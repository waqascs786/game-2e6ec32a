import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_config.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String gameId;

  FirestoreService(this.gameId);

  Future<GameConfig?> getGameConfig() async {
    try {
      final doc = await _db.collection('games').doc(gameId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final content = data['content'];
        final flat = Map<String, dynamic>.from(data);
        if (content is Map<String, dynamic>) {
          flat['levels'] = content['levels'] ?? [];
          flat['packs'] = content['packs'] ?? [];
          if (content['sounds'] != null) flat['sounds'] = content['sounds'];
          if (content['design'] != null) flat['design'] = content['design'];
        }
        if (!flat.containsKey('levels') || flat['levels'] == null) flat['levels'] = [];
        if (!flat.containsKey('packs') || flat['packs'] == null) flat['packs'] = [];
        if (!flat.containsKey('coinPacks') || flat['coinPacks'] == null) flat['coinPacks'] = [];
        if (!flat.containsKey('sounds') || flat['sounds'] == null) flat['sounds'] = {};
        if (!flat.containsKey('icon') || flat['icon'] == null) flat['icon'] = {};
        if (!flat.containsKey('settings') || flat['settings'] == null) flat['settings'] = {};
        final monetization = data['monetization'];
        if (monetization is Map<String, dynamic>) {
          flat['iapEnabled'] = monetization['iapEnabled'] ?? true;
          if (monetization['coinPacks'] != null) flat['coinPacks'] = monetization['coinPacks'];
        }
        if (!flat.containsKey('iapEnabled') || flat['iapEnabled'] == null) flat['iapEnabled'] = true;
        return GameConfig.fromMap(flat);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveUserProgress(String userId, Map<String, dynamic> progress) async {
    await _db.collection('user_progress').doc(userId).collection('games').doc(gameId).set(progress, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProgress(String userId) async {
    final doc = await _db.collection('user_progress').doc(userId).collection('games').doc(gameId).get();
    return doc.exists ? doc.data() : null;
  }
}