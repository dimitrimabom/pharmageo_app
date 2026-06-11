class MedicamentModel {
  final int id;
  final String nom;
  final String? description;
  final int prixIndicatif;

  MedicamentModel({
    required this.id,
    required this.nom,
    this.description,
    required this.prixIndicatif,
  });

  factory MedicamentModel.fromSupabase(Map<String, dynamic> json) {
    return MedicamentModel(
      id: json['id'] as int,
      nom: json['nom'] as String,
      description: json['description'] as String?,
      prixIndicatif: (json['prix_indicatif'] as num?)?.toInt() ?? 0,
    );
  }
}
