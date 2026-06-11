import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pharmacie_model.dart';

class GeoService {
  final _supabase = Supabase.instance.client;

  // 1. Récupérer la position GPS actuelle du Patient
  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Le service de localisation est désactivé.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Les permissions de localisation sont refusées.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Les permissions sont refusées de façon permanente.');
    } 

    return await Geolocator.getCurrentPosition();
  }

  // 2. Charger toutes les pharmacies depuis Supabase
  Future<List<PharmacieModel>> fetchPharmacies() async {
    try {
      final List<dynamic> response = await _supabase
          .from('pharmacies')
          .select('id, nom, adresse, position');

      return response.map((item) => PharmacieModel.fromSupabase(item)).toList();
    } catch (e) {
      debugPrint("Erreur de récupération des pharmacies: $e");
      return [];
    }
  }
}