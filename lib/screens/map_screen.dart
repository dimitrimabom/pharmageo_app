import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/geo_service.dart';
import '../services/db_service.dart';
import '../models/pharmacie_model.dart';
import '../providers/app_state_provider.dart';
import 'stocks_dialog.dart';

class MapScreen extends StatefulWidget {
  final VoidCallback? onCheckoutRequested;

  const MapScreen({super.key, this.onCheckoutRequested});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GeoService _geoService = GeoService();
  final DbService _dbService = DbService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  Position? _currentPosition;
  List<PharmacieModel> _allPharmacies = [];
  bool _isLoading = true;
  
  // Recherche et filtrage
  String _searchQuery = "";
  bool _isSearching = false;
  Set<int> _filteredPharmacyIds = {}; // Contient les IDs des pharmacies qui ont le médoc recherché en stock
  
  PharmacieModel? _selectedPharmacie;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      // 1. Obtenir la position GPS du téléphone
      final position = await _geoService.determinePosition();
      // 2. Obtenir la liste des pharmacies en BDD
      final pharmacies = await _geoService.fetchPharmacies();

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _allPharmacies = pharmacies;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'initialisation GPS : $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _recenterMap() async {
    HapticFeedback.lightImpact();
    try {
      final position = await _geoService.determinePosition();
      setState(() {
        _currentPosition = position;
      });
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de recentrer : $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // Effectue la recherche globale du médicament en BDD
  Future<void> _executeSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = "";
        _isSearching = false;
        _filteredPharmacyIds.clear();
      });
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isSearching = true);

    final matchingStocks = await _dbService.searchMedicamentInStocks(query);
    final ids = matchingStocks.map((s) => s.pharmacieId).toSet();

    if (!mounted) return;
    setState(() {
      _searchQuery = query;
      _filteredPharmacyIds = ids;
      _isSearching = false;
    });

    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aucune pharmacie ne possède "$query" en stock actuellement.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  String _calculateDistance(double pharmacyLat, double pharmacyLng) {
    if (_currentPosition == null) return '';
    final distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      pharmacyLat,
      pharmacyLng,
    );
    if (distanceInMeters >= 1000) {
      final distanceInKm = distanceInMeters / 1000;
      return 'À ${distanceInKm.toStringAsFixed(1)} km';
    } else {
      return 'À ${distanceInMeters.toStringAsFixed(0)} m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    
    // Filtrage des pharmacies affichées
    final displayedPharmacies = _searchQuery.isEmpty
        ? _allPharmacies
        : _allPharmacies.where((p) => _filteredPharmacyIds.contains(p.id)).toList();

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text('Localisation GPS en cours...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : Stack(
              children: [
                // Carte OpenStreetMap principale
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : const LatLng(3.8480, 11.5021),
                    initialZoom: 14.5,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedPharmacie = null;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pharmageo.app',
                    ),
                    
                    // Couche des Marqueurs
                    MarkerLayer(
                      markers: [
                        // 🔵 Position du patient
                        if (_currentPosition != null)
                          Marker(
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 50,
                            height: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.25),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // 🟢 Positions des pharmacies partenaires filtrées
                        ...displayedPharmacies.map((pharmacie) {
                          final isSelected = _selectedPharmacie?.id == pharmacie.id;
                          return Marker(
                            point: LatLng(pharmacie.latitude, pharmacie.longitude),
                            width: isSelected ? 55 : 44,
                            height: isSelected ? 55 : 44,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedPharmacie = pharmacie;
                                });
                                _mapController.move(
                                  LatLng(pharmacie.latitude, pharmacie.longitude),
                                  15.0,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: isSelected ? const Color(0xFF047857) : const Color(0xFF10B981),
                                      size: isSelected ? 55 : 44,
                                    ),
                                    Positioned(
                                      top: isSelected ? 9 : 7,
                                      child: Icon(
                                        Icons.local_pharmacy_rounded,
                                        color: Colors.white,
                                        size: isSelected ? 20 : 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),

                // 🔍 Barre de recherche flottante (Design premium)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 14),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _executeSearch,
                      decoration: InputDecoration(
                        hintText: "Rechercher un médicament (ex: Doliprane)...",
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _executeSearch("");
                                },
                              )
                            : const Icon(Icons.mic_rounded, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                // 🏷️ Bannière de filtre actif
                if (_searchQuery.isNotEmpty)
                  Positioned(
                    top: 80,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B), // Ardoise foncée
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_alt_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Filtre : $_searchQuery (${displayedPharmacies.length} pharmacies)',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _executeSearch("");
                              },
                              child: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 🛒 Bannière panier flottante en bas de l'écran si le panier contient des articles (masqué si un détail de pharmacie est affiché)
                if (appState.cartCount > 0 && _selectedPharmacie == null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Votre panier chez ${appState.cartPharmacy?.nom}",
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                "${appState.cartCount} produit(s) • ${appState.cartSubtotal} FCFA",
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              if (widget.onCheckoutRequested != null) {
                                widget.onCheckoutRequested!();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF10B981),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Commander', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 📄 Panneau flottant de détail de la pharmacie sélectionnée
                if (_selectedPharmacie != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _buildFloatingDetailsCard(_selectedPharmacie!),
                  ),
              ],
            ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: _selectedPharmacie != null
              ? 230.0
              : (appState.cartCount > 0 ? 80.0 : 0.0),
        ),
        child: FloatingActionButton(
          onPressed: _recenterMap,
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.my_location_rounded),
        ),
      ),
    );
  }

  // Widget de panneau flottant de détail de la pharmacie sélectionnée
  Widget _buildFloatingDetailsCard(PharmacieModel pharmacie) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône de pharmacie verte Material
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  color: Color(0xFF10B981),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // Détails textuels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pharmacie.nom,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pharmacie.adresse ?? 'Aucune adresse enregistrée',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Statut de confiance
                    Text(
                      _currentPosition != null
                          ? "Ouverte (24/7) • ${_calculateDistance(pharmacie.latitude, pharmacie.longitude)}"
                          : "Ouverte (24/7)",
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton fermer (X) discret
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedPharmacie = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.grey,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bouton consulter les stocks
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => StocksDialog(
                    pharmacie: pharmacie,
                    onCheckoutRequested: widget.onCheckoutRequested,
                  ),
                );
              },
              icon: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 18),
              label: const Text('Consulter les stocks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}