import 'package:flutter/material.dart';
import '../models/game_config.dart';
import '../widgets/game_engine.dart';
import '../services/iap_service.dart';

class GameScreen extends StatefulWidget {
  final GameConfig config;
  const GameScreen({super.key, required this.config});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _currentLevel = 0;
  final IAPService _iap = IAPService();

  int get _coins => _iap.coins;

  @override
  void initState() {
    super.initState();
    _iap.onPurchased = () { if (mounted) setState(() {}); };
    _iap.initialize(gameId: widget.config.id);
    if (widget.config.iapEnabled) {
      _iap.loadProducts();
    }
  }

  @override
  void dispose() {
    _iap.dispose();
    super.dispose();
  }

  void _onLevelComplete(int coinsEarned) {
    setState(() {
      if (widget.config.iapEnabled) _iap.addCoins(coinsEarned);
      _currentLevel++;
    });
  }

  void _onHintUsed() {
    if (widget.config.iapEnabled) {
      setState(() => _iap.spendCoins(5));
    }
  }

  void _onSpendCoins(int amount) {
    setState(() {
      if (amount > 0) { _iap.spendCoins(amount); }
      else { _iap.addCoins(-amount); }
    });
  }

  void _onBuyCoins(String productId) {
    final product = _iap.products.firstWhere((p) => p.id == productId, orElse: () => throw Exception("Product not found: $productId"));
    _iap.buyCoins(product);
  }

  void _onPrevLevel() {
    if (_currentLevel > 0) {
      setState(() => _currentLevel--);
    }
  }

  void _onNextLevel() {
    if (_currentLevel < widget.config.levels.length - 1) {
      setState(() => _currentLevel++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameEngine(
        config: widget.config,
        currentLevel: _currentLevel,
        coins: _coins,
        iapEnabled: widget.config.iapEnabled,
        onLevelComplete: _onLevelComplete,
        onHintUsed: _onHintUsed,
        onSpendCoins: _onSpendCoins,
        onBuyCoins: widget.config.iapEnabled ? _onBuyCoins : null,
        onNavigatePrev: _currentLevel > 0 ? _onPrevLevel : null,
        onNavigateNext: _currentLevel < widget.config.levels.length - 1 ? _onNextLevel : null,
      ),
    );
  }
}