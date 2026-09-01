import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  int _coins = 100;
  String? _gameId;
  String? _userId;

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  int get coins => _coins;
  VoidCallback? onPurchased;

  static const List<String> coinProductIds = [
    'coins1', 'coins2', 'coins3', 'coins4',
  ];

  static int coinsForProduct(String id) {
    switch (id) {
      case 'coins1': return 1000;
      case 'coins2': return 2500;
      case 'coins3': return 5000;
      case 'coins4': return 10000;
      default: return 0;
    }
  }

  Future<void> initialize({String? gameId, String? userId}) async {
    _gameId = gameId;
    _userId = userId;
    await _loadBalance();
    if (!kIsWeb) {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) return;
      _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate, onDone: () => _subscription?.cancel(), onError: (e) => debugPrint('IAP error: ' + e.toString()));
    }
  }

  Future<void> loadProducts() async {
    if (kIsWeb || !_isAvailable) return;
    final response = await _iap.queryProductDetails(coinProductIds.toSet());
    _products = response.productDetails;
  }

  Future<void> buyCoins(ProductDetails product) async {
    if (kIsWeb || !_isAvailable) return;
    await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> addCoins(int amount) async {
    _coins += amount;
    await _saveBalance();
  }

  Future<bool> spendCoins(int amount) async {
    if (_coins < amount) return false;
    _coins -= amount;
    await _saveBalance();
    return true;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        final coins = coinsForProduct(purchase.productID);
        if (coins > 0) addCoins(coins);
      }
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
    onPurchased?.call();
  }

  Future<void> _loadBalance() async {
    if (_userId == null || _gameId == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('games').doc(_gameId).collection('users').doc(_userId).get();
      if (doc.exists && doc.data()?['coins'] != null) {
        _coins = doc.data()!['coins'] as int;
      }
    } catch (e) {
      debugPrint('Failed to load coin balance: ' + e.toString());
    }
  }

  Future<void> _saveBalance() async {
    if (_userId == null || _gameId == null) return;
    try {
      await FirebaseFirestore.instance.collection('games').doc(_gameId).collection('users').doc(_userId).set({'coins': _coins}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save coin balance: ' + e.toString());
    }
  }

  void dispose() => _subscription?.cancel();
}