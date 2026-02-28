import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'voyage_programme.dart';

// Couleur définie en dehors de la classe pour éviter les problèmes de const
const Color srtbBlue = Color(0xFF1A3F7A);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _matriculeController = TextEditingController();
  final _motDePasseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Bienvenue ${data['employe']['prenom']} ${data['employe']['nom']} !'),
      backgroundColor: Colors.green,
    ),
  );
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VoyageProgrammePage(agent: data['employe']), // ← employe not agent
    ),
  );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Matricule ou mot de passe incorrect'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur de connexion au serveur'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header bleu ──
            Container(
              width: double.infinity,
              color: srtbBlue,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              child: Column(
                children: [
                  // Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/logo_srtb.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.directions_bus,
                          size: 80,
                          color: srtbBlue,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Titre
                  const Text(
                    'S R T B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Sous-titre
                  const Text(
                    'Société Régionale des Transports de Bizerte',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // ── Formulaire ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label Matricule
                    const Row(
                      children: [
                        Icon(Icons.person, color: srtbBlue, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Matricule',
                          style: TextStyle(
                            color: srtbBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Champ Matricule
                    TextFormField(
                      controller: _matriculeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Entrez votre matricule',
                        hintStyle: const TextStyle(color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: srtbBlue, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre matricule';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Label Mot de passe
                    const Row(
                      children: [
                        Icon(Icons.lock, color: srtbBlue, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Mot de passe',
                          style: TextStyle(
                            color: srtbBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Champ Mot de passe
                    TextFormField(
                      controller: _motDePasseController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _seConnecter(),
                      decoration: InputDecoration(
                        hintText: 'Entrez votre mot de passe',
                        hintStyle: const TextStyle(color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: srtbBlue, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre mot de passe';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Bouton Se connecter
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _seConnecter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: srtbBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                            : const Text(
                          'Se connecter',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}