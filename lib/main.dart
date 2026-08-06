import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'models/dog.dart';
import 'models/kennel_box.dart';
import 'models/booking.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/sync_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("📩 Notifica in background: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting('it_IT', null);

    // 🔥 FIREBASE
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Permesso notifiche concesso');
      String? token;
      if (kIsWeb) {
        const vapidKey = "BHN9v0lMcrH1l5vNnXmC1c9aNv1qM8lP5vGJk1vE0lM"; // 🔥 SOSTITUISCI
        token = await messaging.getToken(vapidKey: vapidKey);
      } else {
        token = await messaging.getToken();
      }
      print('📱 Token FCM: $token');
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Notifica in primo piano: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📩 Utente ha cliccato sulla notifica');
    });

    // SUPABASE
    await Supabase.initialize(
      url: 'https://rwdjpmgpqtebrnsvshty.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ3ZGpwbWdwcXRlYnJuc3ZzaHR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3OTg1NzYsImV4cCI6MjEwMDM3NDU3Nn0.J381Men5RsiXVgukOlzVEO3mHRDdCdVIUXc5Xz8PFgc',
    );
    print('✅ Supabase inizializzato!');

    // HIVE
    await Hive.initFlutter();
    Hive.registerAdapter(DogAdapter());
    Hive.registerAdapter(KennelBoxAdapter());
    Hive.registerAdapter(BookingAdapter());

    await Hive.openBox<Dog>('dogs');
    await Hive.openBox<KennelBox>('kennel_boxes');
    await Hive.openBox<Booking>('bookings');
    print('✅ Hive inizializzato!');

    // SYNC
    final syncService = SyncService();
    syncService.initialize();

    if (await syncService.hasInternet()) {
      print('🔄 Sincronizzazione all\'avvio...');
      await syncService.syncAll();
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
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
