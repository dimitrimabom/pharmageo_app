import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/app_state_provider.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../models/livraison_model.dart';
import '../auth_screen.dart';

class LivreurMainScreen extends StatefulWidget {
  const LivreurMainScreen({super.key});

  @override
  State<LivreurMainScreen> createState() => _LivreurMainScreenState();
}

class _LivreurMainScreenState extends State<LivreurMainScreen> {
  int _currentIndex = 0;
  final List<Widget> _tabs = const [
    LivreurRadarTab(),
    LivreurActiveDeliveryTab(),
    LivreurGainsTab(),
  ];

  bool _isLoading = true;
  bool _needsPasswordCustomization = false;
  
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword1 = true;
  bool _obscurePassword2 = true;
  bool _isSavingPassword = false;

  @override
  void initState() {
    super.initState();
    _checkPasswordCustomization();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkPasswordCustomization() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final hasCustomized = prefs.getBool('has_customized_password_${user.id}') ?? false;
      if (mounted) {
        setState(() {
          _needsPasswordCustomization = !hasCustomized;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _isSavingPassword = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Mettre à jour le mot de passe dans Supabase Auth
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _passwordController.text.trim()),
        );

        // Enregistrer dans SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_customized_password_${user.id}', true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Mot de passe personnalisé avec succès !"),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          setState(() {
            _needsPasswordCustomization = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la personnalisation: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    if (_needsPasswordCustomization) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        size: 48,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Première Connexion',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pour des raisons de sécurité, veuillez définir un nouveau mot de passe personnalisé avant de commencer à recevoir les commandes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Nouveau mot de passe
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword1,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword1 = !_obscurePassword1),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'Le mot de passe doit faire 6 caractères minimum.' : null,
                    ),
                    const SizedBox(height: 16),

                    // Confirmer mot de passe
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword2,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF94A3B8), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword2 = !_obscurePassword2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirmez votre mot de passe';
                        if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Bouton Enregistrer
                    ElevatedButton(
                      onPressed: _isSavingPassword ? null : _saveNewPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSavingPassword
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Définir mon mot de passe", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),

                    // Retour/Déconnexion si besoin
                    TextButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const AuthScreen()),
                          );
                        }
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      child: const Text("Annuler et se déconnecter", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            HapticFeedback.lightImpact();
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: const Color(0xFF94A3B8),
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.radar_outlined),
              activeIcon: Icon(Icons.radar_rounded),
              label: 'Radar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.motorcycle_outlined),
              activeIcon: Icon(Icons.motorcycle_rounded),
              label: 'Livraison',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monetization_on_outlined),
              activeIcon: Icon(Icons.monetization_on_rounded),
              label: 'Gains',
            ),
          ],
        ),
      ),
    );
  }
}

// ================= TAB 1 : RADAR DE COURSES =================
class LivreurRadarTab extends StatefulWidget {
  const LivreurRadarTab({super.key});

  @override
  State<LivreurRadarTab> createState() => _LivreurRadarTabState();
}

class _LivreurRadarTabState extends State<LivreurRadarTab> {
  final DbService _dbService = DbService();
  final AuthService _authService = AuthService();
  
