import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/game_config.dart';

enum _Screen { packSelect, levelSelect, playing, complete, buyCoins }

class GameEngine extends StatefulWidget {
  final GameConfig config;
  final int currentLevel;
  final int coins;
  final bool iapEnabled;
  final Function(int) onLevelComplete;
  final VoidCallback onHintUsed;
  final Function(int) onSpendCoins;
  final Function(String)? onBuyCoins;
  final VoidCallback? onNavigatePrev;
  final VoidCallback? onNavigateNext;

  const GameEngine({
    super.key,
    required this.config,
    required this.currentLevel,
    required this.coins,
    this.iapEnabled = true,
    required this.onLevelComplete,
    required this.onHintUsed,
    required this.onSpendCoins,
    this.onBuyCoins,
    this.onNavigatePrev,
    this.onNavigateNext,
  });

  @override
  State<GameEngine> createState() => _GameEngineState();
}

class _GameEngineState extends State<GameEngine> with SingleTickerProviderStateMixin {
  String _currentAnswer = '';
  bool _showComplete = false;
  late AnimationController _animController;
  final _random = Random();

  List<String> _selectedOptions = [];
  List<String> _shuffledLetters = [];
  List<int> _usedLetterIndices = [];
  List<int> _answerGridIndices = [];
  String _typedAnswer = '';
  _Screen _screen = _Screen.packSelect;
  String? _selectedPackId;
  int _internalLevelIndex = 0;

  List<String> _pairingLeft = [];
  List<String?> _pairingRight = [];
  List<String> _pairingShuffledTargets = [];
  List<String> _pairingSlotCorrectLeft = [];
  int _lastPairingLevelIndex = -1;

  List<List<String>> _wsGrid = [];
  List<String> _wsWords = [];
  Set<String> _wsFoundWords = {};
  String? _wsSelectedWord;
  List<List<int>> _wsSelectedCells = [];
  List<List<List<int>>> _wsFoundCells = [];
  int _lastWsLevelIndex = -1;

  List<List<String>> _ws2Grid = [];
  List<String> _ws2Words = [];
  List<String> _ws2Clues = [];
  Set<String> _ws2FoundWords = {};
  List<String> _ws2FoundOrder = [];
  List<List<List<int>>> _ws2FoundCells = [];
  Map<String, Color> _ws2FoundColors = {};
  List<int>? _ws2DragStart;
  List<List<int>> _ws2DragCells = [];
  int _lastWs2LevelIndex = -1;

  int _jigsawRows = 3;
  int _jigsawCols = 3;
  List<int> _jigsawScattered = [];
  Set<int> _jigsawPlaced = {};
  int _lastJigsawLevelIndex = -1;

  final TextEditingController _fillController = TextEditingController();

  static const List<Color> _wsColors = [
    Color(0xFF4CAF50), Color(0xFFFF5722), Color(0xFF2196F3), Color(0xFF9C27B0),
    Color(0xFFFF9800), Color(0xFFE91E63), Color(0xFF00BCD4), Color(0xFF8BC34A),
  ];

  void _playSound() {
    try { HapticFeedback.selectionClick(); } catch (_) {}
  }

  Color? _getColor(String key) {
    final value = widget.config.design['colors']?[key];
    if (value is int) return Color(value);
    return Colors.white;
  }

  bool get _hasPacks => widget.config.hasPacks;

  List<GameLevel> get _currentPackLevels {
    if (_selectedPackId == null) return widget.config.levels;
    final pack = widget.config.packs.firstWhere((p) => p.id == _selectedPackId, orElse: () => widget.config.packs.isNotEmpty ? widget.config.packs.first : GameLevelPack(id: '', name: ''));
    final ids = pack.levelIds.toSet();
    return widget.config.levels.where((l) => ids.contains(l.id)).toList();
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _screen = _hasPacks ? _Screen.packSelect : _Screen.levelSelect;
    _initLevel();
  }

