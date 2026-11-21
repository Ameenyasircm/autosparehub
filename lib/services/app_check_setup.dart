import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Turns on Firebase App Check so Firestore, Realtime Database and Auth can
/// reject requests that do not come from the genuine, unmodified app
/// (scripts using the public API key, tampered APKs, emulators...).
///
/// Release builds use Play Integrity (Android) / App Attest (iOS). Debug
/// builds use the debug provider: on first run the app logs
/// "Enter this debug secret into the allow list in the Firebase Console",
/// and that token must be added under App Check > Apps > Manage debug tokens.
///
/// Activation alone blocks nothing. Requests are only rejected after
/// enforcement is switched on per product in the Firebase console.
Future<void> activateAppCheck([FirebaseApp? app]) async {
  try {
    final appCheck =
        app == null ? FirebaseAppCheck.instance : FirebaseAppCheck.instanceFor(app: app);
    await appCheck.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}
