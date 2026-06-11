import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stock_model.dart';
import '../models/livraison_model.dart';

class DbService {
  final _supabase = Supabase.instance.client;

  // 1. Récupérer le stock d'une pharmacie (avec jointure médicament)
  Future<List<StockModel>> fetchStocks(int pharmacieId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('stocks')
          .select('id, pharmacie_id, medicament_id, quantite, medicaments(*)')
          .eq('pharmacie_id', pharmacieId);

      return response.map((item) => StockModel.fromSupabase(item)).toList();
    } catch (e) {
      // ignore: avoid_print
      print("Erreur de récupération des stocks: $e");
      return [];
    }
  }

  // 2. Recherche globale de pharmacies possédant un médicament spécifique en stock
  // Retourne la liste des stocks contenant le médicament recherché
  Future<List<StockModel>> searchMedicamentInStocks(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      // Filtre interne PostgREST sur le nom du médicament joint
      final List<dynamic> response = await _supabase
          .from('stocks')
          .select('id, pharmacie_id, medicament_id, quantite, medicaments!inner(*)')
          .ilike('medicaments.nom', '%$query%')
          .gt('quantite', 0); // Uniquement les produits en stock

      return response.map((item) => StockModel.fromSupabase(item)).toList();
    } catch (e) {
      // ignore: avoid_print
      print("Erreur de recherche globale: $e");
      return [];
    }
  }

  // 3. Créer une livraison / commande (Patient)
  Future<LivraisonModel?> createLivraison({
    required int pharmacieId,
    required String patientId,
  }) async {
    try {
      final List<dynamic> response = await _supabase
          .from('livraisons')
          .insert({
            'pharmacie_id': pharmacieId,
            'patient_id': patientId,
            'statut': 'EN_ATTENTE',
          })
          .select('*, pharmacies(*)');

      if (response.isEmpty) return null;
      return LivraisonModel.fromSupabase(response.first as Map<String, dynamic>);
    } catch (e) {
      // ignore: avoid_print
      print("Erreur de création de livraison: $e");
      return null;
    }
  }

  // 4. Charger l'historique des livraisons pour un Patient
  Future<List<LivraisonModel>> fetchPatientLivraisons(String patientId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('livraisons')
          .select('*, pharmacies(*)')
          .eq('patient_id', patientId)
          .order('id', ascending: false);

      return response.map((item) => LivraisonModel.fromSupabase(item)).toList();
    } catch (e) {
      // ignore: avoid_print
      print("Erreur de chargement de l'historique patient: $e");
      return [];
    }
  }

  // 5. Charger les livraisons disponibles pour le Radar des livreurs (statut EN_ATTENTE ou PREPARATION)
  Future<List<LivraisonModel>> fetchAvailableLivraisons() async {
    try {
      final List<dynamic> response = await _supabase
          .from('livraisons')
          .select('*, pharmacies(*)')
          .or('statut.eq.EN_ATTENTE,statut.eq.PREPARATION')
          .isFilter('livreur_id', null)
          .order('id', ascending: false);

      return response.map((item) => LivraisonModel.fromSupabase(item)).toList();
    } catch (e) {
      // ignore: avoid_print
      print("Erreur de récupération des livraisons radar: $e");
      return [];
    }
  }

  // 6. Charger la livraison active d'un Livreur (statut EN_COURS ou PREPARATION affectée)
  Future<LivraisonModel?> fetchLivreurActiveLivraison(String livreurId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('livraisons')
          .select('*, pharmacies(*)')
          .eq('livreur_id', livreurId)
          .neq('statut', 'LIVRE')
          .limit(1);

      if (response.isEmpty) return null;
      return LivraisonModel.fromSupabase(response.first as Map<String, dynamic>);
    } catch (e) {
      // ignore: avoid_print
      print("Erreur active livraison livreur: $e");
      return null;
    }
  }

  // 7. Accepter une livraison (Livreur)
  Future<bool> acceptLivraison(int livraisonId, String livreurId) async {
    try {
      await _supabase
          .from('livraisons')
          .update({
            'livreur_id': livreurId,
            'statut': 'EN_COURS',
          })
          .eq('id', livraisonId);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("Erreur acceptation livraison: $e");
      return false;
    }
  }

  // 8. Mettre à jour le statut d'une livraison
  Future<bool> updateLivraisonStatus(int livraisonId, String newStatus) async {
    try {
      await _supabase
          .from('livraisons')
          .update({
            'statut': newStatus,
          })
          .eq('id', livraisonId);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("Erreur de mise à jour du statut: $e");
      return false;
    }
  }

  // 9. S'abonner aux changements d'une livraison spécifique en temps réel
  RealtimeChannel subscribeToLivraison(int livraisonId, Function(LivraisonModel) onUpdate) {
    final channel = _supabase.channel('livraison-realtime-$livraisonId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'livraisons',
      callback: (payload) async {
        final record = payload.newRecord;
        if (record['id'] == livraisonId) {
          // Recharger avec la jointure pharmacies pour avoir un modèle complet
          try {
            final List<dynamic> res = await _supabase
                .from('livraisons')
                .select('*, pharmacies(*)')
                .eq('id', livraisonId)
                .limit(1);
            
            if (res.isNotEmpty) {
              onUpdate(LivraisonModel.fromSupabase(res.first as Map<String, dynamic>));
            }
          } catch (e) {
            // ignore: avoid_print
            print("Erreur lors de la mise à jour temps réel: $e");
          }
        }
      },
    );
    
    channel.subscribe();
    return channel;
  }

  // 10. Récupérer la pharmacie associée à un employé (pharmacien ou livreur)
  Future<int?> fetchUserPharmacyId(String userId) async {
    try {
      final Map<String, dynamic>? data = await _supabase
          .from('pharmacie_personnel')
          .select('pharmacie_id')
          .eq('pharmacien_id', userId)
          .maybeSingle();

      if (data == null) return null;
      return data['pharmacie_id'] as int;
    } catch (e) {
      // ignore: avoid_print
      print("Erreur de récupération de la pharmacie de l'utilisateur: $e");
      return null;
    }
  }
}
