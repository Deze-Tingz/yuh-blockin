// Firebase configuration for Yuh Blockin'
// Values from GoogleService-Info.plist (iOS) and google-services.json (Android)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // iOS configuration from GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC-M4RYBxmf4suI7oCiWBi95sYtgnEKQrE',
    appId: '1:383487814092:ios:e88f094f0cbb3a71e65569',
    messagingSenderId: '383487814092',
    projectId: 'yuh-blockin',
    storageBucket: 'yuh-blockin.firebasestorage.app',
    iosBundleId: 'com.dezetingz.yuhBlockin',
  );

  // Android configuration from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDLkXIA2LPdUn1gy2t1wQ2NMtlxXPhsg80',
    appId: '1:383487814092:android:71c19edf5322738fe65569',
    messagingSenderId: '383487814092',
    projectId: 'yuh-blockin',
    storageBucket: 'yuh-blockin.firebasestorage.app',
  );
}
