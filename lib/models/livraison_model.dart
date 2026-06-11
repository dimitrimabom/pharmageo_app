import 'pharmacie_model.dart';

class LivraisonItem {
  final String designation;
  final int quantite;
  final int prixUnitaire;

  LivraisonItem({
    required this.designation,
    required this.quantite,
    required this.prixUnitaire,
  });

  int get total => quantite * prixUnitaire;
}

class LivraisonModel {
  final int id;
  final String statut; // EN_ATTENTE, PREPARATION, EN_COURS, LIVRE
  final DateTime creeLe;
  final int pharmacieId;
  final String patientId;
  final String? livreurId;
  final PharmacieModel? pharmacie; // Jointure optionnelle

  LivraisonModel({
    required this.id,
    required this.statut,
    required this.creeLe,
    required this.pharmacieId,
    required this.patientId,
    this.livreurId,
    this.pharmacie,
  });

  // Code PIN de sécurité calculé de manière déterministe pour la livraison
  String get codeSecurite {
    final pin = (id * 7) % 9000 + 1000;
    return pin.toString();
  }

  // Articles de livraison générés de façon déterministe identique à la console Pharmacien (FacturePDF.tsx)
  List<LivraisonItem> get items {
    final mod = id % 3;
    if (mod == 0) {
      return [
        LivraisonItem(designation: "Doliprane 1000mg (Boîte)", quantite: 2, prixUnitaire: 1500),
        LivraisonItem(designation: "Paracétamol 500mg (Boîte)", quantite: 1, prixUnitaire: 1000),
      ];
    } else if (mod == 1) {
      return [
        LivraisonItem(designation: "Amoxicilline 500mg (Boîte)", quantite: 3, prixUnitaire: 2500),
        LivraisonItem(designation: "Vitamine C Orange (Tube)", quantite: 2, prixUnitaire: 1200),
      ];
    } else {
      return [
        LivraisonItem(designation: "Spasfon Lyoc 80mg (Boîte)", quantite: 2, prixUnitaire: 2200),
        LivraisonItem(designation: "Efferalgan Vitamine C (Tube)", quantite: 1, prixUnitaire: 1800),
      ];
    }
  }

  // Liste des pharmacies pour simulation des détours
  List<String> get pharmaciesDetours {
    final mod = id % 3;
    final primaryName = pharmacie?.nom ?? "Pharmacie Principale";
    if (mod == 1) {
      return [primaryName, "Pharmacie Denver (Détour)"];
    } else if (mod == 2) {
      return [primaryName, "Pharmacie de la Cité (Détour)"];
    }
    return [primaryName];
  }

  int get totalHT {
    return items.fold(0, (sum, item) => sum + item.total);
  }

  // TVA camerounaise (19.25%)
  int get totalTVA {
    return (totalHT * 0.1925).round();
  }

  int get totalTTC {
    return totalHT + totalTVA;
  }

  factory LivraisonModel.fromSupabase(Map<String, dynamic> json) {
    PharmacieModel? pharm;
    if (json['pharmacies'] != null) {
      pharm = PharmacieModel.fromSupabase(json['pharmacies'] as Map<String, dynamic>);
    }

    return LivraisonModel(
      id: json['id'] as int,
      statut: json['statut'] as String,
      creeLe: DateTime.parse(json['cree_le'] as String),
      pharmacieId: json['pharmacie_id'] as int,
      patientId: json['patient_id'] as String,
      livreurId: json['livreur_id'] as String?,
      pharmacie: pharm,
    );
  }
}
