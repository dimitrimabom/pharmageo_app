import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/stock_model.dart';
import '../models/livraison_model.dart';
import '../models/pharmacie_model.dart';

class CartItem {
  final StockModel stock;
  int quantite;
  final PharmacieModel pharmacy;

  CartItem({required this.stock, required this.pharmacy, this.quantite = 1});

  int get total => stock.medicament!.prixIndicatif * (stock.medicament!.prixIndicatif > 0 ? quantite : 1);
}

class AppStateProvider extends ChangeNotifier {
  // ================= PATIENT STATES =================
  final Map<int, CartItem> _cart = {}; // key: stockId
  PharmacieModel? _cartPharmacy; // Pharmacie principale (la première ajoutée)

  LivraisonModel? _activeOrder; // Commande en cours de livraison active pour le patient

  // Getters
  Map<int, CartItem> get cart => _cart;
  PharmacieModel? get cartPharmacy => _cartPharmacy;
  LivraisonModel? get activeOrder => _activeOrder;
  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantite);
  
  int get cartSubtotal {
    return _cart.values.fold(0, (sum, item) => sum + item.total);
  }

  // Récupérer la liste des pharmacies uniques dans le panier
  List<PharmacieModel> get cartPharmacies {
    final pharmacies = <int, PharmacieModel>{};
    for (var item in _cart.values) {
      pharmacies[item.pharmacy.id] = item.pharmacy;
    }
    return pharmacies.values.toList();
  }

  // Calcul des frais de livraison : 250 FCFA par kilomètre (minimum 500 FCFA)
  // Ajoute des frais de détour de 300 FCFA pour chaque pharmacie supplémentaire après la 1ère.
  int calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= 0) return 500;
    final baseFee = (distanceKm * 250).round();
    final uniquePharmaciesCount = cartPharmacies.length;
    final detourFee = uniquePharmaciesCount > 1 ? (uniquePharmaciesCount - 1) * 300 : 0;
    
    final totalFee = baseFee + detourFee;
    return totalFee < 500 ? 500 : totalFee;
  }

  // Ajouter au panier
  bool addToCart(StockModel stock, PharmacieModel pharmacy) {
    if (stock.medicament == null) return false;

    // Émettre une vibration haptique légère pour confirmer l'ajout
    HapticFeedback.lightImpact();

    // Règle assouplie : Nous permettons l'ajout de médicaments depuis différentes pharmacies !
    if (_cartPharmacy == null) {
      _cartPharmacy = pharmacy;
    }
    
    if (_cart.containsKey(stock.id)) {
      if (_cart[stock.id]!.quantite < stock.quantite) {
        _cart[stock.id]!.quantite++;
      }
    } else {
      _cart[stock.id] = CartItem(stock: stock, pharmacy: pharmacy, quantite: 1);
    }
    
    notifyListeners();
    return true;
  }

  // Diminuer ou retirer du panier
  void decrementCartItem(StockModel stock) {
    HapticFeedback.lightImpact();
    if (!_cart.containsKey(stock.id)) return;

    if (_cart[stock.id]!.quantite > 1) {
      _cart[stock.id]!.quantite--;
    } else {
      _cart.remove(stock.id);
      if (_cart.isEmpty) {
        _cartPharmacy = null;
      }
    }
    notifyListeners();
  }

  // Retirer complètement un article du panier
  void removeCartItem(int stockId) {
    HapticFeedback.lightImpact();
    _cart.remove(stockId);
    if (_cart.isEmpty) {
      _cartPharmacy = null;
    }
    notifyListeners();
  }

  // Vider le panier
  void clearCart() {
    _cart.clear();
    _cartPharmacy = null;
    notifyListeners();
  }

  // Activer le suivi d'une commande
  void setActiveOrder(LivraisonModel order) {
    _activeOrder = order;
    notifyListeners();
  }

  void clearActiveOrder() {
    _activeOrder = null;
    notifyListeners();
  }

  // ================= LIVREUR STATES =================
  bool _isOnline = false; // Statut disponible/hors ligne du livreur
  LivraisonModel? _activeDelivery; // Course actuellement acceptée par le livreur
  int _earningsToday = 0; // Gains cumulés du jour (FCFA)
  int _completedDeliveriesToday = 0; // Nombre de courses validées aujourd'hui

  // Getters livreur
  bool get isOnline => _isOnline;
  LivraisonModel? get activeDelivery => _activeDelivery;
  int get earningsToday => _earningsToday;
  int get completedDeliveriesToday => _completedDeliveriesToday;

  // Changer la disponibilité en ligne/hors ligne
  void toggleOnline() {
    HapticFeedback.mediumImpact();
    _isOnline = !_isOnline;
    notifyListeners();
  }

  // Affecter une livraison active
  void setActiveDelivery(LivraisonModel delivery) {
    _activeDelivery = delivery;
    notifyListeners();
  }

  // Clôturer la livraison et enregistrer les gains
  void completeActiveDelivery(int deliveryFee) {
    HapticFeedback.mediumImpact();
    if (_activeDelivery != null) {
      _earningsToday += deliveryFee;
      _completedDeliveriesToday++;
      _activeDelivery = null;
    }
    notifyListeners();
  }

  void cancelActiveDelivery() {
    _activeDelivery = null;
    notifyListeners();
  }
}