  Position? _currentPosition;
  List<LivraisonModel> _availableCourses = [];
  bool _isScanning = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocationAndCourses();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    _realtimeChannel = Supabase.instance.client.channel('public:livraisons');
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'livraisons',
      callback: (payload) {
        // Rafraîchir les courses en arrière-plan sans perturber l'IHM du livreur
        _fetchCurrentLocationAndCourses(showLoader: false);
      },
    );
    _realtimeChannel!.subscribe();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchCurrentLocationAndCourses({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isScanning = true);
    }
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      final courses = await _dbService.fetchAvailableLivraisons();
      final userPharmacyId = await _dbService.fetchUserPharmacyId(_authService.currentUser!.id);
      
      // Proximité : Filtrer selon la pharmacie affectée ou à moins de 5 km de la pharmacie émettrice
      if (_currentPosition != null && mounted) {
        setState(() {
          _availableCourses = courses.where((c) {
            if (userPharmacyId != null) {
              return c.pharmacieId == userPharmacyId;
            }
            
            final pharmLat = c.pharmacie?.latitude ?? 3.8480;
            final pharmLng = c.pharmacie?.longitude ?? 11.5021;
            final distMeters = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              pharmLat,
              pharmLng,
            );
            return distMeters <= 5000; // 5 km max
          }).toList();
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print("Erreur scan radar: $e");
    } finally {
      if (showLoader && mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _acceptCourse(AppStateProvider appState, LivraisonModel livraison) async {
    final user = _authService.currentUser;
    if (user != null) {
      final success = await _dbService.acceptLivraison(livraison.id, user.id);
      if (success && mounted) {
        HapticFeedback.mediumImpact();
        appState.setActiveDelivery(livraison);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Course #${livraison.id} acceptée. Allez à l'onglet 'Livraison' pour commencer."),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _fetchCurrentLocationAndCourses(); // actualiser
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final isOnline = appState.isOnline;

    return Scaffold(
      appBar: AppBar(
        title: Text('Radar de Courses', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          if (isOnline)
            IconButton(
              icon: _isScanning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                  : const Icon(Icons.sync_rounded, color: Color(0xFF10B981)),
              onPressed: _isScanning ? null : _fetchCurrentLocationAndCourses,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Commutateur de disponibilité
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOnline ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnline ? "EN LIGNE (DISPONIBLE)" : "HORS LIGNE",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isOnline ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline ? "Vous recevez les commandes à proximité (5km)" : "Basculez pour commencer à rouler",
                        style: TextStyle(fontSize: 11, color: isOnline ? const Color(0xFF047857).withOpacity(0.8) : Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: isOnline,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (v) {
                      appState.toggleOnline();
                      if (v) _fetchCurrentLocationAndCourses();
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            Expanded(
              child: !isOnline
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text(
                            "Vous êtes hors ligne.\nActivez la disponibilité pour voir les courses.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : _isScanning
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                      : _availableCourses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_rounded, size: 60, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Aucune course disponible à moins de 5 km actuellement.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _availableCourses.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final course = _availableCourses[index];
                                final pharm = course.pharmacie;
                                
                                // Calcul distance
                                double distanceToPharm = 1.2;
                                if (_currentPosition != null && pharm != null) {
                                  distanceToPharm = Geolocator.distanceBetween(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                    pharm.latitude,
                                    pharm.longitude,
                                  ) / 1000;
                                }

                                // Estimer frais (Gains livreur)
                                final int estimatedGains = appState.calculateDeliveryFee(distanceToPharm + 2.0);

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Course #CMD-${course.id}",
                                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                                            ),
                                            Text(
                                              "$estimatedGains FCFA",
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF10B981),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(Icons.storefront_rounded, size: 16, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(pharm?.nom ?? 'Pharmacie émettrice', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.directions_bike_rounded, size: 16, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Text("À ${distanceToPharm.toStringAsFixed(1)} km de votre position", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text("Destination client : ~ 2.0 km de la pharmacie", style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        ElevatedButton(
                                          onPressed: appState.activeDelivery != null
                                              ? null // Une course à la fois
                                              : () => _acceptCourse(appState, course),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 0,
                                          ),
                                          child: Text(
                                            appState.activeDelivery != null ? "Course déjà en cours" : "Accepter la course",
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= TAB 2 : SUIVI ET VALIDATION LIVRAISON ACTIVE =================
class LivreurActiveDeliveryTab extends StatefulWidget {
  const LivreurActiveDeliveryTab({super.key});

  @override
  State<LivreurActiveDeliveryTab> createState() => _LivreurActiveDeliveryTabState();
}

class _LivreurActiveDeliveryTabState extends State<LivreurActiveDeliveryTab> {
  final DbService _dbService = DbService();
  final _supabase = Supabase.instance.client;
  
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  StreamSubscription<Position>? _positionSubscription;
  RealtimeChannel? _broadcastChannel;
  
  bool _isUpdating = false;
  bool _hasPickedUp = false;

  @override
  void initState() {
    super.initState();
    _checkAndInitTracking();
  }

  void _checkAndInitTracking() {
    final appState = context.read<AppStateProvider>();
    final active = appState.activeDelivery;
    
    if (active != null) {
      _hasPickedUp = active.statut == 'EN_COURS'; // Si déjà en cours, c'est que le colis est récupéré
      _startGpsBroadcasting(active.id);
    }
  }

  // Diffuser les coordonnées GPS du livreur en temps réel vers Supabase
  Future<void> _startGpsBroadcasting(int livraisonId) async {
    // 1. Initialiser le canal de broadcast Supabase
    _broadcastChannel = _supabase.channel('tracking:$livraisonId');
    _broadcastChannel!.subscribe();

    // 2. Écouter la position GPS locale et diffuser chaque changement
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Tous les 10 mètres
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (_broadcastChannel != null) {
        _broadcastChannel!.sendBroadcastMessage(
          event: 'location',
          payload: {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    if (_broadcastChannel != null) _supabase.removeChannel(_broadcastChannel!);
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _pickupPackage(AppStateProvider appState, LivraisonModel delivery) async {
    HapticFeedback.mediumImpact();
    setState(() => _isUpdating = true);
    
    // Mettre à jour en BDD
    final success = await _dbService.updateLivraisonStatus(delivery.id, 'EN_COURS');
    if (success && mounted) {
      setState(() {
        _hasPickedUp = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Colis récupéré. En route vers le client !"), backgroundColor: Color(0xFF10B981)),
      );
    }
    setState(() => _isUpdating = false);
  }

  Future<void> _completeDelivery(AppStateProvider appState, LivraisonModel delivery) async {
    if (!_formKey.currentState!.validate()) return;
    
    HapticFeedback.lightImpact();

    // Vérifier le code PIN
    final enteredPin = _pinController.text.trim();
    if (enteredPin != delivery.codeSecurite) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Code de sécurité incorrect ! Veuillez demander le bon code au patient."),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    // Mettre à jour en BDD -> LIVRE
    final success = await _dbService.updateLivraisonStatus(delivery.id, 'LIVRE');
    
    if (success && mounted) {
      // Calculer les gains de livraison accumulés
      final int gains = appState.calculateDeliveryFee(3.0); // Forfait / distance simulée
      appState.completeActiveDelivery(gains);

      // Stopper la diffusion GPS
      _positionSubscription?.cancel();
      if (_broadcastChannel != null) {
        _supabase.removeChannel(_broadcastChannel!);
      }

      _pinController.clear();
      _hasPickedUp = false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Livraison clôturée avec succès ! Gains enregistrés."),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
    
    setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final delivery = appState.activeDelivery;

    if (delivery == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_run_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  "Aucune livraison en cours actuellement.",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Text(
                  "Rendez-vous dans l'onglet 'Radar' et passez en ligne pour accepter une course.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pharm = delivery.pharmacie;
    final pharmLatLng = LatLng(pharm?.latitude ?? 3.8480, pharm?.longitude ?? 11.5021);
    final patientLatLng = LatLng(pharmLatLng.latitude - 0.008, pharmLatLng.longitude + 0.008);

    return Scaffold(
      appBar: AppBar(
        title: Text("Course active #${delivery.id}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Carte routière
          Expanded(
            flex: 2,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: pharmLatLng,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pharmageo.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pharmLatLng,
                      width: 35,
                      height: 35,
                      child: const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF10B981), size: 28),
                    ),
                    Marker(
                      point: patientLatLng,
                      width: 35,
                      height: 35,
                      child: const Icon(Icons.home_rounded, color: Colors.blue, size: 28),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Panel d'actions de livraison
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Infos Itinéraire
                      Text(
                        _hasPickedUp ? "Destination : Client (Patient)" : "Étape 1 : Récupérer le colis à la pharmacie",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 12),
                      
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            ...List.generate(delivery.pharmaciesDetours.length, (idx) {
                              final pName = delivery.pharmaciesDetours[idx];
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        idx == 0 ? Icons.store_rounded : Icons.storefront_rounded,
                                        size: 16,
                                        color: idx == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          pName + (idx > 0 ? " (Détour)" : " (Départ)"),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(left: 7.0),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(height: 16, child: VerticalDivider(width: 2, color: Colors.grey)),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            Row(
                              children: [
                                const Icon(Icons.person_pin_circle_rounded, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    "Adresse Patient (voir application client)",
                                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions dynamiques selon l'étape
                      if (!_hasPickedUp) ...[
                        ElevatedButton(
                          onPressed: _isUpdating ? null : () => _pickupPackage(appState, delivery),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isUpdating
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Colis récupéré", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ] else ...[
                        // Étape Validation PIN
                        Text(
                          "Étape 2 : Confirmer la livraison (PIN)",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8.0),
                          decoration: InputDecoration(
                            hintText: "0000",
                            hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 0.0),
                            counterText: "",
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                          ),
                          validator: (v) {
                            if (v == null || v.length != 4) return "Entrez le PIN à 4 chiffres fourni par le client";
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _isUpdating ? null : () => _completeDelivery(appState, delivery),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isUpdating
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Livraison terminée (Confirmer PIN)", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TAB 3 : APERÇU DES GAINS =================
class LivreurGainsTab extends StatelessWidget {
  const LivreurGainsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: Text('Mes Gains', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carte des Gains Cumulés
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF047857), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "REVENUS D'AUJOURD'HUI",
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${appState.earningsToday} FCFA",
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniGainStat("Courses complétées", "${appState.completedDeliveriesToday}"),
                      _buildMiniGainStat("Taux d'acceptation", "100%"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            Text("Historique de session", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B))),
            const SizedBox(height: 12),

            if (appState.completedDeliveriesToday == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    Icon(Icons.monetization_on_outlined, size: 54, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    Text(
                      "Aucune course complétée aujourd'hui.",
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: appState.completedDeliveriesToday,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
                  itemBuilder: (context, index) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.08),
                        child: const Icon(Icons.check_rounded, color: Color(0xFF10B981)),
                      ),
                      title: Text("Course validée", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1E293B))),
                      subtitle: Text("Livraison terminée avec succès", style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      trailing: const Text(
                        "+ 750 FCFA",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF10B981)),
                      ),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 24),

            // Déconnexion
            TextButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await authService.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Déconnexion du compte', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniGainStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
