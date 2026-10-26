import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/firebase_emulator_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    // Gated on the compile-time constant itself so a normal build drops the
    // emulator code entirely (see firebase_emulator_config.dart).
    final useEmulators =
        kUseFirebaseEmulators &&
        resolveFirebaseTarget(
              useEmulators: kUseFirebaseEmulators,
              isRelease: kReleaseMode,
            ) ==
            FirebaseTarget.emulators;
    await Firebase.initializeApp(
      options: kUseFirebaseEmulators && useEmulators
          ? emulatorFirebaseOptions(DefaultFirebaseOptions.currentPlatform)
          : DefaultFirebaseOptions.currentPlatform,
    );
    if (kUseFirebaseEmulators && useEmulators) {
      await connectToFirebaseEmulators();
    }
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
