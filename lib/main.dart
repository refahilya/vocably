import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    initError = e;
  }

  runApp(
    ProviderScope(
      child: initError == null
          ? const VocablyApp()
          : _InitErrorApp(error: initError),
    ),
  );
}

/// Fallback shown if Firebase itself fails to initialize — distinct from
/// any in-app Firestore/Auth error, which the auth flow already handles
/// gracefully once the app is running.
class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat aplikasi: $error'),
          ),
        ),
      ),
    );
  }
}
