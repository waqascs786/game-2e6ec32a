import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final FlutterInappPurchase _iap = FlutterInappPurchase.instance;
  StreamSubscription? _purchaseSub;
  List<ProductCommon> _products = [];
  bool _isAvailable = false;
  int _coins = 100;
  String? _gameId;
  String? _userId;

  List<ProductCommon> get products => _products;
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
      try {
        _isAvailable = await _iap.initConnection();
        if (!_isAvailable) return;
        _purchaseSub = _iap.purchaseUpdatedListener.listen(_onPurchaseUpdate, onError: (e) => debugPrint('IAP error: ' + e.toString()));
      } catch (e) {
        debugPrint('IAP init failed: ' + e.toString());
        _isAvailable = false;
      }
    }
  }

  Future<void> loadProducts() async {
    if (kIsWeb || !_isAvailable) return;
    try {
      _products = await _iap.fetchProducts(skus: coinProductIds, type: ProductQueryType.InApp);
    } catch (e) {
      debugPrint('Failed to load IAP products: ' + e.toString());
    }
  }

  Future<void> buyCoins(ProductCommon product) async {
    if (kIsWeb || !_isAvailable) return;
    try {
      await _iap.requestPurchase(
        RequestPurchaseProps.inApp((
          apple: RequestPurchaseIosProps(sku: product.id),
          google: RequestPurchaseAndroidProps(skus: [product.id]),
        )),
      );
    } catch (e) {
      debugPrint('IAP buy failed: ' + e.toString());
    }
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

  void _onPurchaseUpdate(Purchase purchase) {
    if (purchase.purchaseState == PurchaseState.Purchased) {
      final coins = coinsForProduct(purchase.productId);
      if (coins > 0) {
        addCoins(coins);
        debugPrint('Delivered ' + coins.toString() + ' coins for ' + purchase.productId);
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

  void dispose() {
    _purchaseSub?.cancel();
    _iap.endConnection();
  }
}