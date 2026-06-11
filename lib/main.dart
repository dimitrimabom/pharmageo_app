import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/app_state_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth_screen.dart';
import 'screens/patient/patient_main_screen.dart';
import 'screens/livreur/livreur_main_screen.dart';

void main() async {
  // S'assurer que les liaisons Flutter sont initialisées
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation globale de Supabase
  await Supabase.initialize(
    url: 'https://laebhzpqplbjlcgsvydg.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhZWJoenBxcGxiamxjZ3N2eWRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMzgyODQsImV4cCI6MjA5NjYxNDI4NH0.G-TvJjd6JRPJO5k1qH2YopjvXkzoFgV7rjCqAoQmE1M',
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaGeo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF10B981),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFF059669),
          surface: Colors.white,
          error: Colors.redAccent,
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      // On démarrera sur une page de vérification de session (Splash Screen)
      home: const SplashScreen(),
    );
  }
}

// Écran de chargement premium et animé pour vérifier si l'utilisateur est connecté et identifier son rôle
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    
    // Configuration de l'animation de pulsation du logo
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  void _checkAuth() async {
    // Laisser le temps à l'animation de faire au moins deux pulsations pour l'effet visuel (2.0s)
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final session = _authService.currentSession;

    if (session != null) {
      // Si connecté, on récupère le profil de l'utilisateur pour vérifier son rôle
      final profile = await _authService.fetchUserProfile(session.user.id);
      
      if (!mounted) return;

      if (profile != null) {
        if (profile.role == 'LIVREUR') {
          // Redirection vers l'espace Livreur
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LivreurMainScreen()),
          );
          return;
        }
      }
      
      // Par défaut (rôle PATIENT ou si profil introuvable), redirection vers l'espace Patient
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PatientMainScreen()),
      );
    } else {
      // Sinon vers l'écran de connexion
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF10B981), // Vert Émeraude 500
              Color(0xFF047857), // Vert Émeraude 700
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo pulsant avec ombre douce
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _opacityAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_pharmacy_rounded,
                          color: Color(0xFF10B981),
                          size: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Nom de l'application
                    Text(
                      'PharmaGeo',
                      style: GoogleFonts.poppins(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Slogan sous-titre
                    Text(
                      'Réseau de Santé Mobile Cameroun',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Chargement discret en bas
              Positioned(
                bottom: 48,
                left: 40,
                right: 40,
                child: Column(
                  children: [
                    const SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(100)),
                        child: LinearProgressIndicator(
                          color: Colors.white,
                          backgroundColor: Color(0x2BFFFFFF),
                          minHeight: 3.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Connexion au serveur sécurisé...',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.55),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
