class PharmacieModel {
  final int id;
  final String nom;
  final String? adresse;
  final double latitude;
  final double longitude;

  PharmacieModel({
    required this.id,
    required this.nom,
    this.adresse,
    required this.latitude,
    required this.longitude,
  });

  // Convertit une ligne de la base de données Supabase en objet Dart
  factory PharmacieModel.fromSupabase(Map<String, dynamic> json) {
    double lat = 3.8480; // Valeur par défaut (Yaoundé)
    double lng = 11.5021;

    final posData = json['position'];
    if (posData is String) {
      if (posData.startsWith('POINT')) {
        // Nettoyage de la chaîne "POINT(11.5021 3.8480)"
        final coordString = posData.replaceAll('POINT(', '').replaceAll(')', '');
        final coords = coordString.split(' ');
        if (coords.length == 2) {
          lng = double.parse(coords[0]);
          lat = double.parse(coords[1]);
        }
      }
    } else if (posData is Map<String, dynamic>) {
      // Format GeoJSON retourné par Supabase: {"type": "Point", "coordinates": [longitude, latitude]}
      final coords = posData['coordinates'] as List?;
      if (coords != null && coords.length == 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    }

    return PharmacieModel(
      id: json['id'] as int,
      nom: json['nom'] as String,
      adresse: json['adresse'] as String?,
      latitude: lat,
      longitude: lng,
    );
  }
}