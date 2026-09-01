import 'package:flutter/material.dart';
import '../models/game_config.dart';
import '../services/firestore_service.dart';
import 'game_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGameConfig();
  }

  Future<void> _loadGameConfig() async {
    try {
      final config = await FirestoreService('2e6ec32a-1f42-4902-bc72-22bf81cc3ca6').getGameConfig();
      if (config != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GameScreen(config: config)),
        );
      } else if (mounted) {
        setState(() { _error = 'Game configuration not found'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Failed to load game: ' + e.toString(); _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const Icon(Icons.quiz, size: 80, color: Color(0xFF00BFA5)),
                const SizedBox(height: 32),
                const CircularProgressIndicator(color: Color(0xFF00BFA5)),
                const SizedBox(height: 16),
                const Text('Loading...', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
              if (_error != null) ...[
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadGameConfig, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}