import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/pharmacie_model.dart';
import '../models/stock_model.dart';
import '../providers/app_state_provider.dart';
import '../services/db_service.dart';

class StocksDialog extends StatefulWidget {
  final PharmacieModel pharmacie;
  final VoidCallback? onCheckoutRequested; // Déclenché si le patient valide le panier depuis le stock

  const StocksDialog({super.key, required this.pharmacie, this.onCheckoutRequested});

  @override
  State<StocksDialog> createState() => _StocksDialogState();
}

class _StocksDialogState extends State<StocksDialog> {
  final DbService _dbService = DbService();
  final TextEditingController _searchController = TextEditingController();
  
  List<StockModel> _allStocks = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    setState(() => _isLoading = true);
    final stocks = await _dbService.fetchStocks(widget.pharmacie.id);
    if (!mounted) return;
    setState(() {
      _allStocks = stocks;
      _isLoading = false;
    });
  }

  List<StockModel> get _filteredStocks {
    if (_searchQuery.isEmpty) return _allStocks;
    return _allStocks.where((stock) {
      final name = stock.medicament?.nom.toLowerCase() ?? "";
      final desc = stock.medicament?.description?.toLowerCase() ?? "";
      return name.contains(_searchQuery.toLowerCase()) || desc.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Affiche un dialogue demandant de vider le panier si changement d'officine
  void _showClearCartDialog(BuildContext context, AppStateProvider appState, StockModel stock) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer de pharmacie ?'),
        content: Text(
          'Votre panier contient déjà des médicaments de "${appState.cartPharmacy?.nom}".\n\n'
          'Voulez-vous vider votre panier actuel pour commander chez "${widget.pharmacie.nom}" ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              appState.clearCart();
              appState.addToCart(stock, widget.pharmacie);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Vider et ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final hasItemsInThisPharmacy = appState.cartPharmacy?.id == widget.pharmacie.id && appState.cartCount > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12, 
        left: 20, 
        right: 20, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 20
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée du BottomSheet
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),

          // En-tête de la pharmacie
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medical_services_rounded, color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pharmacie.nom,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Inventaire des stocks en temps réel",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barre de recherche
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: "Rechercher un médicament...",
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),

          // Zone d'affichage des stocks
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            child: _isLoading
                ? _buildSkeletons() // Skeletons animés au lieu de CircularProgressIndicator
                : _filteredStocks.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, size: 54, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty 
                                  ? "Aucun médicament disponible dans cette officine." 
                                  : "Aucun résultat pour \"$_searchQuery\"",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _filteredStocks.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
                        itemBuilder: (context, index) {
                          final stock = _filteredStocks[index];
                          final med = stock.medicament;
                          if (med == null) return const SizedBox();

                          final int qty = stock.quantite;
                          final bool inStock = qty > 0;
                          final bool lowStock = qty > 0 && qty <= 10;

                          // Déterminer le statut visuel
                          Color statusColor = const Color(0xFF10B981);
                          String statusText = "En stock";
                          if (!inStock) {
                            statusColor = const Color(0xFFEF4444);
                            statusText = "Rupture";
                          } else if (lowStock) {
                            statusColor = const Color(0xFFF59E0B);
                            statusText = "Stock faible ($qty)";
                          }

                          // Vérifier si l'article est dans le panier
                          final cartItem = appState.cart[stock.id];
                          final int cartQty = cartItem?.quantite ?? 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              children: [
                                // Médicament info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.nom.toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        med.description ?? "Pas de description fournie",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            statusText,
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Prix & Boutons d'ajout
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${med.prixIndicatif} FCFA",
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 8),
                                    if (!inStock)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text('Indisponible', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      )
                                    else if (cartQty > 0)
                                      // Commandes de quantité dynamiques + et -
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF10B981)),
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              padding: EdgeInsets.zero,
                                              onPressed: () => appState.decrementCartItem(stock),
                                            ),
                                            Text(
                                              '$cartQty',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF10B981)),
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                if (cartQty < stock.quantite) {
                                                  appState.addToCart(stock, widget.pharmacie);
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text("Quantité maximale en stock atteinte.")),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      // Bouton Ajouter initial
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          final success = appState.addToCart(stock, widget.pharmacie);
                                          if (!success) {
                                            _showClearCartDialog(context, appState, stock);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 14, color: Colors.white),
                                        label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          
          // Barre flottante du Panier en bas si articles présents dans cette pharmacie
          if (hasItemsInThisPharmacy) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF047857), // Vert Émeraude sombre
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF047857).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${appState.cartCount} médicament(s)",
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${appState.cartSubtotal} FCFA",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Fermer le stock
                      if (widget.onCheckoutRequested != null) {
                        widget.onCheckoutRequested!();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF047857),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      children: [
                        Text('Passer la commande', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Blocs de Skeletons animés clignotants pendant le chargement
  Widget _buildSkeletons() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return const SkeletonItem();
      },
    );
  }
}

// Composant individuel de Skeleton Loader
class SkeletonItem extends StatefulWidget {
  const SkeletonItem({super.key});

  @override
  State<SkeletonItem> createState() => _SkeletonItemState();
}

class _SkeletonItemState extends State<SkeletonItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gradientPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _gradientPosition = Tween<double>(begin: -1.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double value = _gradientPosition.value;
        return Opacity(
          opacity: 0.5 + (value.abs() * 0.3), // Fait pulser l'opacité
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 16,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 220,
                        height: 12,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 70,
                        height: 10,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 80,
                      height: 16,
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 24,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
