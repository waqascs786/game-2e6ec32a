import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final options = kIsWeb
        ? const FirebaseOptions(
            apiKey: 'AIzaSyAzN4vJZlYmGVzm8sCsz1bEPawQEiKIc6k',
            appId: '1:311998863107:web:76d4b682624e96d02cfb36',
            messagingSenderId: '311998863107',
            projectId: 'trivianinja-bff5c',
            storageBucket: 'trivianinja-bff5c.firebasestorage.app',
          )
        : defaultTargetPlatform == TargetPlatform.iOS
            ? const FirebaseOptions(
                apiKey: 'AIzaSyAzN4vJZlYmGVzm8sCsz1bEPawQEiKIc6k',
                appId: '1:311998863107:ios:a492472970340e432cfb36',
                messagingSenderId: '311998863107',
                projectId: 'trivianinja-bff5c',
                storageBucket: 'trivianinja-bff5c.firebasestorage.app',
                iosBundleId: 'com.game19.ios',
              )
            : const FirebaseOptions(
                apiKey: 'AIzaSyAzN4vJZlYmGVzm8sCsz1bEPawQEiKIc6k',
                appId: '1:311998863107:android:placeholder',
                messagingSenderId: '311998863107',
                projectId: 'trivianinja-bff5c',
                storageBucket: 'trivianinja-bff5c.firebasestorage.app',
              );
    await Firebase.initializeApp(options: options);
  } catch (e) {
    debugPrint('Firebase init failed: ' + e.toString());
  }
  runApp(const TriviaGameApp());
}

class TriviaGameApp extends StatelessWidget {
  const TriviaGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game 19',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}