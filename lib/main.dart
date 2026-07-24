import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/dog.dart';
import 'models/kennel_box.dart';
import 'models/booking.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inizializza i dati locali per il formato data italiano
    await initializeDateFormatting('it_IT', null);

    // Inizializza Supabase
    await Supabase.initialize(
      url: 'https://rwdjpmgpqtebrnsvshty.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ3ZGpwbWdwcXRlYnJuc3ZzaHR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3OTg1NzYsImV4cCI6MjEwMDM3NDU3Nn0.J381Men5RsiXVgukOlzVEO3mHRDdCdVIUXc5Xz8PFgc',
    );

    // Inizializza Hive
    await Hive.initFlutter();
    
    // Registra gli adapter
    Hive.registerAdapter(DogAdapter());
    Hive.registerAdapter(KennelBoxAdapter());
    Hive.registerAdapter(BookingAdapter());

    // Apri i box
    await Hive.openBox<Dog>('dogs');
    await Hive.openBox<KennelBox>('kennel_boxes');
    await Hive.openBox<Booking>('bookings');

    print('✅ App inizializzata correttamente!');
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