  @override
  void dispose() {
    _animController.dispose();
    _fillController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GameEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLevel != widget.currentLevel) {
      if (!_hasPacks) {
        _internalLevelIndex = widget.currentLevel;
      }
      _initLevel();
    }
  }

  void _initLevel() {
    _currentAnswer = '';
    _showComplete = false;
    _selectedOptions = [];
    _usedLetterIndices = [];
    _answerGridIndices = [];
    _typedAnswer = '';
    _fillController.clear();
    if (_screen == _Screen.playing && !_hasPacks) {
      _internalLevelIndex = widget.currentLevel;
    }
    final packLevels = _currentPackLevels;
    final idx = _internalLevelIndex;
    if (_screen == _Screen.playing && packLevels.isNotEmpty && idx < packLevels.length) {
      final level = packLevels[idx];
      final qType = level.questionType;
      if (qType == 'anagram' || qType == 'wordscramble') {
        _shuffledLetters = level.answer.toUpperCase().split('');
        _shuffledLetters.shuffle(_random);
      } else {
        _shuffledLetters = _generateLetters(level.answer.toUpperCase());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _getColor('background'),
      child: _showComplete
          ? _buildCompleteScreen()
          : _screen == _Screen.buyCoins && widget.iapEnabled
              ? _buildBuyCoinsScreen()
              : _screen == _Screen.packSelect
                  ? _buildPackSelectScreen()
                  : _screen == _Screen.levelSelect
                      ? _buildLevelSelectScreen()
                      : _buildGameScreen(),
    );
  }

  Widget _buildGameScreen() {
    if (widget.config.levels.isEmpty) return _emptyScreen();
    final packLevels = _currentPackLevels;
    if (packLevels.isEmpty) return _emptyScreen();
    final idx = _internalLevelIndex;
    if (idx >= packLevels.length) return _allDoneScreen();
    final level = packLevels[idx];
    final qType = level.questionType;

    switch (qType) {
      case 'mcq':
        return _buildMCQScreen(level);
      case 'truefalse':
        return _buildTrueFalseScreen(level);
      case 'typeanswer':
        return _buildTypeAnswerScreen(level);
      case 'fillblank':
        return _buildFillBlankScreen(level);
      case 'multiselect':
        return _buildMultiSelectScreen(level);
      case 'anagram':
        return _buildAnagramScreen(level);
      case 'hangman':
        return _buildHangmanScreen(level);
      case 'wordscramble':
        return _buildAnagramScreen(level);
      case 'ordering':
        return _buildOrderingScreen(level);
      case 'classification':
        return _buildClassificationScreen(level);
      case 'emojipairing':
        return _buildPairingScreen(level);
      case 'jigsaw':
        return _buildJigsawScreen(level);
      case 'wordsearch1':
        return _buildWS1Screen(level);
      case 'wordsearch2':
        return _buildWS2Screen(level);
      case 'crossword':
        return _buildCrosswordScreen(level);
      default:
        return _buildLetterTapScreen(level);
    }
  }

  int _getImageCount(String qType) {
    if (qType == '4emoji1word' || qType.startsWith('4pic')) return 4;
    if (qType == '3emoji1word' || qType.startsWith('3pic')) return 3;
    if (qType == '2emoji1word' || qType == '2emoji1wordplus' || qType.startsWith('2pic')) return 2;
    if (qType == '1emoji1word') return 1;
    return 1;
  }

  List<String> _getUrls(GameLevel level) {
    final all = <String>[];
    if (level.imageUrl.isNotEmpty) all.add(level.imageUrl);
    all.addAll(level.imageUrls.where((u) => u.isNotEmpty));
    return all;
  }

  Widget _buildEmojiTile(String emoji) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(emoji, style: const TextStyle(fontSize: 36))),
      ),
    );
  }

  Widget _buildImageArea(GameLevel level) {
    final qType = level.questionType;
    final isEmoji = qType.contains('emoji');
    final count = _getImageCount(qType);
    final emojis = level.emojis;

    if (isEmoji && emojis.isNotEmpty) {
      if (count == 1) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: 100,
          child: Center(child: Text(emojis[0], style: const TextStyle(fontSize: 72))),
        );
      }
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        height: count <= 2 ? 120.0 : (count == 3 ? 100.0 : 80.0),
        child: Row(
          children: [
            for (int i = 0; i < emojis.length && i < count; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _buildEmojiTile(emojis[i])),
            ],
          ],
        ),
      );
    }

    final urls = _getUrls(level);
    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }

    if (count == 1) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        height: 180,
        decoration: BoxDecoration(color: const Color(0xFF30363D), borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(urls[0], fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, size: 48, color: Colors.grey))),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: count <= 2 ? 140.0 : (count == 3 ? 110.0 : 90.0),
      child: Row(
        children: [
          for (int i = 0; i < urls.length && i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF30363D), borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(urls[i], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, size: 24, color: Colors.grey))),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== LETTER TAP (1pic1word, 2pic1word, etc.) ==========
  Widget _buildLetterTapScreen(GameLevel level) {
    final answer = level.answer.toUpperCase();
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          Expanded(child: _buildImageArea(level)),
          _buildAnswerSlots(answer),
          const SizedBox(height: 8),
          _buildLetterGrid(answer),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== MCQ ==========
  Widget _buildMCQScreen(GameLevel level) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: level.options.map((opt) {
                final selected = _selectedOptions.contains(opt);
                final isCorrect = opt.toUpperCase() == level.answer.toUpperCase();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onTap: () {
                      _playSound();
                      setState(() {
                        _selectedOptions = [opt];
                        if (isCorrect) {
                          _animController.forward(from: 0);
                          _showComplete = true;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Wrong! Try again'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                          );
                        }
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: selected ? _getColor('primary') : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? _getColor('primary')! : Colors.grey.shade700),
                      ),
                      child: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== TRUE / FALSE ==========
  Widget _buildTrueFalseScreen(GameLevel level) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _playSound();
                      final correct = level.answer.toUpperCase() == 'TRUE';
                      setState(() {
                        _selectedOptions = ['True'];
                        if (correct) {
                          _animController.forward(from: 0);
                          _showComplete = true;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Wrong!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                          );
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: _selectedOptions.contains('True') ? Colors.green : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Center(child: Text('TRUE', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _playSound();
                      final correct = level.answer.toUpperCase() == 'FALSE';
                      setState(() {
                        _selectedOptions = ['False'];
                        if (correct) {
                          _animController.forward(from: 0);
                          _showComplete = true;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Wrong!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                          );
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: _selectedOptions.contains('False') ? Colors.red : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Center(child: Text('FALSE', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== TYPE ANSWER ==========
  Widget _buildTypeAnswerScreen(GameLevel level) {
    final answer = level.answer.toUpperCase();
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _typedAnswer.isEmpty ? 'Type your answer...' : _typedAnswer,
                          style: TextStyle(color: _typedAnswer.isEmpty ? Colors.grey : Colors.white, fontSize: 18),
                        ),
                      ),
                      if (_typedAnswer.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _typedAnswer = _typedAnswer.substring(0, _typedAnswer.length - 1)),
                          child: const Icon(Icons.backspace, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
                  children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _typedAnswer += letter);
                        if (_typedAnswer.length == answer.length) {
                          if (_typedAnswer == answer) {
                            _animController.forward(from: 0);
                            setState(() => _showComplete = true);
                          } else {
                            setState(() => _typedAnswer = '');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Wrong answer!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: _getColor('primary'), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== MULTI SELECT ==========
  Widget _buildMultiSelectScreen(GameLevel level) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: level.options.map((opt) {
                final selected = _selectedOptions.contains(opt);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedOptions.remove(opt);
                        } else {
                          _selectedOptions.add(opt);
                        }
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: selected ? _getColor('primary') : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? _getColor('primary')! : Colors.grey.shade700),
                      ),
                      child: Row(
                        children: [
                          Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 16))),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedOptions.isEmpty ? null : () {
                  final correctAnswers = level.answer.split(',').map((s) => s.trim().toUpperCase()).toList();
                  final selectedUpper = _selectedOptions.map((s) => s.toUpperCase()).toList();
                  correctAnswers.sort();
                  selectedUpper.sort();
                  if (listEquals(correctAnswers, selectedUpper)) {
                    _animController.forward(from: 0);
                    setState(() => _showComplete = true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not quite right!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Check', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== ANAGRAM / WORD SCRAMBLE ==========
  Widget _buildAnagramScreen(GameLevel level) {
    final answer = level.answer.toUpperCase();
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          _buildAnswerSlots(answer),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: List.generate(_shuffledLetters.length, (i) {
                final used = _usedLetterIndices.contains(i);
                return GestureDetector(
                  onTap: used ? null : () {
                    _playSound();
                    setState(() {
                      _currentAnswer += _shuffledLetters[i];
                      _usedLetterIndices.add(i);
                    });
                    _checkAnswer(answer);
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: used ? Colors.grey.shade800 : _getColor('primary'),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(_shuffledLetters[i], style: TextStyle(color: used ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                  ),
                );
              }),
            ),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== HANGMAN ==========
  Widget _buildHangmanScreen(GameLevel level) {
    final answer = level.answer.toUpperCase();
    final wrongGuesses = _selectedOptions.where((o) => !answer.contains(o)).toList();
    final wrongCount = wrongGuesses.length;
    final won = answer.split('').every((c) => _selectedOptions.contains(c));
    final lost = wrongCount >= 6;
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          if (level.hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(level.hint, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size(120, 120),
              painter: _HangmanPainter(wrongCount: wrongCount),
            ),
          ),
          const SizedBox(height: 8),
          Text('Wrong guesses: $wrongCount/6', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: answer.split('').map((char) {
                final revealed = _selectedOptions.contains(char);
                return Container(
                  width: 32, height: 36, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: revealed ? _getColor('primary') : const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Center(child: Text(revealed ? char : '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 9, crossAxisSpacing: 4, mainAxisSpacing: 4,
                ),
                itemCount: 26,
                itemBuilder: (context, i) {
                  final letter = String.fromCharCode(65 + i);
                  final guessed = _selectedOptions.contains(letter);
                  final isCorrect = guessed && answer.contains(letter);
                  final isWrong = guessed && !answer.contains(letter);
                  return GestureDetector(
                    onTap: (guessed || won || lost) ? null : () {
                      _playSound();
                      setState(() => _selectedOptions.add(letter));
                      if (won || lost) return;
                      final allRevealed = answer.split('').every((c) => _selectedOptions.contains(c));
                      if (allRevealed) {
                        _playSound();
                        _animController.forward(from: 0);
                        setState(() => _showComplete = true);
                      } else if (_selectedOptions.where((o) => !answer.contains(o)).length >= 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Game Over! Try again.'), backgroundColor: Colors.red),
                        );
                        setState(() => _initLevel());
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: guessed
                            ? (isWrong ? const Color(0xFFE53935).withOpacity(0.5) : isCorrect ? _getColor('primary')!.withOpacity(0.5) : _getColor('primary'))
                            : _getColor('primary'),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          guessed ? '' : letter,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ========== ORDERING ==========
  Widget _buildOrderingScreen(GameLevel level) {
    if (_selectedOptions.isEmpty && level.options.isNotEmpty) {
      _selectedOptions = List<String>.from(level.options)..shuffle(_random);
    }
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _selectedOptions.removeAt(oldIndex);
                  _selectedOptions.insert(newIndex, item);
                });
              },
              children: _selectedOptions.asMap().entries.map((entry) {
                return Container(
                  key: ValueKey(entry.value),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Row(
                    children: [
                      Text('${entry.key + 1}.', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(entry.value, style: const TextStyle(color: Colors.white, fontSize: 16))),
                      const Icon(Icons.drag_handle, color: Colors.grey),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final correct = level.answer.split('|').map((s) => s.trim()).toList();
                  if (listEquals(_selectedOptions, correct)) {
                    _animController.forward(from: 0);
                    setState(() => _showComplete = true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not in the right order!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Check Order', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== CLASSIFICATION ==========
  Widget _buildClassificationScreen(GameLevel level) {
    final categories = level.answer.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final itemToCategory = <String, String>{};
    final items = <String>[];
    final available = <String>[];
    for (final raw in level.emojis) {
      final parts = raw.split('|');
      if (parts.length == 2) {
        final cat = parts[0].trim();
        final val = parts[1].trim();
        itemToCategory[val] = cat;
        items.add(val);
        available.add(val);
      }
    }
    final slots = <String, List<String>>{};
    for (final cat in categories) {
      slots[cat] = [];
    }
    if (_selectedOptions.isEmpty && available.isNotEmpty) {
      available.shuffle(_random);
    }
    final allPlaced = available.isEmpty;
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                    children: categories.map((cat) {
                      final catItems = slots[cat] ?? [];
                      return Container(
                        width: 150, constraints: const BoxConstraints(minHeight: 60),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _getColor('primary')!.withOpacity(0.5), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat, style: TextStyle(color: _getColor('primary'), fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4, runSpacing: 4,
                              children: catItems.map((item) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(item, style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (available.isNotEmpty)
                    Wrap(
                      spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
                      children: available.map((item) {
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF21262D),
                                title: Text('Place "$item"', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: categories.map((cat) {
                                    return ListTile(
                                      title: Text(cat, style: const TextStyle(color: Colors.white)),
                                      onTap: () {
                                        Navigator.of(ctx).pop();
                                        setState(() {
                                          available.remove(item);
                                          slots[cat]?.add(item);
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getColor('primary')!.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _getColor('primary')!),
                            ),
                            child: Text(item, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: allPlaced
                    ? () {
                        bool allCorrect = true;
                        for (final cat in categories) {
                          final catItems = slots[cat] ?? [];
                          for (final item in catItems) {
                            if (itemToCategory[item] != cat) {
                              allCorrect = false;
                              break;
                            }
                          }
                          if (!allCorrect) break;
                        }
                        if (allCorrect) {
                          _animController.forward(from: 0);
                          setState(() => _showComplete = true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Some items are misplaced! Try again.'), backgroundColor: Colors.red),
                          );
                          setState(() => _initLevel());
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Check', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== EMOJI PAIRING ==========
  void _initPairing(GameLevel level) {
    final left = List<String>.from(level.emojis.where((e) => e.isNotEmpty));
    final rightRaw = List<String>.from(level.options.where((e) => e.isNotEmpty));
    final right = rightRaw.isEmpty ? left.reversed.toList() : rightRaw;
    final count = left.length < right.length ? left.length : right.length;
    final indices = List<int>.generate(count, (i) => i)..shuffle(_random);
    _pairingLeft = List<String>.from(left.take(count));
    _pairingRight = List<String?>.filled(count, null);
    _pairingShuffledTargets = indices.map((i) => right[i]).toList();
    _pairingSlotCorrectLeft = indices.map((i) => left[i]).toList();
    _lastPairingLevelIndex = _internalLevelIndex;
  }

  Widget _buildPairingScreen(GameLevel level) {
    if (_lastPairingLevelIndex != _internalLevelIndex) {
      _initPairing(level);
    }
    final allMatched = _pairingRight.every((r) => r != null);
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _pairingLeft.map((emoji) {
                          final used = _pairingRight.contains(emoji);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Draggable<String>(
                              data: emoji,
                              maxSimultaneousDrags: used ? 0 : 1,
                              feedback: Material(
                                color: Colors.transparent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: _getColor('primary')!.withOpacity(0.5), blurRadius: 12, spreadRadius: 2)],
                                  ),
                                  child: Text(emoji, style: const TextStyle(fontSize: 44)),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.2,
                                child: _buildPairingCell(emoji),
                              ),
                              child: _buildPairingCell(emoji),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, color: Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Drop here', style: TextStyle(color: Colors.grey, fontSize: 10)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(_pairingRight.length, (i) => _buildPairingDropSlot(i)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: allMatched
                    ? () {
                        bool allCorrect = true;
                        for (int i = 0; i < _pairingSlotCorrectLeft.length; i++) {
                          if (i >= _pairingRight.length || _pairingRight[i] != _pairingSlotCorrectLeft[i]) {
                            allCorrect = false;
                            break;
                          }
                        }
                        if (allCorrect) {
                          _animController.forward(from: 0);
                          setState(() => _showComplete = true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Some pairs are wrong! Try again.'), backgroundColor: Colors.red),
                          );
                          setState(() => _initPairing(level));
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Check', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingCell(String emoji) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
    );
  }

  Widget _buildPairingDropSlot(int i) {
    final matched = _pairingRight[i] != null;
    final isCorrect = matched && _pairingRight[i] == _pairingSlotCorrectLeft[i];
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != _pairingRight[i],
      onAcceptWithDetails: (d) {
        setState(() {
          _pairingRight[i] = d.data;
        });
        _playSound();
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isHovering
                ? _getColor('primary')!.withOpacity(0.3)
                : isCorrect
                    ? const Color(0xFF0D2818)
                    : matched
                        ? const Color(0xFF1A2332)
                        : const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering
                  ? _getColor('primary')!
                  : isCorrect
                      ? Colors.greenAccent
                      : matched
                          ? _getColor('primary')!.withOpacity(0.4)
                          : Colors.grey.shade700,
              width: isHovering ? 2.5 : 1,
            ),
          ),
          child: Center(
            child: matched
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_pairingRight[i]!, style: const TextStyle(fontSize: 30)),
                      if (isCorrect) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                      ],
                    ],
                  )
                : Text(i < _pairingShuffledTargets.length ? _pairingShuffledTargets[i] : '?',
                    style: TextStyle(fontSize: 28, color: Colors.grey.shade500)),
          ),
        );
      },
    );
  }

  // ========== WORD SEARCH 1 (tap) ==========
  void _initWS1(GameLevel level) {
    _wsWords = level.emojis.map((e) => e.trim().toUpperCase()).where((w) => w.isNotEmpty).toList();
    _wsFoundWords = {};
    _wsSelectedWord = null;
    _wsSelectedCells = [];
    _wsFoundCells = [];
    _lastWsLevelIndex = _internalLevelIndex;
    _generateWSGrid();
  }

  void _generateWSGrid() {
    final maxLen = _wsWords.fold<int>(0, (m, w) => w.length > m ? w.length : m);
    final size = (maxLen + 4).clamp(8, 12);
    _wsGrid = List.generate(size, (_) => List.generate(size, (_) => ''));
    const directions = [
      [0, 1], [1, 0], [1, 1], [0, -1], [-1, 0], [-1, -1], [1, -1], [-1, 1],
    ];
    final random = Random();
    for (final word in _wsWords) {
      var placed = false;
      for (var attempt = 0; attempt < 100 && !placed; attempt++) {
        final dir = directions[random.nextInt(directions.length)];
        final row = random.nextInt(size);
        final col = random.nextInt(size);
        if (row + dir[0] * (word.length - 1) < 0 || row + dir[0] * (word.length - 1) >= size) continue;
        if (col + dir[1] * (word.length - 1) < 0 || col + dir[1] * (word.length - 1) >= size) continue;
        var fits = true;
        for (var k = 0; k < word.length; k++) {
          final r = row + dir[0] * k;
          final c = col + dir[1] * k;
          if (_wsGrid[r][c] != '' && _wsGrid[r][c] != word[k]) { fits = false; break; }
        }
        if (fits) {
          for (var k = 0; k < word.length; k++) {
            _wsGrid[row + dir[0] * k][col + dir[1] * k] = word[k];
          }
          placed = true;
        }
      }
    }
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (_wsGrid[r][c] == '') _wsGrid[r][c] = letters[random.nextInt(letters.length)];
      }
    }
  }

  void _onWs1CellTap(int r, int c) {
    if (_wsSelectedWord == null) return;
    _playSound();
    setState(() {
      final existing = _wsSelectedCells.indexWhere((cell) => cell[0] == r && cell[1] == c);
      if (existing >= 0) {
        _wsSelectedCells.removeRange(existing, _wsSelectedCells.length);
      } else {
        if (_wsSelectedCells.isEmpty) {
          _wsSelectedCells.add([r, c]);
        } else {
          final last = _wsSelectedCells.last;
          final dr = r - last[0];
          final dc = c - last[1];
          if (_wsSelectedCells.length == 1) {
            if (dr == 0 && dc == 0) return;
          } else {
            final prev = _wsSelectedCells[_wsSelectedCells.length - 2];
            final pdr = last[0] - prev[0];
            final pdc = last[1] - prev[1];
            if (dr != pdr || dc != pdc) { _wsSelectedCells.clear(); _wsSelectedCells.add([r, c]); return; }
          }
          _wsSelectedCells.add([r, c]);
        }
      }
      if (_wsSelectedCells.length == _wsSelectedWord!.length) {
        final selected = _wsSelectedCells.map((cell) => _wsGrid[cell[0]][cell[1]]).join();
        if (selected == _wsSelectedWord) {
          _wsFoundWords.add(_wsSelectedWord!);
          _wsFoundCells.add(List.from(_wsSelectedCells));
          _wsSelectedWord = null;
          _wsSelectedCells = [];
        } else {
          _wsSelectedCells.clear();
        }
      }
    });
  }

  Widget _buildWS1Screen(GameLevel level) {
    if (_wsGrid.isEmpty || _lastWsLevelIndex != _internalLevelIndex) {
      _initWS1(level);
    }
    if (_wsWords.isEmpty) {
      return SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildQuestion(level),
            const Expanded(child: Center(child: Text('No words available for this puzzle', style: TextStyle(color: Colors.grey)))),
          ],
        ),
      );
    }
    final allFound = _wsFoundWords.length == _wsWords.length;
    final gridSize = _wsGrid.length;
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 4),
          Text('Words found: ${_wsFoundWords.length} / ${_wsWords.length}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _wsWords.isEmpty ? 0 : _wsFoundWords.length / _wsWords.length,
            backgroundColor: const Color(0xFF21262D),
            valueColor: AlwaysStoppedAnimation(_getColor('primary')),
            minHeight: 3,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize, crossAxisSpacing: 2, mainAxisSpacing: 2,
                ),
                itemCount: gridSize * gridSize,
                itemBuilder: (context, index) {
                  final r = index ~/ gridSize;
                  final c = index % gridSize;
                  final isFound = _wsFoundCells.any((cells) => cells.any((cell) => cell[0] == r && cell[1] == c));
                  final isSelected = _wsSelectedCells.any((cell) => cell[0] == r && cell[1] == c);
                  return GestureDetector(
                    onTap: () => _onWs1CellTap(r, c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isFound
                            ? Colors.greenAccent.withOpacity(0.3)
                            : isSelected
                                ? _getColor('primary')!.withOpacity(0.5)
                                : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isFound
                              ? Colors.greenAccent
                              : isSelected
                                  ? _getColor('primary')!
                                  : const Color(0xFF30363D),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(_wsGrid[r][c], style: TextStyle(
                          fontSize: gridSize > 10 ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: isFound ? Colors.greenAccent : Colors.white,
                        )),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
              children: _wsWords.map((w) {
                final found = _wsFoundWords.contains(w);
                return GestureDetector(
                  onTap: found ? null : () => setState(() { _wsSelectedWord = w; _wsSelectedCells = []; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: found
                          ? Colors.greenAccent.withOpacity(0.2)
                          : _wsSelectedWord == w
                              ? _getColor('primary')!.withOpacity(0.3)
                              : const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: found ? Colors.greenAccent : _wsSelectedWord == w ? _getColor('primary')! : const Color(0xFF30363D),
                      ),
                    ),
                    child: Text(w, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: found ? Colors.greenAccent : _wsSelectedWord == w ? Colors.white : Colors.grey,
                      decoration: found ? TextDecoration.lineThrough : null,
                    )),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: allFound
                    ? () {
                        _animController.forward(from: 0);
                        setState(() => _showComplete = true);
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(allFound ? 'Complete!' : 'Find all ${_wsWords.length} words', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== WORD SEARCH 2 / CROSSWORD (drag) ==========
  void _initWS2(GameLevel level, {bool crossword = false}) {
    _ws2Words = level.emojis.map((e) => e.trim().toUpperCase()).where((w) => w.isNotEmpty).toList();
    _ws2Clues = List<String>.from(level.options);
    _ws2FoundWords = {};
    _ws2FoundOrder = [];
    _ws2FoundCells = [];
    _ws2FoundColors = {};
    _ws2DragStart = null;
    _ws2DragCells = [];
    _lastWs2LevelIndex = _internalLevelIndex;
    if (_ws2Words.isEmpty) return;
    final maxLen = _ws2Words.fold<int>(0, (m, w) => w.length > m ? w.length : m);
    final size = (maxLen + 4).clamp(8, 12);
    _ws2Grid = List.generate(size, (_) => List.generate(size, (_) => ''));
    const directions = [
      [0, 1], [1, 0], [1, 1], [0, -1], [-1, 0], [-1, -1], [1, -1], [-1, 1],
    ];
    final random = Random();
    for (final word in _ws2Words) {
      var placed = false;
      for (var attempt = 0; attempt < 100 && !placed; attempt++) {
        final dir = directions[random.nextInt(directions.length)];
        final row = random.nextInt(size);
        final col = random.nextInt(size);
        if (row + dir[0] * (word.length - 1) < 0 || row + dir[0] * (word.length - 1) >= size) continue;
        if (col + dir[1] * (word.length - 1) < 0 || col + dir[1] * (word.length - 1) >= size) continue;
        var fits = true;
        for (var k = 0; k < word.length; k++) {
          final r = row + dir[0] * k;
          final c = col + dir[1] * k;
          if (_ws2Grid[r][c] != '' && _ws2Grid[r][c] != word[k]) { fits = false; break; }
        }
        if (fits) {
          for (var k = 0; k < word.length; k++) {
            _ws2Grid[row + dir[0] * k][col + dir[1] * k] = word[k];
          }
          placed = true;
        }
      }
    }
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (_ws2Grid[r][c] == '') _ws2Grid[r][c] = letters[random.nextInt(letters.length)];
      }
    }
  }

  List<int>? _ws2HitCell(Offset pos, BoxConstraints constraints, int gridSize) {
    const spacing = 2.0;
    final totalSpacing = spacing * (gridSize - 1);
    final cellW = (constraints.maxWidth - totalSpacing) / gridSize;
    final cellH = (constraints.maxHeight - totalSpacing) / gridSize;
    final c = (pos.dx / (cellW + spacing)).floor();
    final r = (pos.dy / (cellH + spacing)).floor();
    if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) return [r, c];
    return null;
  }

  void _onWs2DragStart(DragStartDetails details, BoxConstraints constraints, int gridSize) {
    final cell = _ws2HitCell(details.localPosition, constraints, gridSize);
    if (cell == null) return;
    setState(() { _ws2DragStart = cell; _ws2DragCells = [cell]; });
  }

  void _onWs2DragUpdate(DragUpdateDetails details, BoxConstraints constraints, int gridSize) {
    if (_ws2DragStart == null) return;
    final cell = _ws2HitCell(details.localPosition, constraints, gridSize);
    if (cell == null) return;
    final sr = _ws2DragStart![0], sc = _ws2DragStart![1];
    final dr = cell[0] - sr, dc = cell[1] - sc;
    if (dr == 0 && dc == 0) return;
    int stepR = 0, stepC = 0;
    if (dr == 0) { stepC = dc > 0 ? 1 : -1; }
    else if (dc == 0) { stepR = dr > 0 ? 1 : -1; }
    else if (dr.abs() == dc.abs()) { stepR = dr > 0 ? 1 : -1; stepC = dc > 0 ? 1 : -1; }
    else {
      if (dr.abs() >= dc.abs()) { stepR = dr > 0 ? 1 : -1; stepC = 0; }
      else { stepC = dc > 0 ? 1 : -1; stepR = 0; }
    }
    final dist = stepR != 0 ? dr.abs() ~/ stepR.abs() : dc.abs() ~/ stepC.abs();
    final cells = <List<int>>[];
    for (var i = 0; i <= dist && i < gridSize; i++) {
      final nr = sr + stepR * i, nc = sc + stepC * i;
      if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) cells.add([nr, nc]);
    }
    setState(() { _ws2DragCells = cells; });
  }

  void _onWs2DragEnd(BoxConstraints constraints, int gridSize) {
    if (_ws2DragCells.length < 2) {
      setState(() { _ws2DragStart = null; _ws2DragCells = []; });
      return;
    }
    final selected = _ws2DragCells.map((c) => _ws2Grid[c[0]][c[1]]).join();
    final reversed = selected.split('').reversed.join();
    String? foundWord;
    for (final w in _ws2Words) {
      if (_ws2FoundWords.contains(w)) continue;
      if (selected == w || reversed == w) { foundWord = w; break; }
    }
    setState(() {
      if (foundWord != null) {
        _ws2FoundWords.add(foundWord);
        _ws2FoundOrder.add(foundWord);
        _ws2FoundCells.add(List.from(_ws2DragCells));
        _ws2FoundColors[foundWord] = _wsColors[(_ws2FoundOrder.length - 1).clamp(0, _wsColors.length - 1)];
        if (_ws2FoundWords.length == _ws2Words.length) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) {
              _animController.forward(from: 0);
              setState(() => _showComplete = true);
            }
          });
        }
      }
      _ws2DragStart = null;
      _ws2DragCells = [];
    });
  }

  Widget _buildWSGridBody({required Color dragColor, required bool showClues}) {
    final gridSize = _ws2Grid.length;
    if (gridSize == 0 || _ws2Words.isEmpty) {
      return const Center(child: Text('No words available for this puzzle', style: TextStyle(color: Colors.grey)));
    }
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                return GestureDetector(
                  onPanStart: (d) => _onWs2DragStart(d, constraints, gridSize),
                  onPanUpdate: (d) => _onWs2DragUpdate(d, constraints, gridSize),
                  onPanEnd: (_) => _onWs2DragEnd(constraints, gridSize),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridSize, crossAxisSpacing: 2, mainAxisSpacing: 2,
                    ),
                    itemCount: gridSize * gridSize,
                    itemBuilder: (context, index) {
                      final r = index ~/ gridSize;
                      final c = index % gridSize;
                      String? foundColorKey;
                      bool isFound = false;
                      for (var fi = 0; fi < _ws2FoundCells.length; fi++) {
                        if (_ws2FoundCells[fi].any((cell) => cell[0] == r && cell[1] == c)) {
                          isFound = true;
                          foundColorKey = fi < _ws2FoundOrder.length ? _ws2FoundOrder[fi] : null;
                          break;
                        }
                      }
                      final foundColor = foundColorKey != null
                          ? (_ws2FoundColors[foundColorKey] ?? Colors.greenAccent)
                          : Colors.greenAccent;
                      final isDrag = _ws2DragCells.any((cell) => cell[0] == r && cell[1] == c);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          color: isFound
                              ? foundColor.withOpacity(0.35)
                              : isDrag
                                  ? dragColor.withOpacity(0.35)
                                  : const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isFound ? foundColor : isDrag ? dragColor : const Color(0xFF30363D),
                            width: isDrag ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(_ws2Grid[r][c], style: TextStyle(
                            fontSize: gridSize > 10 ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: isFound ? Colors.white : Colors.white70,
                          )),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(12),
          ),
          child: showClues
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_ws2Words.length, (i) {
                    final w = _ws2Words[i];
                    final found = _ws2FoundWords.contains(w);
                    final color = _ws2FoundColors[w] ?? Colors.greenAccent;
                    final clue = i < _ws2Clues.length ? _ws2Clues[i] : w;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text('${i + 1}. ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: found ? color : Colors.white70)),
                          Expanded(
                            child: Text(clue, style: TextStyle(
                              fontSize: 12,
                              color: found ? color : Colors.white70,
                              decoration: found ? TextDecoration.lineThrough : null,
                              decorationColor: color,
                            )),
                          ),
                        ],
                      ),
                    );
                  }),
                )
              : Wrap(
                  spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
                  children: _ws2Words.map((w) {
                    final found = _ws2FoundWords.contains(w);
                    final color = _ws2FoundColors[w] ?? Colors.greenAccent;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: found ? color.withOpacity(0.25) : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: found ? color : const Color(0xFF30363D), width: found ? 2 : 1),
                      ),
                      child: Text(w, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: found ? color : Colors.white70,
                        decoration: found ? TextDecoration.lineThrough : null,
                        decorationColor: color,
                      )),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildWS2Screen(GameLevel level) {
    if (_ws2Grid.isEmpty || _lastWs2LevelIndex != _internalLevelIndex) {
      _initWS2(level);
    }
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 4),
          Text('Words found: ${_ws2FoundWords.length} / ${_ws2Words.length}',
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 8),
          Expanded(child: _buildWSGridBody(dragColor: _getColor('primary')!, showClues: false)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCrosswordScreen(GameLevel level) {
    if (_ws2Grid.isEmpty || _lastWs2LevelIndex != _internalLevelIndex) {
      _initWS2(level, crossword: true);
    }
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 4),
          Text('Words found: ${_ws2FoundWords.length} / ${_ws2Words.length}',
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 8),
          Expanded(child: _buildWSGridBody(dragColor: Colors.white, showClues: true)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ========== JIGSAW ==========
  void _initJigsaw(GameLevel level) {
    final answer = level.answer.isEmpty ? '3x3' : level.answer;
    final parts = answer.split('x');
    _jigsawRows = int.tryParse(parts[0]) ?? 3;
    _jigsawCols = parts.length > 1 ? (int.tryParse(parts[1]) ?? 3) : 3;
    final total = _jigsawRows * _jigsawCols;
    _jigsawScattered = List<int>.generate(total, (i) => i)..shuffle(_random);
    _jigsawPlaced = {};
    _lastJigsawLevelIndex = _internalLevelIndex;
  }

  Widget _buildJigsawSlice(String url, int pieceIdx, double pieceW, double pieceH) {
    final r = pieceIdx ~/ _jigsawCols;
    final c = pieceIdx % _jigsawCols;
    return ClipRect(
      child: SizedBox(
        width: pieceW,
        height: pieceH,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _jigsawCols * pieceW,
          maxWidth: _jigsawCols * pieceW,
          minHeight: _jigsawRows * pieceH,
          maxHeight: _jigsawRows * pieceH,
          child: Transform.translate(
            offset: Offset(-c * pieceW, -r * pieceH),
            child: SizedBox(
              width: _jigsawCols * pieceW,
              height: _jigsawRows * pieceH,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: _getColor('primary')!.withOpacity(0.6)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJigsawScreen(GameLevel level) {
    if (_lastJigsawLevelIndex != _internalLevelIndex || _jigsawScattered.isEmpty) {
      _initJigsaw(level);
    }
    final url = level.imageUrl;
    final total = _jigsawRows * _jigsawCols;
    final placed = _jigsawPlaced.length;
    final allPlaced = placed >= total;

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.extension, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text('Pieces: $placed / $total', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? placed / total : 0,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(_getColor('primary')),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final cellW = constraints.maxWidth / _jigsawCols;
                        final cellH = constraints.maxHeight / _jigsawRows;
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF30363D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              if (url.isNotEmpty)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.25,
                                    child: Image.network(url, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                                  ),
                                ),
                              ...List.generate(total, (cellIdx) {
                                final r = cellIdx ~/ _jigsawCols;
                                final c = cellIdx % _jigsawCols;
                                final isPlaced = _jigsawPlaced.contains(cellIdx);
                                return Positioned(
                                  left: c * cellW,
                                  top: r * cellH,
                                  width: cellW,
                                  height: cellH,
                                  child: isPlaced
                                      ? url.isNotEmpty
                                          ? _buildJigsawSlice(url, cellIdx, cellW, cellH)
                                          : Container(color: _getColor('primary')!.withOpacity(0.6))
                                      : DragTarget<int>(
                                          onWillAcceptWithDetails: (d) => d.data == cellIdx && !_jigsawPlaced.contains(cellIdx),
                                          onAcceptWithDetails: (d) {
                                            setState(() {
                                              _jigsawPlaced.add(cellIdx);
                                              _jigsawScattered.remove(cellIdx);
                                            });
                                            _playSound();
                                            if (_jigsawPlaced.length == total) {
                                              Future.delayed(const Duration(milliseconds: 400), () {
                                                if (mounted) {
                                                  _animController.forward(from: 0);
                                                  setState(() => _showComplete = true);
                                                }
                                              });
                                            }
                                          },
                                          builder: (ctx, candidateData, rejectedData) {
                                            final isHovering = candidateData.isNotEmpty;
                                            final isWrong = rejectedData.isNotEmpty;
                                            return AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              decoration: BoxDecoration(
                                                color: isHovering ? _getColor('primary')!.withOpacity(0.2) : Colors.black.withOpacity(0.45),
                                                border: Border.all(
                                                  color: isHovering
                                                      ? _getColor('primary')!
                                                      : isWrong
                                                          ? Colors.red.withOpacity(0.5)
                                                          : Colors.white24,
                                                  width: isHovering ? 2 : 1,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    child: _jigsawScattered.isEmpty
                        ? const Center(child: Text('All pieces placed!', style: TextStyle(color: Colors.white54, fontSize: 16)))
                        : GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _jigsawCols.clamp(2, 5),
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio: 1,
                            ),
                            itemCount: _jigsawScattered.length,
                            itemBuilder: (ctx, i) {
                              final pieceIdx = _jigsawScattered[i];
                              return LayoutBuilder(
                                builder: (ctx, constraints) {
                                  final pw = constraints.maxWidth;
                                  return Draggable<int>(
                                    data: pieceIdx,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: SizedBox(
                                        width: 90,
                                        height: 90,
                                        child: url.isNotEmpty
                                            ? _buildJigsawSlice(url, pieceIdx, 90 / _jigsawCols, 90 / _jigsawRows)
                                            : Container(color: _getColor('primary')),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.3,
                                      child: url.isNotEmpty
                                          ? _buildJigsawSlice(url, pieceIdx, pw / _jigsawCols, pw / _jigsawRows)
                                          : Container(color: _getColor('primary')),
                                    ),
                                    child: url.isNotEmpty
                                        ? _buildJigsawSlice(url, pieceIdx, pw / _jigsawCols, pw / _jigsawRows)
                                        : Container(color: _getColor('primary')!.withOpacity(0.7)),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (allPlaced) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () {
                  _animController.forward(from: 0);
                  setState(() => _showComplete = true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Finish', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== FILL IN THE BLANK ==========
  void _submitFillBlank(GameLevel level) {
    final answer = level.answer.toUpperCase().trim();
    final input = _fillController.text.trim().toUpperCase();
    if (input == answer) {
      _animController.forward(from: 0);
      setState(() => _showComplete = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong answer! Try again.'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildFillBlankScreen(GameLevel level) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              level.question.replaceAll('___', '______'),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _fillController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Fill in the blank...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: const Color(0xFF21262D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF30363D))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _getColor('primary')!)),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitFillBlank(level),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submitFillBlank(level),
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Submit', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ========== PACK SELECT ==========
  Widget _buildPackSelectScreen() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('Level Packs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.9),
              itemCount: widget.config.packs.length,
              itemBuilder: (context, index) {
                final pack = widget.config.packs[index];
                final locked = pack.locked;
                final name = pack.name.isNotEmpty ? pack.name : 'Pack ${index + 1}';
                final iconUrl = pack.iconUrl;
                final levelCount = pack.levelIds.length;
                return GestureDetector(
                  onTap: locked
                      ? () {
                          if (!widget.iapEnabled) {
                            setState(() {
                              pack.locked = false;
                              _selectedPackId = pack.id;
                              _screen = _Screen.levelSelect;
                            });
                          } else if (widget.coins >= 500) {
                            widget.onSpendCoins(500);
                            setState(() {
                              pack.locked = false;
                              _selectedPackId = pack.id;
                              _screen = _Screen.levelSelect;
                            });
                          } else {
                            setState(() { _screen = _Screen.buyCoins; });
                          }
                        }
                      : () => setState(() { _selectedPackId = pack.id; _screen = _Screen.levelSelect; }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: locked ? const Color(0xFF21262D) : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: locked ? Colors.grey.shade800 : (_getColor('primary') ?? Colors.white).withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        iconUrl.isNotEmpty
                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(iconUrl, width: 56, height: 56, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(locked ? Icons.lock : Icons.inventory_2, size: 32, color: Colors.grey)))
                            : Icon(locked ? Icons.lock : Icons.inventory_2, size: 32, color: locked ? Colors.grey : _getColor('primary')),
                        const SizedBox(height: 8),
                        Text(locked ? (widget.iapEnabled ? '🔒 500 coins' : 'Tap to unlock') : name, style: TextStyle(color: locked ? Colors.grey : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        if (!locked) Text('$levelCount levels', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========== LEVEL SELECT ==========
  Widget _buildLevelSelectScreen() {
    final packLevels = _currentPackLevels;
    final pack = _selectedPackId != null ? widget.config.packs.firstWhere((p) => p.id == _selectedPackId, orElse: () => GameLevelPack(id: '', name: '')) : GameLevelPack(id: '', name: 'All Levels');
    final title = _hasPacks ? (pack.name.isNotEmpty ? pack.name : 'Levels') : 'All Levels';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _hasPacks ? () => setState(() { _screen = _Screen.packSelect; _selectedPackId = null; }) : null,
                child: Icon(Icons.arrow_back, color: _hasPacks ? Colors.white : Colors.grey, size: 24),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: packLevels.length,
              itemBuilder: (context, index) {
                final level = packLevels[index];
                final url = level.imageUrl;
                final emojis = level.emojis;
                final locked = level.locked;
                return GestureDetector(
                  onTap: locked ? null : () => setState(() {
                    _internalLevelIndex = index;
                    _screen = _Screen.playing;
                    _initLevel();
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: locked ? const Color(0xFF1C1F24) : const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        if (emojis.isNotEmpty)
                          Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(emojis.first, style: TextStyle(fontSize: 32, color: locked ? Colors.grey : null)))),
                        if (emojis.isEmpty && url.isNotEmpty)
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                            errorBuilder: (_, __, ___) => Center(child: Text('${index + 1}', style: TextStyle(color: locked ? Colors.grey : Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))),
                        if (emojis.isEmpty && url.isEmpty)
                          Center(child: Text('${index + 1}', style: TextStyle(color: locked ? Colors.grey : Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                        if (locked)
                          Container(
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                            child: const Center(child: Icon(Icons.lock, color: Colors.white70, size: 20)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========== SHARED WIDGETS ==========
  Widget _emptyScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.games, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No levels available', style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _allDoneScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
          const SizedBox(height: 16),
          const Text('All levels complete!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Coins: ${widget.coins}', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final packLevels = _currentPackLevels;
    final idx = _internalLevelIndex;
    final hasPrev = _hasPacks ? idx > 0 : widget.onNavigatePrev != null;
    final hasNext = _hasPacks ? idx < packLevels.length - 1 : widget.onNavigateNext != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: hasPrev ? () {
              setState(() {
                if (_hasPacks) { _internalLevelIndex--; _initLevel(); }
                else widget.onNavigatePrev?.call();
              });
            } : null,
            child: Icon(Icons.chevron_left, color: hasPrev ? Colors.white : Colors.grey, size: 28),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _getColor('primary'), borderRadius: BorderRadius.circular(6)),
            child: Text('Level: ${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (widget.iapEnabled) ...[
            GestureDetector(
              onTap: () => setState(() { _screen = _Screen.buyCoins; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _getColor('secondary'), borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  const Icon(Icons.monetization_on, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text('${widget.coins}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
          GestureDetector(
            onTap: hasNext ? () {
              setState(() {
                if (_hasPacks) { _internalLevelIndex++; _initLevel(); }
                else widget.onNavigateNext?.call();
              });
            } : null,
            child: Icon(Icons.chevron_right, color: hasNext ? Colors.white : Colors.grey, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(GameLevel level) {
    if (level.question.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(level.question, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    );
  }

  Widget _buildAnswerSlots(String answer) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(answer.length, (i) {
          final char = i < _currentAnswer.length ? _currentAnswer[i] : '';
          return GestureDetector(
            onTap: char.isNotEmpty ? () {
              _playSound();
              setState(() {
                _currentAnswer = _currentAnswer.substring(0, i);
                if (i < _answerGridIndices.length) {
                  final gridIdx = _answerGridIndices[i];
                  _usedLetterIndices.remove(gridIdx);
                  _answerGridIndices.removeRange(i, _answerGridIndices.length);
                }
              });
            } : null,
            child: Container(
              width: 34, height: 34, margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: char.isNotEmpty ? _getColor('primary') : const Color(0xFF30363D),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text(char, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLetterGrid(String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
        children: _shuffledLetters.asMap().entries.map((entry) {
          final used = _usedLetterIndices.contains(entry.key);
          return GestureDetector(
            onTap: used ? null : () {
              _playSound();
              setState(() {
                _currentAnswer += entry.value;
                _usedLetterIndices.add(entry.key);
                _answerGridIndices.add(entry.key);
              });
              _checkAnswer(answer);
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: used ? Colors.grey.shade800 : _getColor('primary'),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(entry.value, style: TextStyle(color: used ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(GameLevel level) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.people, size: 18), label: const Text('Ask Friends'),
            style: ElevatedButton.styleFrom(backgroundColor: _getColor('secondary')),
          ),
          ElevatedButton.icon(
            onPressed: widget.iapEnabled ? (widget.coins >= 5 ? () { widget.onHintUsed(); _useHint(); } : null) : () { widget.onHintUsed(); _useHint(); },
            icon: const Icon(Icons.lightbulb, size: 18), label: Text(widget.iapEnabled ? 'Hints (5)' : 'Hints'),
            style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary')),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteScreen() {
    final packLevels = _currentPackLevels;
    final idx = _internalLevelIndex;
    final level = idx < packLevels.length ? packLevels[idx] : packLevels.last;
    final isLast = idx >= packLevels.length - 1;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.elasticOut)),
            child: const Icon(Icons.check_circle, size: 100, color: Colors.green),
          ),
          const SizedBox(height: 24),
          const Text('Well Done!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (widget.iapEnabled)
            Text('+${level.coinsReward} coins', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 20)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              widget.onLevelComplete(level.coinsReward);
              setState(() {
                _showComplete = false;
                if (_hasPacks) {
                  if (isLast) {
                    _screen = _Screen.levelSelect;
                    _selectedPackId = null;
                    _internalLevelIndex = 0;
                  } else {
                    _internalLevelIndex++;
                    _initLevel();
                  }
                } else {
                  _screen = _Screen.levelSelect;
                }
              });
            },
            child: Text(isLast ? 'Back to Levels' : 'Next Level'),
          ),
        ],
      ),
    );
  }

  // ========== BUY COINS ==========
  Widget _buildBuyCoinsScreen() {
    final packs = [
      {'id': 'coins1', 'name': '1000 Coins', 'coins': 1000, 'price': '\$0.99'},
      {'id': 'coins2', 'name': '2500 Coins', 'coins': 2500, 'price': '\$2.99'},
      {'id': 'coins3', 'name': '5000 Coins', 'coins': 5000, 'price': '\$4.99'},
      {'id': 'coins4', 'name': '10000 Coins', 'coins': 10000, 'price': '\$9.99'},
    ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  if (_hasPacks && _selectedPackId != null) {
                    _screen = _Screen.levelSelect;
                  } else if (_hasPacks) {
                    _screen = _Screen.packSelect;
                  } else {
                    _screen = _Screen.levelSelect;
                  }
                }),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Buy Coins', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              Text('Balance: ${widget.coins}', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 14)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Buy coins to use hints and unlock packs', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: packs.length,
              itemBuilder: (context, index) {
                final pack = packs[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (_getColor('primary') ?? Colors.white).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pack['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${pack['coins']} coins', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 13)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (widget.onBuyCoins != null) {
                            widget.onBuyCoins!(pack['id'] as String);
                          } else {
                            widget.onSpendCoins(-(pack['coins'] as int));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary')),
                        child: Text(pack['price'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _checkAnswer(String answer) {
    if (_currentAnswer.length == answer.length) {
      if (_currentAnswer == answer) {
        _playSound();
        _animController.forward(from: 0);
        setState(() => _showComplete = true);
      } else {
        setState(() => _currentAnswer = '');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong answer! Try again'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
        );
      }
    }
  }

  void _useHint() {
    final packLevels = _currentPackLevels;
    final idx = _internalLevelIndex;
    if (idx >= packLevels.length) return;
    final answer = packLevels[idx].answer.toUpperCase();
    if (_currentAnswer.length < answer.length) {
      setState(() => _currentAnswer += answer[_currentAnswer.length]);
      _checkAnswer(answer);
    }
  }

  List<String> _generateLetters(String answer) {
    final chars = answer.split('');
    final all = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    final needed = (widget.config.settings['amountOfLetters'] ?? 14) - chars.length;
    for (var i = 0; i < needed; i++) {
      chars.add(all[_random.nextInt(all.length)]);
    }
    chars.shuffle(_random);
    return chars;
  }
}

class _HangmanPainter extends CustomPainter {
  final int wrongCount;
  _HangmanPainter({required this.wrongCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;

    canvas.drawLine(Offset(20, size.height - 10), Offset(20, 10), paint);
    canvas.drawLine(Offset(20, 10), Offset(cx, 10), paint);
    canvas.drawLine(Offset(cx, 10), Offset(cx, 25), paint);

    if (wrongCount >= 1) {
      paint.style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, 35), 10, paint);
    }
    if (wrongCount >= 2) {
      canvas.drawLine(Offset(cx, 45), Offset(cx, 75), paint);
    }
    if (wrongCount >= 3) {
      canvas.drawLine(Offset(cx, 55), Offset(cx - 15, 65), paint);
    }
    if (wrongCount >= 4) {
      canvas.drawLine(Offset(cx, 55), Offset(cx + 15, 65), paint);
    }
    if (wrongCount >= 5) {
      canvas.drawLine(Offset(cx, 75), Offset(cx - 12, 95), paint);
    }
    if (wrongCount >= 6) {
      canvas.drawLine(Offset(cx, 75), Offset(cx + 12, 95), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HangmanPainter old) => old.wrongCount != wrongCount;
}
