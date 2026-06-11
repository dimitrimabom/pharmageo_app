import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'map_screen.dart'; // Pour la redirection après connexion
import '../services/auth_service.dart';
import 'patient/patient_main_screen.dart';
import 'livreur/livreur_main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // États de bascule et de chargement
  bool _isSignUp = false; // False = Connexion, True = Inscription
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'PATIENT'; // Rôle d'inscription

  // Contrôleurs des champs de texte
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nomController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ⚡ FONCTION PRINCIPALE : SOUMISSION DE L'AUTHENTIFICATION
  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;

    // Retour haptique lors du clic sur le bouton d'action principal
    HapticFeedback.lightImpact();

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        // 1. LOGIQUE D'INSCRIPTION DYNAMIQUE (PATIENT OU LIVREUR)
        final AuthResponse res = await _supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'nom': _nomController.text.trim(),
            'telephone': _phoneController.text.trim(),
            'role': _selectedRole, // Rôle dynamique choisi par l'utilisateur
          },
        );

        if (!mounted) return;

        if (res.user != null) {
          // Affichage d'un SnackBar premium
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Compte créé ! Veuillez valider votre adresse email avant de vous connecter.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 6),
            ),
          );
          setState(() => _isSignUp = false); // Basculer sur l'écran connexion
        }
      } else {
        // 2. LOGIQUE DE CONNEXION AVEC REDIRECTION SELON LE RÔLE
        final AuthResponse res = await _supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;

        if (res.session != null) {
          HapticFeedback.mediumImpact();
          
          final AuthService authService = AuthService();
          final profile = await authService.fetchUserProfile(res.session!.user.id);
          
          if (!mounted) return;
          
          if (profile != null && profile.role == 'LIVREUR') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LivreurMainScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PatientMainScreen()),
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      
      // Gestion explicite de l'email non confirmé
      String errorMsg = e.message;
      if (errorMsg.contains('Email not confirmed')) {
        errorMsg = 'Votre adresse email n\'a pas encore été confirmée. Veuillez vérifier votre boîte de réception.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMsg,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Une erreur est survenue : $e',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Gris très clair premium (Slate 50)
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // EN-TÊTE LOGO
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.08),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.local_pharmacy_rounded,
                        size: 50,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSignUp ? 'Créer un compte' : 'Espace Patient',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B), // Slate 800
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Réseau de logistique médicale PharmaGeo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B), // Slate 500
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // CONTENEURS INPUTS
                  if (_isSignUp) ...[
                    // Nom complet
                    TextFormField(
                      controller: _nomController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: _buildInputDecoration(
                        label: 'Nom complet',
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Entrez votre nom' : null,
                    ),
                    const SizedBox(height: 16),
                    // Numéro de téléphone
                    TextFormField(
                      controller: _phoneController,
                      style: GoogleFonts.inter(fontSize: 14),
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration(
                        label: 'Numéro de téléphone',
                        icon: Icons.phone_iphone_rounded,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Entrez votre numéro' : null,
                    ),
                    const SizedBox(height: 16),
                    // Sélecteur de rôle d'inscription
                    const Text(
                      "S'inscrire en tant que :",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRoleOption("PATIENT", Icons.person_rounded, "Patient"),
                        const SizedBox(width: 12),
                        _buildRoleOption("LIVREUR", Icons.motorcycle_rounded, "Livreur"),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email
                  TextFormField(
                    controller: _emailController,
                    style: GoogleFonts.inter(fontSize: 14),
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildInputDecoration(
                      label: 'Adresse email',
                      icon: Icons.mail_outline_rounded,
                    ),
                    validator: (v) => v == null || !v.contains('@') ? 'Adresse email invalide' : null,
                  ),
                  const SizedBox(height: 16),

                  // Mot de passe
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: _buildInputDecoration(
                      label: 'Mot de passe',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (v) => v == null || v.length < 6 ? 'Le mot de passe doit faire 6 caractères min.' : null,
                  ),
                  
                  const SizedBox(height: 28),

                  // BOUTON VALIDER
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _isSignUp ? "S'inscrire" : 'Se connecter',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // BASCULE DE MODE
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _isSignUp ? 'Déjà inscrit ? Se connecter' : 'Nouveau sur PharmaGeo ? Créer un compte',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

  // Méthode utilitaire pour générer des decorations d'inputs premium cohérentes
  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        color: const Color(0xFF64748B),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        color: const Color(0xFF10B981),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      // Bords normaux
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      // Bords désactivés/activés mais non sélectionnés
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      // Bords en cours d'écriture (Focused)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
      ),
      // Bords en cas d'erreur de validation
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
      errorStyle: GoogleFonts.inter(
        fontSize: 11,
        color: const Color(0xFFEF4444),
      ),
    );
  }

  Widget _buildRoleOption(String role, IconData icon, String label) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedRole = role;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981).withOpacity(0.08) : Colors.white,
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}