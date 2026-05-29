import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS:     return ios;
      default: return web;
    }
  }

  // ── Web (Chrome) ──────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyCAYp4ekRWsSk1hYv45Jul5aEyc86GTBec',
    authDomain:        'lexnland-2f518.firebaseapp.com',
    projectId:         'lexnland-2f518',
    storageBucket:     'lexnland-2f518.firebasestorage.app',
    messagingSenderId: '756869712541',
    appId:             '1:756869712541:web:21395687fef5c472e4a274',
    measurementId:     'G-KK96N2Q8P7',
  );

  // ── Android ───────────────────────────────────────────────
  // Add your google-services.json SHA-1 to Firebase Console
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyCAYp4ekRWsSk1hYv45Jul5aEyc86GTBec',
    authDomain:        'lexnland-2f518.firebaseapp.com',
    projectId:         'lexnland-2f518',
    storageBucket:     'lexnland-2f518.firebasestorage.app',
    messagingSenderId: '756869712541',
    appId:             '1:756869712541:web:21395687fef5c472e4a274',
  );

  // ── iOS ───────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyCAYp4ekRWsSk1hYv45Jul5aEyc86GTBec',
    authDomain:        'lexnland-2f518.firebaseapp.com',
    projectId:         'lexnland-2f518',
    storageBucket:     'lexnland-2f518.firebasestorage.app',
    messagingSenderId: '756869712541',
    appId:             '1:756869712541:web:21395687fef5c472e4a274',
  );
}
