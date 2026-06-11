import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmageo_app/main.dart';
import 'package:pharmageo_app/screens/auth_screen.dart';

void main() {
  setUpAll(() async {
    // Initialise les valeurs simulées pour SharedPreferences avant l'initialisation de Supabase
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://laebhzpqplbjlcgsvydg.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhZWJoenBxcGxiamxjZ3N2eWRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMzgyODQsImV4cCI6MjA5NjYxNDI4NH0.G-TvJjd6JRPJO5k1qH2YopjvXkzoFgV7rjCqAoQmE1M',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  testWidgets('App starts with SplashScreen and redirects to AuthScreen when session is null', (WidgetTester tester) async {
    // Construit l'application
    await tester.pumpWidget(const MyApp());

    // Effectue le premier frame et laisse les redirections se produire
    await tester.pumpAndSettle();

    // Vérifie que l'écran d'authentification est affiché
    expect(find.byType(AuthScreen), findsOneWidget);
  });
}
