import 'dart:async';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/daos/agent_dao.dart';
import '../voyage/voyage_page.dart';
import '../../widgets/language_switcher.dart';
import '../../../services/sync_service.dart';

const _navyDark  = AppTheme.navyDark;
const _navyMid   = AppTheme.navyMid;
const _navyLight = AppTheme.navyLight;
const _goldLight = AppTheme.goldLight;
const _surface   = AppTheme.offWhite;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _matriculeController  = TextEditingController();
  final _motDePasseController = TextEditingController();
  final _formKey              = GlobalKey<FormState>();

  bool _isLoading       = false;
  bool _obscurePassword = true;

  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

  // ─────────────────────────────────────────────────────────────
  // Toast
  // ─────────────────────────────────────────────────────────────

  void _showToast(String msg,
      {bool isError = false, bool isWarning = false}) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    final color = isError
        ? Colors.red.shade700
        : isWarning
            ? Colors.orange.shade700
            : const Color(0xFF16A34A);
    final icon = isError
        ? Icons.error_outline
        : isWarning
            ? Icons.offline_bolt
            : Icons.check_circle_outline;

    final entry = OverlayEntry(
      builder: (_) => _ToastWidget(msg: msg, color: color, icon: icon),
    );
    _toastEntry = entry;
    Overlay.of(context).insert(entry);
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      entry.remove();
      if (_toastEntry == entry) _toastEntry = null;
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _matriculeController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Login logic
  // ─────────────────────────────────────────────────────────────

  Future<void> _seConnecter() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    // ── Capture values FIRST before any async gap ────────────────
    final matriculeInput = _matriculeController.text.trim();
    final passwordInput  = _motDePasseController.text;

    final t = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    // ── 1. Try online login ──────────────────────────────────────
    // null  = network/timeout (fall through to offline)
    // true  = server said success
    // false = server explicitly rejected credentials
    bool? serverResult;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'matricule':    matriculeInput,
              'mot_de_passe': passwordInput,
            }),
          )
          .timeout(const Duration(seconds: 5));

      // ── Debug: log the raw server response ─────────────────────
      print('🌐 Online response status: ${response.statusCode}');
      print('🌐 Online response body:   ${response.body}');

      // 5xx = server-side infrastructure failure (DB down, crash, etc.)
      // Treat exactly like a network error → fall through to offline.
      if (response.statusCode >= 500) {
        print('⚠️  Server error ${response.statusCode} (infrastructure) — falling back to offline…');
        serverResult = null;
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          serverResult = true;

          final employe = Map<String, dynamic>.from(
              data['employe'] as Map<String, dynamic>);

          final matricule = employe['matricule_agent'] as int? ??
              int.tryParse(employe['matricule']?.toString() ?? '') ??
              int.parse(matriculeInput);

          try {
            await AgentDao.saveAgent(
              matricule:   matricule,
              motDePasse:  passwordInput,
              employeData: employe,
            );
            print('✅ Agent credentials cached for offline use');
          } catch (e, stack) {
            print('❌ CRITICAL: failed to cache agent credentials: $e');
            print(stack);
          }

          SyncService.setMatricule(matricule);

          if (mounted) {
            setState(() => _isLoading = false);
            _showToast(t.bienvenue(employe['prenom'], employe['nom']));
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VoyageProgrammePage(agent: employe),
              ),
            );
          }
          return;

        } else {
          // 4xx or explicit success:false → wrong credentials, stop here
          serverResult = false;
          print('❌ Server rejected login (${response.statusCode}): success=${data['success']} message=${data['message']}');
        }
      }

    } on TimeoutException {
      print('⏱  Server timeout — falling back to offline login…');
      serverResult = null; // treat as offline
    } on http.ClientException catch (e) {
      print('🌐 Network error (ClientException) — falling back to offline… ($e)');
      serverResult = null;
    } catch (e) {
      print('🌐 Network error — falling back to offline login… ($e)');
      serverResult = null;
    }

    // ── If server explicitly rejected, stop — don't try offline ──
    if (serverResult == false) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast(t.loginError, isError: true);
      }
      return;
    }

    // ── 2. Offline fallback (serverResult == null = no connection) ─
    if (mounted) setState(() => _isLoading = false);

    print('🔑 OFFLINE ATTEMPT: matricule="$matriculeInput" pass_len=${passwordInput.length}');

    final matricule = int.tryParse(matriculeInput);
    if (matricule == null) {
      if (mounted) _showToast(t.matriculeInvalid, isError: true);
      return;
    }

    final cached = await AgentDao.getAgent(matricule, passwordInput);
    print('🔑 OFFLINE RESULT: ${cached != null ? "SUCCESS" : "FAILED"}');

    if (cached != null) {
      SyncService.setMatricule(matricule);
      if (mounted) {
        _showToast(t.bienvenueOffline(cached['prenom']), isWarning: true);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoyageProgrammePage(agent: cached),
          ),
        );
      }
    } else {
      if (mounted) _showToast(t.offlineNoAccount, isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_navyDark, _navyMid, _navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 36),
              child: Column(
                children: [
                  Row(
                    children: const [Spacer(), LanguageSwitcher()],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/images/logo_srtb.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.directions_bus,
                        size: 50,
                        color: _navyMid,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'S R T B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.srtbFullName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _goldLight.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _navyMid.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _navyMid,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            t.connexion,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _navyDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _fieldLabel(Icons.badge_outlined, t.matricule),
                      const SizedBox(height: 8),
                      _textField(
                        controller:      _matriculeController,
                        hint:            t.matriculeHint,
                        keyboardType:    TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? t.matriculeError : null,
                      ),

                      const SizedBox(height: 20),

                      _fieldLabel(Icons.lock_outline, t.motDePasse),
                      const SizedBox(height: 8),
                      _textField(
                        controller:      _motDePasseController,
                        hint:            t.motDePasseHint,
                        obscureText:     _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _seConnecter(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? t.motDePasseError : null,
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: _isLoading ? null : _seConnecter,
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: _isLoading
                                    ? null
                                    : const LinearGradient(
                                        colors: [_navyDark, _navyLight],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                color: _isLoading ? Colors.grey.shade200 : null,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _isLoading
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: _navyMid.withOpacity(0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: _navyMid,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        t.seConnecter,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: Text(
                          t.offlineHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Micro-widgets
  // ─────────────────────────────────────────────────────────────

  Widget _fieldLabel(IconData icon, String label) => Row(
        children: [
          Icon(icon, color: _navyMid, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _navyDark,
              letterSpacing: 0.3,
            ),
          ),
        ],
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType   keyboardType     = TextInputType.text,
    TextInputAction textInputAction  = TextInputAction.next,
    bool obscureText                 = false,
    Widget? suffixIcon,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller:       controller,
        keyboardType:     keyboardType,
        textInputAction:  textInputAction,
        obscureText:      obscureText,
        onFieldSubmitted: onFieldSubmitted,
        style: const TextStyle(
          color: _navyDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _navyMid, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade300),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          suffixIcon: suffixIcon,
        ),
        validator: validator,
      );
}

// ─────────────────────────────────────────────────────────────
// Toast widget
// ─────────────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final String   msg;
  final Color    color;
  final IconData icon;

  const _ToastWidget(
      {required this.msg, required this.color, required this.icon});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _opacity;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
    Future.delayed(
      const Duration(milliseconds: 2100),
      () {
        if (mounted) _ctrl.reverse();
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.msg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}