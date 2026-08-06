import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBEkv6cH_cLUMiq3qoXlybvnuan3Em94WQ",
    authDomain: "canilepensioni.firebaseapp.com",
    projectId: "canilepensioni",
    storageBucket: "canilepensioni.firebasestorage.app",
    messagingSenderId: "1076405604277",
    appId: "1:1076405604277:web:06b95fd4a04ae79c5213fc",
    measurementId: "G-185584N56R",
  );
}
