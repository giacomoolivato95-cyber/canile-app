import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/dog.dart';
import 'models/kennel_box.dart';
import 'models/booking.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ==============================================
    // 1. INIZIALIZZA I DATI LOCALI (formato data)
    // ==============================================
    await initializeDateFormatting('it_IT', null);

    // ==============================================
    // 2. INIZIALIZZA SUPABASE
    // ==============================================
    await Supabase.initialize(
      url: 'https://rwdjpmgpqtebrnsvshty.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ3ZGpwbWdwcXRlYnJuc3ZzaHR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3OTg1NzYsImV4cCI6MjEwMDM3NDU3Nn0.J381Men5RsiXVgukOlzVEO3mHRDdCdVIUXc5Xz8PFgc',
    );
    print('✅ Supabase inizializzato!');

    // ==============================================
    // 3. INIZIALIZZA HIVE (database locale)
    // ==============================================
    await Hive.initFlutter();
    Hive.registerAdapter(DogAdapter());
    Hive.registerAdapter(KennelBoxAdapter());
    Hive.registerAdapter(BookingAdapter());

    await Hive.openBox<Dog>('dogs');
    await Hive.openBox<KennelBox>('kennel_boxes');
    await Hive.openBox<Booking>('bookings');
    print('✅ Hive inizializzato!');

    // ==============================================
    // 4. INIZIALIZZA IL SYNC SERVICE
    // ==============================================
    final syncService = SyncService();
    syncService.initialize();
    print('✅ SyncService inizializzato!');

    // ==============================================
    // 5. 🔥 SINCRONIZZA ALL'AVVIO (se online)
    // ==============================================
    if (await syncService.hasInternet()) {
      print('🔄 Sincronizzazione all\'avvio...');
      try {
        final results = await syncService.syncAll();
        print('✅ Sincronizzazione iniziale completata!');
        print('📊 Risultati: $results');
      } catch (e) {
        print('❌ Errore sync iniziale: $e');
      }
    } else {
      print('⚠️ Offline: sync all\'avvio saltato');
    }

    print('✅ APP INIZIALIZZATA COMPLETAMENTE! 🎉');

  } catch (e) {
    print('❌ Errore inizializzazione: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canile App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          color: Colors.brown,
          foregroundColor: Colors.white,
        ),
      ),
      home: StreamBuilder(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}