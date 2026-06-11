import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profil_model.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Récupérer la session active
  Session? get currentSession => _supabase.auth.currentSession;

  // Récupérer l'utilisateur connecté
  User? get currentUser => _supabase.auth.currentUser;

  // Connexion email/mot de passe
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Inscription patient
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String nom,
    required String telephone,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'nom': nom,
        'telephone': telephone,
        'role': 'PATIENT', // Rôle mobile forcé par défaut
      },
    );
  }

  // Récupérer le profil et le rôle en base de données pour l'utilisateur connecté
  Future<ProfilModel?> fetchUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profils')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (data == null) return null;
      return ProfilModel.fromSupabase(data);
    } catch (e) {
      // ignore: avoid_print
      print("Erreur de récupération du profil: $e");
      return null;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
