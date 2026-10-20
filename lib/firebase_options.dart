import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show appFlavor;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return currentAndroidPlatform;
      case TargetPlatform.windows:
        return windows;
      default:
        return currentAndroidPlatform;
    }
  }

  static FirebaseOptions get currentAndroidPlatform {
    if (appFlavor == 'admin') {
      return androidAdmin;
    }
    return androidUser;
  }

  /// Android configuration for the 'user' flavor
  static const FirebaseOptions androidUser = FirebaseOptions(
    apiKey: 'AIzaSyCUF9djASHGex4l_vIfd6aCHN1sa_lzzRo',
    appId: '1:157612280338:android:c7008abb9704a33e9fa6cb',
    messagingSenderId: '157612280338',
    projectId: 'autosparehub-ce005',
    storageBucket: 'autosparehub-ce005.firebasestorage.app',
  );

  /// Android configuration for the 'admin' flavor
  static const FirebaseOptions androidAdmin = FirebaseOptions(
    apiKey: 'AIzaSyCUF9djASHGex4l_vIfd6aCHN1sa_lzzRo',
    appId: '1:157612280338:android:3f4f0b84042bd5d79fa6cb',
    messagingSenderId: '157612280338',
    projectId: 'autosparehub-ce005',
    storageBucket: 'autosparehub-ce005.firebasestorage.app',
  );

  /// Default android fallback
  static const FirebaseOptions android = androidUser;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCUF9djASHGex4l_vIfd6aCHN1sa_lzzRo',
    appId: '1:157612280338:web:c7008abb9704a33e9fa6cb',
    messagingSenderId: '157612280338',
    projectId: 'autosparehub-ce005',
    storageBucket: 'autosparehub-ce005.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCUF9djASHGex4l_vIfd6aCHN1sa_lzzRo',
    appId: '1:157612280338:web:c7008abb9704a33e9fa6cb',
    messagingSenderId: '157612280338',
    projectId: 'autosparehub-ce005',
    storageBucket: 'autosparehub-ce005.firebasestorage.app',
  );
}
