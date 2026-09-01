import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'AIzaSyAzN4vJZlYmGVzm8sCsz1bEPawQEiKIc6k',
      appId: defaultTargetPlatform == TargetPlatform.iOS
          ? '1:311998863107:ios:placeholder'
          : defaultTargetPlatform == TargetPlatform.android
              ? '1:311998863107:android:placeholder'
              : '1:311998863107:web:76d4b682624e96d02cfb36',
      messagingSenderId: '311998863107',
      projectId: 'trivianinja-bff5c',
      storageBucket: 'trivianinja-bff5c.firebasestorage.app',
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS ? 'com.trivianinja.app' : null,
    ),
  );
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