class ProfilModel {
  final String id;
  final String nom;
  final String? telephone;
  final String role; // PATIENT, LIVREUR, PHARMACIEN, ADMIN
  final DateTime creeLe;

  ProfilModel({
    required this.id,
    required this.nom,
    this.telephone,
    required this.role,
    required this.creeLe,
  });

  factory ProfilModel.fromSupabase(Map<String, dynamic> json) {
    return ProfilModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      telephone: json['telephone'] as String?,
      role: json['role'] as String,
      creeLe: DateTime.parse(json['cree_le'] as String),
    );
  }
}
