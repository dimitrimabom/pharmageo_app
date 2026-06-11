import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/app_state_provider.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../models/livraison_model.dart';
import '../map_screen.dart';
import 'tracking_screen.dart';
import '../auth_screen.dart';
import 'patient_cart_tab.dart';

class PatientMainScreen extends StatefulWidget {
  const PatientMainScreen({super.key});

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  final DbService _dbService = DbService();

  // Liste des écrans (l'onglet Carte sera instancié de façon à ce qu'il puisse déclencher le checkout)
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      MapScreen(onCheckoutRequested: _openCheckoutBottomSheet),
      PatientCartTab(
        onNavigateToMap: () {
          setState(() {
            _currentIndex = 0;
          });
        },
        onCheckoutRequested: _openCheckoutBottomSheet,
      ),
      const PatientOrdersTab(),
      const PatientProfileTab(),
    ];

    // Vérifier s'il y a une commande active au démarrage
    _checkActiveOrderOnStart();
  }

  Future<void> _checkActiveOrderOnStart() async {
    final user = _authService.currentUser;
    if (user != null) {
      final orders = await _dbService.fetchPatientLivraisons(user.id);
      final active = orders.firstWhere(
        (o) => o.statut != 'LIVRE',
        orElse: () => LivraisonModel(
          id: -1, 
          statut: 'NONE', 
          creeLe: DateTime.now(), 
          pharmacieId: -1, 
          patientId: ''
        ),
      );
      if (active.id != -1 && mounted) {
        context.read<AppStateProvider>().setActiveOrder(active);
      }
    }
  }

  // Ouvre le tiroir de paiement/validation de commande (Checkout)
  void _openCheckoutBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CheckoutBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
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
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: const Color(0xFF10B981).withOpacity(0.15),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981));
              }
              return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8));
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF10B981), size: 24);
              }
              return const IconThemeData(color: Color(0xFF94A3B8), size: 24);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              HapticFeedback.lightImpact();
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.white,
            elevation: 0,
            height: 65,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Carte',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart_rounded),
                label: 'Panier',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Commandes',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= ONGLET COMMANDES PATIENT =================
class PatientOrdersTab extends StatefulWidget {
  const PatientOrdersTab({super.key});

  @override
  State<PatientOrdersTab> createState() => _PatientOrdersTabState();
}

