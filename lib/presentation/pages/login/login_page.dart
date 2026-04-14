import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/daos/agent_dao.dart';
import '../voyage/voyage_page.dart';

// ── Local aliases for brevity (mapped from AppTheme) ──────────
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

  // ── Toast overlay ─────────────────────────────────────────
  OverlayEntry? _toastEntry;
  Timer?        _toastTimer;

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

  // ── Login logic ───────────────────────────────────────────

  void _seConnecter() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // 1. Try server login
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'matricule':    _matriculeController.text,
              'mot_de_passe': _motDePasseController.text,
            }),
          )
          .timeout(ApiConstants.defaultTimeout);

      final data = jsonDecode(response.body);
      setState(() => _isLoading = false);
      if (!mounted) return;

      if (data['success'] == true) {
        final employe = data['employe'] as Map<String, dynamic>;
        await AgentDao.saveAgent(
          matricule:    int.parse(_matriculeController.text),
          motDePasse:   _motDePasseController.text,
          employeData:  employe,
        );
        _showToast('Bienvenue ${employe['prenom']} ${employe['nom']} !');
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoyageProgrammePage(agent: employe),
          ),
        );
      } else {
        _showToast('Matricule ou mot de passe incorrect', isError: true);
      }
      return;
    } catch (_) {}

    setState(() => _isLoading = false);

    // 2. Offline login
    final matricule = int.tryParse(_matriculeController.text);
    if (matricule == null) {
      _showToast('Matricule invalide', isError: true);
      return;
    }

    final cached = await AgentDao.getAgent(matricule, _motDePasseController.text);
    if (!mounted) return;

    if (cached != null) {
      _showToast('Hors-ligne — Bienvenue ${cached['prenom']} !',
          isWarning: true);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoyageProgrammePage(agent: cached),
        ),
      );
    } else {
      _showToast('Hors-ligne — aucun compte local trouvé', isError: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header gradient ──────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_navyDark, _navyMid, _navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 36),
              child: Column(
                children: [
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
                    'Société Régionale des Transports de Bizerte',
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

            // ── Form card ─────────────────────────────────────
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
                      // Title
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
                          const Text(
                            'Connexion',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _navyDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _fieldLabel(Icons.badge_outlined, 'Matricule'),
                      const SizedBox(height: 8),
                      _textField(
                        controller:      _matriculeController,
                        hint:            'Entrez votre matricule',
                        keyboardType:    TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Veuillez entrer votre matricule'
                            : null,
                      ),

                      const SizedBox(height: 20),

                      _fieldLabel(Icons.lock_outline, 'Mot de passe'),
                      const SizedBox(height: 8),
                      _textField(
                        controller:      _motDePasseController,
                        hint:            'Entrez votre mot de passe',
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
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Veuillez entrer votre mot de passe'
                            : null,
                      ),

                      const SizedBox(height: 32),

                      // Submit button
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
                                color: _isLoading
                                    ? null
                                    : null,
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
                                    : const Text(
                                        'Se connecter',
                                        style: TextStyle(
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
                          'Connectez-vous une fois avec internet\npour activer le mode hors-ligne',
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

  // ── Helper widgets ────────────────────────────────────────

  Widget _fieldLabel(IconData icon, String label) {
    return Row(
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
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType         = TextInputType.text,
    TextInputAction textInputAction    = TextInputAction.next,
    bool obscureText                   = false,
    Widget? suffixIcon,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:      controller,
      keyboardType:    keyboardType,
      textInputAction: textInputAction,
      obscureText:     obscureText,
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
}

// ─────────────────────────────────────────────────────────────
// Toast — pill-shaped, slide-in from right
// ─────────────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final String msg;
  final Color color;
  final IconData icon;

  const _ToastWidget(
      {required this.msg, required this.color, required this.icon});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
    Future.delayed(
      const Duration(milliseconds: 2100),
      () { if (mounted) _ctrl.reverse(); },
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