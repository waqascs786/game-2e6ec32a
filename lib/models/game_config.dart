class GameConfig {
  final String id;
  final String name;
  final String gameType;
  final Map<String, dynamic> design;
  final List<GameLevel> levels;
  final List<GameLevelPack> packs;
  final Map<String, dynamic> sounds;
  final Map<String, dynamic> icon;
  final Map<String, dynamic> settings;
  final List<CoinPackConfig> coinPacks;
  final bool iapEnabled;

  GameConfig({
    required this.id,
    required this.name,
    required this.gameType,
    required this.design,
    required this.levels,
    this.packs = const [],
    required this.sounds,
    required this.icon,
    required this.settings,
    required this.coinPacks,
    this.iapEnabled = true,
  });

  bool get hasPacks => packs.isNotEmpty;

  factory GameConfig.fromMap(Map<String, dynamic> m) {
    return GameConfig(
      id: m['id'] ?? '',
      name: m['name'] ?? '',
      gameType: m['gameType'] ?? 'guess_picture',
      design: Map<String, dynamic>.from(m['design'] ?? {}),
      levels: (m['levels'] as List?)?.map((l) => GameLevel.fromMap(l)).toList() ?? [],
      packs: (m['packs'] as List?)?.map((p) => GameLevelPack.fromMap(p)).toList() ?? [],
      sounds: Map<String, dynamic>.from(m['sounds'] ?? {}),
      icon: Map<String, dynamic>.from(m['icon'] ?? {}),
      settings: Map<String, dynamic>.from(m['settings'] ?? {}),
      coinPacks: (m['coinPacks'] as List?)?.map((p) => CoinPackConfig.fromMap(p)).toList() ?? [],
      iapEnabled: m['iapEnabled'] ?? true,
    );
  }
}

class GameLevel {
  final String id;
  final int order;
  final String imageUrl;
  final List<String> imageUrls;
  final String questionType;
  final String question;
  final String answer;
  final List<String> emojis;
  final List<String> options;
  final int coinsReward;
  final String hint;
  final bool locked;

  GameLevel({
    required this.id, required this.order, this.imageUrl = '',
    this.imageUrls = const [], this.questionType = '1pic1word',
    this.question = '', required this.answer, this.emojis = const [],
    this.options = const [], this.coinsReward = 10, this.hint = '',
    this.locked = false,
  });

  factory GameLevel.fromMap(Map<String, dynamic> m) => GameLevel(
    id: m['id'] ?? '', order: m['order'] ?? 0, imageUrl: m['imageUrl'] ?? '',
    imageUrls: List<String>.from(m['imageUrls'] ?? []),
    questionType: m['questionType'] ?? '1pic1word',
    question: m['question'] ?? '', answer: m['answer'] ?? '',
    emojis: List<String>.from(m['emojis'] ?? []),
    options: List<String>.from(m['options'] ?? []),
    coinsReward: m['coinsReward'] ?? 10, hint: m['hint'] ?? '',
    locked: m['locked'] ?? false,
  );
}

class GameLevelPack {
  final String id;
  final String name;
  final String iconUrl;
  final List<String> levelIds;
  final int order;
  bool locked;

  GameLevelPack({
    required this.id, required this.name, this.iconUrl = '',
    this.levelIds = const [], this.order = 0, this.locked = true,
  });

  factory GameLevelPack.fromMap(Map<String, dynamic> m) => GameLevelPack(
    id: m['id'] ?? '', name: m['name'] ?? '',
    iconUrl: m['iconUrl'] ?? '',
    levelIds: List<String>.from(m['levelIds'] ?? []),
    order: m['order'] ?? 0, locked: m['locked'] ?? true,
  );
}

class CoinPackConfig {
  final String id;
  final String name;
  final int coins;
  final double price;

  CoinPackConfig({required this.id, required this.name, required this.coins, required this.price});

  factory CoinPackConfig.fromMap(Map<String, dynamic> m) => CoinPackConfig(
    id: m['id'] ?? '', name: m['name'] ?? '',
    coins: m['coins'] ?? 0, price: (m['price'] ?? 0).toDouble(),
  );
}