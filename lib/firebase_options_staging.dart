// Stub Firebase options so the project compiles before Firebase is configured.
// Replace it by running:
//   flutterfire configure --project=<staging-project-id> --out=lib/firebase_options_staging.dart
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
    apiKey: 'stub',
    appId: 'stub',
    messagingSenderId: 'stub',
    projectId: 'stub',
  );
}
