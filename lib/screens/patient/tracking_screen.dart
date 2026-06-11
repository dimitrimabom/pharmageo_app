import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/livraison_model.dart';
import '../../services/db_service.dart';

class TrackingScreen extends StatefulWidget {
  final LivraisonModel livraison;

  const TrackingScreen({super.key, required this.livraison});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final DbService _dbService = DbService();
  final _supabase = Supabase.instance.client;
  
  late LivraisonModel _currentLivraison;
  LatLng? _driverPosition;
  RealtimeChannel? _dbChannel;
  RealtimeChannel? _locationChannel;
  
  bool _isLoadingDriver = true;
  String? _driverName;
  String? _driverPhone;

  @override
  void initState() {
    super.initState();
    _currentLivraison = widget.livraison;
    _initRealtimeTracking();
    _loadDriverProfile();
  }

  // Charger le profil du livreur assigné
  Future<void> _loadDriverProfile() async {
    if (_currentLivraison.livreurId == null) {
      setState(() => _isLoadingDriver = false);
      return;
    }
    
    try {
      final res = await _supabase
          .from('profils')
          .select('nom, telephone')
          .eq('id', _currentLivraison.livreurId!)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _driverName = res['nom'] as String;
          _driverPhone = res['telephone'] as String?;
          _isLoadingDriver = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDriver = false);
    }
  }

  void _initRealtimeTracking() {
    // 1. Écouter les changements de statut de la livraison en BDD (Postgres Changes)
    _dbChannel = _dbService.subscribeToLivraison(_currentLivraison.id, (updated) {
      if (!mounted) return;
      setState(() {
        _currentLivraison = updated;
      });
      
      // Si un livreur vient d'être assigné, charger ses infos
      if (updated.livreurId != null && _driverName == null) {
        _loadDriverProfile();
      }

      // Si la commande est livrée, retour haptique de succès
      if (updated.statut == 'LIVRE') {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Votre commande a été livrée ! Merci d'utiliser PharmaGeo."),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    });

    // 2. Écouter la position GPS diffusée par le livreur en direct (Realtime Broadcast)
    _locationChannel = _supabase.channel('tracking:${_currentLivraison.id}');
    _locationChannel!.onBroadcast(
      event: 'location',
      callback: (payload) {
        final double? lat = (payload['latitude'] as num?)?.toDouble();
        final double? lng = (payload['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null && mounted) {
          setState(() {
            _driverPosition = LatLng(lat, lng);
          });
        }
      },
    );
    _locationChannel!.subscribe();
  }

  @override
  void dispose() {
    if (_dbChannel != null) _supabase.removeChannel(_dbChannel!);
    if (_locationChannel != null) _supabase.removeChannel(_locationChannel!);
    super.dispose();
  }

  // Simuler l'appel téléphonique
  void _callDriver() {
    HapticFeedback.lightImpact();
    if (_driverPhone == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Text("Appeler le livreur", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          "Voulez-vous composer le numéro de ${_driverName ?? 'votre livreur'} ?\n\n"
          "Numéro : $_driverPhone"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Simulation d'appel vers $_driverPhone..."),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text("Appeler", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentLivraison.statut;
    final hasLivreur = _currentLivraison.livreurId != null;

    // Définir la position par défaut de la pharmacie et du domicile patient
    final pharmacyLatLng = LatLng(_currentLivraison.pharmacie?.latitude ?? 3.8480, _currentLivraison.pharmacie?.longitude ?? 11.5021);
    // Supposons une position patient fictive à 1.5km pour la carte
    final patientLatLng = LatLng(pharmacyLatLng.latitude - 0.008, pharmacyLatLng.longitude + 0.008);

    return Scaffold(
      appBar: AppBar(
        title: Text("Suivi Commande #${_currentLivraison.id}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🗺️ Carte de Suivi (Hauteur fixe 30%)
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: pharmacyLatLng,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pharmageo.app',
                    ),
                    MarkerLayer(
                      markers: [
                        // 🏬 Pharmacie
                        Marker(
                          point: pharmacyLatLng,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF10B981), size: 30),
                        ),
                        // 🏠 Client
                        Marker(
                          point: patientLatLng,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.home_rounded, color: Colors.blue, size: 32),
                        ),
                        // 🛵 Livreur (si assigné et position reçue)
                        if (status == 'EN_COURS' && _driverPosition != null)
                          Marker(
                            point: _driverPosition!,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                              child: const Icon(Icons.motorcycle_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Alerte si la livraison est en cours mais pas encore de coordonnées GPS
                if (status == 'EN_COURS' && _driverPosition == null)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 1.5),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Connexion GPS au livreur...",
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 📦 Progression & Détails (Hauteur restante 70%)
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Indicateurs d'Étapes (Stepper)
                    _buildStepper(status),
                    _buildDetourTimeline(),
                    const SizedBox(height: 24),

                    // 2. Encadré Code PIN de validation
                    if (status != 'LIVRE')
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "CODE DE SÉCURITÉ DE LIVRAISON",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentLivraison.codeSecurite,
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF047857),
                                letterSpacing: 6.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Veuillez communiquer ce code à 4 chiffres au livreur lorsqu'il vous remettra le colis pour valider la transaction.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    
                    if (status == 'LIVRE')
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Colis remis en mains propres avec succès. Transaction clôturée.",
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF047857), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // 3. Fiche du Livreur
                    Text("Livreur affecté", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 10),
                    
                    if (_isLoadingDriver)
                      const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                    else if (!hasLivreur)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hourglass_empty_rounded, color: Colors.grey, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "En attente d'acceptation par un livreur...",
                                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                              child: const Icon(Icons.motorcycle_rounded, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _driverName ?? "Livreur PharmaGeo",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _driverPhone ?? "Téléphone indisponible",
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (_driverPhone != null)
                              IconButton(
                                icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981)),
                                onPressed: _callDriver,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Constructeur de Stepper horizontal personnalisé premium
  Widget _buildStepper(String currentStatus) {
    final steps = ['EN_ATTENTE', 'PREPARATION', 'EN_COURS', 'LIVRE'];
    final labels = ['Reçue', 'Préparation', 'En route', 'Livrée'];
    
    int activeIndex = steps.indexOf(currentStatus);
    if (activeIndex == -1) activeIndex = 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final isCompleted = index < activeIndex;
        final isActive = index == activeIndex;
        final isLast = index == steps.length - 1;

        Color itemColor = Colors.grey[300]!;
        if (isCompleted || isActive) {
          itemColor = const Color(0xFF10B981);
        }

        return Expanded(
          child: Row(
            children: [
              // Indicateur Étape
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : itemColor,
                      border: Border.all(
                        color: itemColor,
                        width: isActive ? 5.0 : 1.0,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[index],
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: (isActive || isCompleted) ? FontWeight.bold : FontWeight.w500,
                      color: (isActive || isCompleted) ? const Color(0xFF1E293B) : Colors.grey,
                    ),
                  ),
                ],
              ),
              // Ligne de liaison
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                    color: isCompleted ? const Color(0xFF10B981) : Colors.grey[200],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDetourTimeline() {
    final pharmacies = _currentLivraison.pharmaciesDetours;
    if (pharmacies.length <= 1) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          "Itinéraire multi-pharmacies (Détours requis)",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB), // Ambre clair
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            children: List.generate(pharmacies.length + 1, (index) {
              final isLast = index == pharmacies.length;
              final String name = isLast ? "Votre Domicile (Livraison)" : pharmacies[index];
              final bool isMain = index == 0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Icon(
                          isLast
                              ? Icons.home_rounded
                              : (isMain ? Icons.local_pharmacy_rounded : Icons.store_rounded),
                          color: isLast
                              ? Colors.blue
                              : (isMain ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                          size: 18,
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 20,
                            color: const Color(0xFFF59E0B),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            isLast
                                ? "Destination de livraison finale"
                                : (isMain ? "Officine de départ" : "Étape de détour intermédiaire"),
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
