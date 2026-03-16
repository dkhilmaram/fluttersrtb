import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'voyage_programme.dart';

// ── Color palette ──
const Color navyDark  = Color(0xFF0D1B3E);
const Color navyMid   = Color(0xFF1A3260);
const Color navyLight = Color(0xFF1E4080);
const Color goldLight = Color(0xFFF5C842);
const Color surface   = Color(0xFFF2F5FB);
const Color cardWhite = Color(0xFFFFFFFF);

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

  void _seConnecter() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final response = await http.post(
          Uri.parse('http://127.0.0.1:8000/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'matricule': _matriculeController.text,
            'mot_de_passe': _motDePasseController.text,
          }),
        );
        final data = jsonDecode(response.body);
        setState(() => _isLoading = false);
        if (!mounted) return;

        if (data['success'] == true) {
          _showSnack(
            'Bienvenue ${data['employe']['prenom']} ${data['employe']['nom']} !',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VoyageProgrammePage(agent: data['employe']),
            ),
          );
        } else {
          _showSnack('Matricule ou mot de passe incorrect', isError: true);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnack('Erreur de connexion au serveur', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Flexible(child: Text(msg,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  void dispose() {
    _matriculeController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: SingleChildScrollView(
        child: Column(children: [

          // ── Header ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [navyDark, navyMid, navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 36),
            child: Column(children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20, offset: const Offset(0, 8),
                  )],
                ),
                padding: const EdgeInsets.all(10),
                child: Image.asset('assets/images/logo_srtb.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.directions_bus,
                            size: 50, color: navyMid)),
              ),
              const SizedBox(height: 16),
              const Text('S R T B',
                  style: TextStyle(color: Colors.white, fontSize: 24,
                      fontWeight: FontWeight.bold, letterSpacing: 8)),
              const SizedBox(height: 6),
              Text('Société Régionale des Transports de Bizerte',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.65),
                      fontSize: 12, letterSpacing: 0.3)),
              const SizedBox(height: 20),
              // ── Divider pill ──
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: goldLight.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ]),
          ),

          // ── Form card ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                  color: navyMid.withOpacity(0.08),
                  blurRadius: 20, offset: const Offset(0, 4),
                )],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Title ──
                    Row(children: [
                      Container(
                        width: 4, height: 22,
                        decoration: BoxDecoration(
                          color: navyMid,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Connexion',
                          style: TextStyle(fontSize: 18,
                              fontWeight: FontWeight.bold, color: navyDark)),
                    ]),

                    const SizedBox(height: 24),

                    // ── Matricule ──
                    _fieldLabel(Icons.badge_outlined, 'Matricule'),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _matriculeController,
                      hint: 'Entrez votre matricule',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Veuillez entrer votre matricule' : null,
                    ),

                    const SizedBox(height: 20),

                    // ── Mot de passe ──
                    _fieldLabel(Icons.lock_outline, 'Mot de passe'),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _motDePasseController,
                      hint: 'Entrez votre mot de passe',
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _seConnecter(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey.shade400, size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Veuillez entrer votre mot de passe' : null,
                    ),

                    const SizedBox(height: 32),

                    // ── Submit button ──
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _isLoading ? null : _seConnecter,
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: _isLoading ? null
                                  : const LinearGradient(
                                      colors: [navyDark, navyLight],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                              color: _isLoading ? null : null,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: _isLoading ? [] : [
                                BoxShadow(color: navyMid.withOpacity(0.35),
                                    blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(
                                          color: navyMid, strokeWidth: 2.5))
                                  : const Text('Se connecter',
                                      style: TextStyle(color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fieldLabel(IconData icon, String label) {
    return Row(children: [
      Icon(icon, color: navyMid, size: 16),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: navyDark, letterSpacing: 0.3)),
    ]);
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool obscureText = false,
    Widget? suffixIcon,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(color: navyDark, fontSize: 14,
          fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400,
            fontSize: 13, fontWeight: FontWeight.normal),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        filled: true,
        fillColor: surface,
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
          borderSide: const BorderSide(color: navyMid, width: 2),
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