class _PatientOrdersTabState extends State<PatientOrdersTab> {
  final DbService _dbService = DbService();
  final AuthService _authService = AuthService();
  List<LivraisonModel> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = _authService.currentUser;
    if (user != null) {
      final data = await _dbService.fetchPatientLivraisons(user.id);
      if (mounted) {
        setState(() {
          _history = data;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final active = appState.activeOrder;

    return Scaffold(
      appBar: AppBar(
        title: Text('Mes Commandes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadHistory();
              if (active != null) {
                // Recharger également la commande active
                _dbService.fetchPatientLivraisons(_authService.currentUser!.id).then((orders) {
                  final updatedActive = orders.firstWhere((o) => o.id == active.id, orElse: () => active);
                  appState.setActiveOrder(updatedActive);
                });
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        color: const Color(0xFF10B981),
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Commande active en cours
            if (active != null && active.statut != 'LIVRE') ...[
              Text(
                "Commande en cours",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TrackingScreen(livraison: active)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "CMD #CMD-${active.id}",
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Fournisseur : ${active.pharmacie?.nom ?? 'Pharmacie'}",
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "STATUT : ${active.statut}",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Column(
                        children: [
                          Icon(Icons.location_searching_rounded, color: Colors.white, size: 32),
                          SizedBox(height: 4),
                          Text("Suivre", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // Historique des commandes
            Text(
              "Historique des commandes",
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Color(0xFF10B981)),
                ),
              )
            else if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60.0),
                child: Column(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      "Aucune commande passée pour le moment.",
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final cmd = _history[index];
                  final isCompleted = cmd.statut == 'LIVRE';

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Commande #CMD-${cmd.id}",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                          Text(
                            cmd.statut,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Pharmacie : ${cmd.pharmacie?.nom ?? 'Pharmacie'}"),
                          const SizedBox(height: 4),
                          Text(
                            "Date : ${cmd.creeLe.day.toString().padLeft(2, '0')}/${cmd.creeLe.month.toString().padLeft(2, '0')}/${cmd.creeLe.year} à ${cmd.creeLe.hour.toString().padLeft(2, '0')}:${cmd.creeLe.minute.toString().padLeft(2, '0')}",
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Si active -> Suivre, sinon détails
                        if (!isCompleted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TrackingScreen(livraison: cmd)),
                          );
                        } else {
                          _showOrderDetailsDialog(context, cmd);
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Affiche un dialogue avec le détail des médicaments de la commande passée (Invoice PDF equivalence)
  void _showOrderDetailsDialog(BuildContext context, LivraisonModel cmd) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Détails de la Commande", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Officine : ${cmd.pharmacie?.nom}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            const Text("Articles commandés :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            ...cmd.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${item.quantite}x ${item.designation}", style: const TextStyle(fontSize: 12)),
                  Text("${item.total} FCFA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Sous-total :", style: TextStyle(fontSize: 12)),
                Text("${cmd.totalHT} FCFA", style: const TextStyle(fontSize: 12)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TVA (19.25%) :", style: TextStyle(fontSize: 12)),
                Text("${cmd.totalTVA} FCFA", style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Payé (TTC) :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
                Text("${cmd.totalTTC} FCFA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ================= ONGLET PROFIL PATIENT =================
class PatientProfileTab extends StatefulWidget {
  const PatientProfileTab({super.key});

  @override
  State<PatientProfileTab> createState() => _PatientProfileTabState();
}

class _PatientProfileTabState extends State<PatientProfileTab> {
  final AuthService _authService = AuthService();
  final _phoneController = TextEditingController();
  final _domicileController = TextEditingController();
  final _travailController = TextEditingController();

  String _nom = "Patient";
  String _email = "";
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = _authService.currentUser;
    if (user != null) {
      _email = user.email ?? "";
      final prof = await _authService.fetchUserProfile(user.id);
      if (prof != null && mounted) {
        setState(() {
          _nom = prof.nom;
          _phoneController.text = prof.telephone ?? "";
        });
      }
      
      // Charger les adresses locales depuis SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _domicileController.text = prefs.getString('addr_domicile') ?? "";
          _travailController.text = prefs.getString('addr_travail') ?? "";
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    
    final user = _authService.currentUser;
    if (user != null) {
      // 1. Enregistrer le téléphone en BDD
      await Supabase.instance.client
          .from('profils')
          .update({'telephone': _phoneController.text.trim()})
          .eq('id', user.id);

      // 2. Enregistrer les adresses locales
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('addr_domicile', _domicileController.text.trim());
      await prefs.setString('addr_travail', _travailController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil et adresses enregistrés avec succès !'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
    
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mon Profil', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar & Name Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF10B981), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nom, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E293B))),
                        Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Formulaires de configuration
            Text("Informations de contact", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B))),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _buildInputDecoration("Téléphone mobile", Icons.phone_android_rounded),
            ),
            const SizedBox(height: 24),

            Text("Adresses favorites", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B))),
            const SizedBox(height: 12),
            TextField(
              controller: _domicileController,
              decoration: _buildInputDecoration("Adresse Domicile", Icons.home_rounded),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _travailController,
              decoration: _buildInputDecoration("Adresse Travail", Icons.work_rounded),
            ),
            const SizedBox(height: 32),

            // Bouton Enregistrer
            ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer le Profil', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),

            // Déconnexion
            TextButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await _authService.signOut();
                if (!mounted) return;
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
              label: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
    );
  }
}

// ================= TIROIR CHECKOUT (COMMANDE) =================
class CheckoutBottomSheet extends StatefulWidget {
  const CheckoutBottomSheet({super.key});

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  final DbService _dbService = DbService();
  final AuthService _authService = AuthService();
  
  String _addressType = "GPS"; // GPS, Domicile, Travail
  bool _isPlacingOrder = false;
  double _distanceKm = 0.0;
  int _deliveryFee = 500;

  @override
  void initState() {
    super.initState();
    _calculateProximityAndFees();
  }

  Future<void> _calculateProximityAndFees() async {
    final appState = context.read<AppStateProvider>();
    final pharmacy = appState.cartPharmacy;
    if (pharmacy == null) return;

    try {
      // Obtenir la position GPS actuelle
      final position = await Geolocator.getCurrentPosition();
      final distMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        pharmacy.latitude,
        pharmacy.longitude,
      );
      
      setState(() {
        _distanceKm = distMeters / 1000;
        _deliveryFee = appState.calculateDeliveryFee(_distanceKm);
      });
    } catch (e) {
      // En cas de permission GPS désactivée, on met des frais forfaitaires (1 000 FCFA)
      setState(() {
        _distanceKm = 3.0;
        _deliveryFee = 750;
      });
    }
  }

  Future<void> _placeOrder(AppStateProvider appState) async {
    HapticFeedback.mediumImpact();
    setState(() => _isPlacingOrder = true);

    final user = _authService.currentUser;
    final pharmacy = appState.cartPharmacy;

    if (user != null && pharmacy != null) {
      // Déterminer l'adresse finale de livraison
      String finalAddress = "Position GPS Actuelle";
      if (_addressType == "Domicile" || _addressType == "Travail") {
        final prefs = await SharedPreferences.getInstance();
        finalKey = _addressType == "Domicile" ? 'addr_domicile' : 'addr_travail';
        finalAddress = prefs.getString(finalKey) ?? "";
        if (finalAddress.isEmpty) {
          finalAddress = _addressType; // Valeur de secours
        }
      }

      // 1. Insérer la livraison dans Supabase
      final newLivraison = await _dbService.createLivraison(
        pharmacieId: pharmacy.id,
        patientId: user.id,
      );

      if (!mounted) return;

      if (newLivraison != null) {
        // Enregistrer la commande active et vider le panier
        appState.setActiveOrder(newLivraison);
        appState.clearCart();

        Navigator.pop(context); // Fermer le Checkout bottomsheet
        HapticFeedback.mediumImpact();

        // Rediriger vers l'écran de suivi
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TrackingScreen(livraison: newLivraison)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la validation. Réessayez.'), backgroundColor: Colors.redAccent),
        );
      }
    }

    setState(() => _isPlacingOrder = false);
  }

  String finalKey = ""; // Variable utilitaire pour SharedPreferences

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final pharmacy = appState.cartPharmacy;
    if (pharmacy == null) return const SizedBox();

    final totalHT = appState.cartSubtotal;
    final totalTVA = (totalHT * 0.1925).round();
    final totalTTC = totalHT + totalTVA + _deliveryFee;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poignée
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 18),

          Text("Finaliser la Commande", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const SizedBox(height: 14),

          // Récapitulatif Articles
          const Text("Récapitulatif des médicaments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          ...appState.cart.values.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "${item.quantite}x ${item.stock.medicament!.nom.toUpperCase()} - ${item.pharmacy.nom}",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text("${item.total} FCFA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          )),
          const Divider(height: 20),

          // Adresse de livraison
          const Text("Adresse de destination", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          
          Row(
            children: [
              _buildAddressOption("GPS", Icons.gps_fixed_rounded, "Position GPS"),
              const SizedBox(width: 8),
              _buildAddressOption("Domicile", Icons.home_rounded, "Domicile"),
              const SizedBox(width: 8),
              _buildAddressOption("Travail", Icons.work_rounded, "Travail"),
            ],
          ),
          const SizedBox(height: 18),

          // Facturation détaillée
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Sous-total :", style: TextStyle(fontSize: 13)),
                    Text("$totalHT FCFA", style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TVA (19.25%) :", style: TextStyle(fontSize: 13)),
                    Text("$totalTVA FCFA", style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Frais de livraison (${_distanceKm.toStringAsFixed(1)} km${appState.cartPharmacies.length > 1 ? ' + ${appState.cartPharmacies.length - 1} détours' : ''}) :",
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text("$_deliveryFee FCFA", style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total à payer (TTC) :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text("$totalTTC FCFA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF10B981))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bouton Commander
          ElevatedButton(
            onPressed: _isPlacingOrder ? null : () => _placeOrder(appState),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isPlacingOrder
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Confirmer et Commander", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressOption(String type, IconData icon, String label) {
    final isSelected = _addressType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _addressType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981).withOpacity(0.08) : Colors.white,
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B), size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
