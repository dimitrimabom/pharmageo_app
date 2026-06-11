import 'medicament_model.dart';

class StockModel {
  final int id;
  final int pharmacieId;
  final int medicamentId;
  final int quantite;
  final MedicamentModel? medicament; // Jointure optionnelle

  StockModel({
    required this.id,
    required this.pharmacieId,
    required this.medicamentId,
    required this.quantite,
    this.medicament,
  });

  factory StockModel.fromSupabase(Map<String, dynamic> json) {
    MedicamentModel? med;
    if (json['medicaments'] != null) {
      med = MedicamentModel.fromSupabase(json['medicaments'] as Map<String, dynamic>);
    }
    
    return StockModel(
      id: json['id'] as int,
      pharmacieId: json['pharmacie_id'] as int,
      medicamentId: json['medicament_id'] as int,
      quantite: json['quantite'] as int,
      medicament: med,
    );
  }
}
