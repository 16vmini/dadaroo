import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Firebase configuration placeholder.
///
/// TODO: Replace these placeholder values with your actual Firebase project config.
/// Run `flutterfire configure` in your project directory to auto-generate this file,
/// or manually fill in the values from the Firebase Console:
///   Project Settings > General > Your apps > Config
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  // TODO: Replace with your Android Firebase config
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO-your-android-api-key',
    appId: 'TODO-your-android-app-id',
    messagingSenderId: 'TODO-your-sender-id',
    projectId: 'TODO-your-project-id',
    storageBucket: 'TODO-your-storage-bucket',
  );

  // TODO: Replace with your iOS Firebase config
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO-your-ios-api-key',
    appId: 'TODO-your-ios-app-id',
    messagingSenderId: 'TODO-your-sender-id',
    projectId: 'TODO-your-project-id',
    storageBucket: 'TODO-your-storage-bucket',
    iosBundleId: 'com.example.dadaroo',
  );
}
