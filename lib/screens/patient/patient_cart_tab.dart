import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/app_state_provider.dart';

class PatientCartTab extends StatelessWidget {
  final VoidCallback onNavigateToMap;
  final VoidCallback onCheckoutRequested;

  const PatientCartTab({
    super.key,
    required this.onNavigateToMap,
    required this.onCheckoutRequested,
  });

  void _showClearCartDialog(BuildContext context, AppStateProvider appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vider le panier ?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Voulez-vous vraiment retirer tous les articles de votre panier ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              appState.clearCart();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Le panier a été vidé.'),
                  backgroundColor: Color(0xFF64748B),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Vider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final cartItems = appState.cart.values.toList();
    final uniquePharmacies = appState.cartPharmacies;

    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFF10B981)),
                ),
                const SizedBox(height: 24),
                Text(
                  "Votre panier est vide",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Text(
                  "Parcourez la carte pour trouver des pharmacies et y ajouter des médicaments.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onNavigateToMap();
                  },
                  icon: const Icon(Icons.map_rounded, size: 16, color: Colors.white),
                  label: const Text("Retourner à la carte", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculer les coûts
    final totalHT = appState.cartSubtotal;
    final totalTVA = (totalHT * 0.1925).round();
    final deliveryFee = appState.calculateDeliveryFee(3.0); // Forfait 3 km de base
    final totalTTC = totalHT + totalTVA + deliveryFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Mon Panier', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
            tooltip: "Vider le panier",
            onPressed: () {
              HapticFeedback.lightImpact();
              _showClearCartDialog(context, appState);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Liste des articles groupés par pharmacie
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: uniquePharmacies.length,
              itemBuilder: (context, pharmIdx) {
                final pharmacy = uniquePharmacies[pharmIdx];
                final pharmItems = cartItems.where((item) => item.pharmacy.id == pharmacy.id).toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre Pharmacie
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pharmacy.nom,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (uniquePharmacies.length > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "Détour",
                                  style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        
                        // Liste des produits dans cette pharmacie
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pharmItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                          itemBuilder: (context, itemIdx) {
                            final item = pharmItems[itemIdx];
                            final med = item.stock.medicament;
                            if (med == null) return const SizedBox();

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  // Infos Produit
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          med.nom.toUpperCase(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                        ),
                                        Text(
                                          "${med.prixIndicatif} FCFA / u",
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Sélecteur Quantité & Supprimer
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove_rounded, size: 14, color: Color(0xFF10B981)),
                                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                              padding: EdgeInsets.zero,
                                              onPressed: () => appState.decrementCartItem(item.stock),
                                            ),
                                            Text(
                                              '${item.quantite}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF10B981)),
                                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                if (item.quantite < item.stock.quantite) {
                                                  appState.addToCart(item.stock, pharmacy);
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text("Quantité en stock maximale atteinte.")),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          appState.removeCartItem(item.stock.id);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Résumé de la facturation & bouton d'action
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Sous-total :", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text("$totalHT FCFA", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TVA (19.25%) :", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text("$totalTVA FCFA", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Frais de livraison${uniquePharmacies.length > 1 ? ' (avec ${uniquePharmacies.length - 1} détours)' : ''} :",
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    Text("$deliveryFee FCFA", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total TTC :", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    Text("$totalTTC FCFA", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onCheckoutRequested();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("Passer la commande", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
