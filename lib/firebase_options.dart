import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD3KMPOeV-QK4h7CcjBANcbRYATLas0jsc',
    appId: '1:33133754624:web:ebd31dded5cff1b0909be5',
    messagingSenderId: '33133754624',
    projectId: 'dadaroo',
    storageBucket: 'dadaroo.firebasestorage.app',
    authDomain: 'dadaroo.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCMFkwoCQ7_sRqF7dve8GEfJgq3aGjr8P8',
    appId: '1:33133754624:android:46702b5ca6227087909be5',
    messagingSenderId: '33133754624',
    projectId: 'dadaroo',
    storageBucket: 'dadaroo.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB3-N5KwVMHmZ41RTmmppaVm80uXeR9yxo',
    appId: '1:33133754624:ios:f8cbc0d8e9b53f84909be5',
    messagingSenderId: '33133754624',
    projectId: 'dadaroo',
    storageBucket: 'dadaroo.firebasestorage.app',
    iosBundleId: 'com.dadaroo.dadaroo',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB3-N5KwVMHmZ41RTmmppaVm80uXeR9yxo',
    appId: '1:33133754624:ios:f8cbc0d8e9b53f84909be5',
    messagingSenderId: '33133754624',
    projectId: 'dadaroo',
    storageBucket: 'dadaroo.firebasestorage.app',
    iosBundleId: 'com.dadaroo.dadaroo',
  );
}
