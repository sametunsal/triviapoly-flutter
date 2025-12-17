import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models/player_model.dart';
import 'models/tile_model.dart';
import 'models/question_model.dart';

/// Game mode enum
enum GameMode {
  /// Fixed number of rounds (e.g. 10 / 15 / 20 turns)
  turnBased,

  /// Game ends when the question pool is exhausted
  questionBased,
}

/// Game state enum
enum GameState {
  waitingForDice,
  movingPawn,
  resolvingTile,
  showingPopup,
  endTurn,
  gameOver,
  tieBreak,
}

/// Game configuration constants
class GameConfig {
  /// Starting score for all players.
  static const int initialScore = 0;

  /// Points for a regular question.
  static const int regularQuestionPoints = 50;

  /// Points for a bonus question.
  static const int bonusQuestionPoints = 150;

  /// Default number of turns for turn-based mode.
  static const int defaultTurnCount = 10;

  /// Allowed turn counts for turn-based mode.
  static const List<int> availableTurnCounts = [10, 15, 20];
}

/// Central game controller using ChangeNotifier for state management
class GameController extends ChangeNotifier {
  // Core game data
  List<Player> players;
  List<BoardTile> tiles = [];

  /// Remaining questions for the main game.
  List<Question> questionPool = [];

  /// All questions (immutable source), used for refilling pools (e.g. sudden death).
  final List<Question> _allQuestions = [];

  /// Questions that have already been asked in the main game loop.
  /// Used to recycle questions in turn-based mode so that the pool
  /// never completely runs dry.
  final List<Question> _usedQuestions = [];

  // Game configuration
  GameMode gameMode = GameMode.turnBased;
  int maxTurns = 10;
  int currentTurn = 1;

  // Turn management
  int currentPlayerIndex = 0;
  GameState gameState = GameState.waitingForDice;
  bool canRollDice = true;

  // Dice state
  int diceValue = 0;
  bool isDiceRolling = false;

  // Visual feedback
  int? highlightedTileIndex;
  String? turnFeedback;
  String? turnTransitionMessage;

  // State guards (prevent deadlocks)
  bool _isProcessingTileEffect = false;
  bool isPlanningNextMove = false;
  Timer? _planningStateTimer;

  // Starting order determination
  bool isDeterminingStartingOrder = false;
  Map<int, int> startingDiceRolls = {};
  int? currentlyRollingPlayerId;

  // Panel states
  bool isTileEffectPanelVisible = false;
  String? tileEffectTitle;
  String? tileEffectMessage;
  bool isQuestionPanelVisible = false;
  Question? currentQuestion;
  String? questionFeedback;

  // Game end state
  Player? winner;
  bool isGameEnded = false;

  // Sudden death tie-breaker state
  bool isSuddenDeathActive = false;
  final List<Player> _suddenDeathPlayers = [];
  int _suddenDeathIndex = 0;
  int _suddenDeathRound = 0;
  final Map<int, bool> _suddenDeathRoundAnswers = {};
  Question? _currentSuddenDeathQuestion;

  // Developer mode
  bool isDeveloperMode = true;
  int developerSelectedPlayerIndex = 0;
  int developerMoveTiles = 1;

  // Debug
  bool enableDebugLogs = false;

  // Random number generator
  final Random _random = Random();

  GameController({
    required List<Player> initialPlayers,
    GameMode gameMode = GameMode.turnBased,
    int? maxTurns,
  }) : players = List.from(initialPlayers) {
    // Apply initial configuration coming from the setup screen.
    this.gameMode = gameMode;
    // Clamp the requested turn count to the allowed range.
    final requestedTurns = maxTurns ?? GameConfig.defaultTurnCount;
    if (GameConfig.availableTurnCounts.contains(requestedTurns)) {
      this.maxTurns = requestedTurns;
    } else {
      this.maxTurns = GameConfig.defaultTurnCount;
    }

    _initializeTiles();
    _initializeQuestions();
    _startGame();
  }

  @override
  void dispose() {
    _planningStateTimer?.cancel();
    _planningStateTimer = null;
    super.dispose();
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  void _initializeTiles() {
    final titles = [
      'BAŞLANGIÇ',
      'BEN KİMİM?',
      'TÜRK EDEBİYATINDA İLKLER',
      'BONUS',
      'EDEBİYAT AKIMLARI',
      'EDEBİ SANATLAR',
      'SAĞINDAKİ OYUNCUYA ⭐330 VER!',
      'ESER-KARAKTER',
      'TÜRK EDEBİYATINDA İLKLER',
      'EDEBİ SANATLAR',
      'İFLAS!',
      'EDEBİYAT AKIMLARI',
      'BEN KİMİM?',
      'BONUS',
      'ESER-KARAKTER',
      'KARŞINDAKİ OYUNCUDAN ⭐150 AL!',
      'EDEBİ SANATLAR',
      'BONUS',
      'TÜRK EDEBİYATINDA İLKLER',
      'BEN KİMİM?',
      'SEÇTİĞİN BİR OYUNCUYA BONUS SORU SOR.',
      'EDEBİYAT AKIMLARI',
      'TÜRK EDEBİYATINDA İLKLER',
      'BONUS',
      'EDEBİ SANATLAR',
      'SOLUNDAKİ OYUNCUDAN ⭐200 AL!',
      'BONUS',
      'TÜRK EDEBİYATINDA İLKLER',
      'BONUS',
      'KARŞINDAKİ OYUNCUYA ⭐150 VER!',
      'ESER-KARAKTER',
      'HERKESE ⭐50 VER!',
      'BEN KİMİM?',
      'ESER-KARAKTER',
      'BONUS',
      'EDEBİYAT AKIMLARI',
      'BONUS',
      'KARŞINDAKİ OYUNCUYA ⭐100 VER!',
      'BONUS',
      'TÜRK EDEBİYATINDA İLKLER',
    ];

    for (int i = 0; i < 40; i++) {
      tiles.add(BoardTile(
        index: i,
        title: titles[i],
        type: _getTileType(titles[i]),
      ));
    }
  }

  TileType _getTileType(String title) {
    final normalized = title.trim().toUpperCase();

    if (normalized == 'BAŞLANGIÇ') return TileType.start;
    if (normalized == 'İFLAS!') return TileType.bankrupt;
    if (normalized == 'BONUS') return TileType.bonus;

    if (normalized.contains('⭐') && normalized.contains('VER')) {
      return TileType.penalty;
    }
    if (normalized.contains('⭐') && normalized.contains('AL')) {
      return TileType.bonus;
    }

    if (normalized == 'BEN KİMİM?' ||
        normalized == 'TÜRK EDEBİYATINDA İLKLER' ||
        normalized == 'ESER-KARAKTER' ||
        normalized == 'EDEBİYAT AKIMLARI' ||
        normalized == 'EDEBİ SANATLAR') {
      return TileType.question;
    }

    if (normalized.contains('BONUS SORU')) return TileType.special;
    return TileType.special;
  }

  void _initializeQuestions() {
    final questions = <Question>[
      Question(
        questionText: 'Türk edebiyatının ilk romanı hangisidir?',
        options: [
          'Taaşşuk-ı Talat ve Fitnat',
          'Araba Sevdası',
          'İntibah',
          'Zehra',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.easy,
      ),
      Question(
        questionText: 'Hangisi Namık Kemal\'in eseridir?',
        options: [
          'İntibah',
          'Araba Sevdası',
          'Zehra',
          'Taaşşuk-ı Talat ve Fitnat',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.easy,
      ),
      Question(
        questionText: 'Türk edebiyatında ilk hikâye örneği hangisidir?',
        options: [
          'Küçük Şeyler',
          'Letâif-i Rivâyet',
          'Hikâye-i Güzide',
          'Müsameretnâme',
        ],
        correctIndex: 1,
        difficulty: QuestionDifficulty.medium,
      ),
      Question(
        questionText: 'Hangisi Servet-i Fünun dönemi yazarıdır?',
        options: [
          'Halit Ziya Uşaklıgil',
          'Ömer Seyfettin',
          'Yakup Kadri Karaosmanoğlu',
          'Reşat Nuri Güntekin',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.medium,
      ),
      Question(
        questionText: 'Türk edebiyatında ilk realist roman hangisidir?',
        options: [
          'Araba Sevdası',
          'İntibah',
          'Taaşşuk-ı Talat ve Fitnat',
          'Zehra',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.medium,
      ),
      // ---- HARD (BONUS) QUESTIONS: Literature, Art, General Culture ----
      Question(
        questionText:
            'Aşağıdaki yazarlardan hangisi Nobel Edebiyat Ödülü kazanmıştır?',
        options: [
          'Orhan Pamuk',
          'Yaşar Kemal',
          'Nazım Hikmet',
          'Ahmet Hamdi Tanpınar',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText: '“Suç ve Ceza” romanının yazarı kimdir?',
        options: [
          'Fyodor Dostoyevski',
          'Lev Tolstoy',
          'Anton Çehov',
          'Nikolay Gogol',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText: '“Sefiller” (Les Misérables) adlı eserin yazarı kimdir?',
        options: [
          'Victor Hugo',
          'Gustave Flaubert',
          'Émile Zola',
          'Alexandre Dumas',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText:
            'Aşağıdaki akımlardan hangisi 19. yüzyılda ortaya çıkan bir sanat akımıdır?',
        options: [
          'Empresyonizm',
          'Klasisizm',
          'Rönesans',
          'Barok',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText: '“Yıldızlı Gece” tablosu hangi ressama aittir?',
        options: [
          'Vincent van Gogh',
          'Claude Monet',
          'Pablo Picasso',
          'Salvador Dalí',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText:
            '“Guernica” adlı ünlü tablo hangi ressam tarafından yapılmıştır?',
        options: [
          'Pablo Picasso',
          'Henri Matisse',
          'Paul Cézanne',
          'Joan Miró',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText:
            'Aşağıdaki bestecilerden hangisi Barok dönem sanatçısıdır?',
        options: [
          'Johann Sebastian Bach',
          'Ludwig van Beethoven',
          'Franz Schubert',
          'Johannes Brahms',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText: '“1984” adlı distopya romanının yazarı kimdir?',
        options: [
          'George Orwell',
          'Aldous Huxley',
          'Ray Bradbury',
          'Philip K. Dick',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText:
            'Aşağıdaki düşünürlerden hangisi varoluşçuluk (egzistansiyalizm) ile ilişkilendirilir?',
        options: [
          'Jean-Paul Sartre',
          'Immanuel Kant',
          'Thomas Hobbes',
          'John Locke',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText:
            '“The Persistence of Memory” (Eriyen Saatler) tablosu kime aittir?',
        options: [
          'Salvador Dalí',
          'René Magritte',
          'Marc Chagall',
          'Edvard Munch',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText:
            'Aşağıdaki şehirlerden hangisi Rönesans\'ın doğduğu yer olarak kabul edilir?',
        options: [
          'Floransa',
          'Roma',
          'Paris',
          'Venedik',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText: '“Faust” isimli eser hangi Alman yazara aittir?',
        options: [
          'Johann Wolfgang von Goethe',
          'Friedrich Schiller',
          'Heinrich Heine',
          'Thomas Mann',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText:
            'Aşağıdaki yazarlardan hangisi Latin Amerika büyülü gerçekçilik akımının önemli temsilcisidir?',
        options: [
          'Gabriel García Márquez',
          'Jorge Luis Borges',
          'Mario Vargas Llosa',
          'Carlos Fuentes',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText: '“Scream” (Çığlık) tablosu hangi ressama aittir?',
        options: [
          'Edvard Munch',
          'Paul Gauguin',
          'Egon Schiele',
          'Frida Kahlo',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
      Question(
        questionText:
            'Aşağıdaki antik yapılardan hangisi Zeus heykelinin bulunduğu yer olarak bilinir?',
        options: [
          'Olimpia',
          'Efes',
          'Rodos',
          'Delphi',
        ],
        correctIndex: 0,
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
    ];

    _allQuestions
      ..clear()
      ..addAll(questions);

    // For the main game, we start with a fresh copy of all questions.
    questionPool
      ..clear()
      ..addAll(_allQuestions);
  }

  void _startGame() {
    isDeterminingStartingOrder = true;
    canRollDice = false;
    startingDiceRolls.clear();
    notifyListeners();

    Future.delayed(Duration.zero, () {
      _determineStartingOrder();
    });
  }

  // ============================================================================
  // STATE MANAGEMENT HELPERS
  // ============================================================================

  void _debugLog(String message) {
    if (enableDebugLogs) {
      debugPrint(message);
    }
  }

  /// Force release all turn locks to prevent deadlock.
  ///
  /// IMPORTANT: This should be called from *panel close / confirmation* flows
  /// (Question \"Devam\" button, TileEffect \"OK\" button), not from the middle
  /// of core turn processing.
  void forceReleaseTurnLocks({bool preserveQuestionPanel = false}) {
    _debugLog('[SAFEGUARD] Force releasing all turn locks');
    _isProcessingTileEffect = false;
    isPlanningNextMove = false;
    if (!preserveQuestionPanel) {
      isQuestionPanelVisible = false;
    }
    isTileEffectPanelVisible = false;
    _planningStateTimer?.cancel();
    _planningStateTimer = null;
    notifyListeners();
  }

  void _enterPlanningState() {
    isPlanningNextMove = true;
    _planningStateTimer?.cancel();
    _planningStateTimer = Timer(const Duration(milliseconds: 500), () {
      if (isPlanningNextMove) {
        _debugLog('[SAFEGUARD] Planning state auto-released after timeout');
        // Minimal, local reset to avoid interfering with panel flows.
        _isProcessingTileEffect = false;
        isPlanningNextMove = false;
        _planningStateTimer?.cancel();
        _planningStateTimer = null;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _exitPlanningState() {
    isPlanningNextMove = false;
    _planningStateTimer?.cancel();
    _planningStateTimer = null;
    notifyListeners();
  }

  // ============================================================================
  // STARTING ORDER DETERMINATION
  // ============================================================================

  void _determineStartingOrder() {
    isDeterminingStartingOrder = true;
    turnFeedback = 'Başlangıç sırası belirleniyor...';
    notifyListeners();
    _rollStartingDice();
  }

  void _rollStartingDice() {
    final playersToRoll =
        players.where((p) => !startingDiceRolls.containsKey(p.id)).toList();

    if (playersToRoll.isEmpty) {
      _checkStartingOrderTies();
      return;
    }

    final player = playersToRoll[0];
    final diceValue = _random.nextInt(6) + 1;

    currentlyRollingPlayerId = player.id;
    startingDiceRolls[player.id] = diceValue;
    turnFeedback = '${player.name}: Zar $diceValue';
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 800), () {
      _rollStartingDice();
    });
  }

  void _checkStartingOrderTies() {
    final Map<int, List<Player>> diceGroups = {};
    for (final player in players) {
      final diceValue = startingDiceRolls[player.id]!;
      diceGroups.putIfAbsent(diceValue, () => []).add(player);
    }

    final tiedGroups =
        diceGroups.entries.where((e) => e.value.length > 1).toList();

    if (tiedGroups.isEmpty) {
      _finalizeStartingOrder();
      return;
    }

    turnFeedback = 'Beraberlik! Tekrar zar atılıyor...';
    currentlyRollingPlayerId = null;
    for (final group in tiedGroups) {
      for (final player in group.value) {
        startingDiceRolls.remove(player.id);
      }
    }
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1000), () {
      _rollStartingDice();
    });
  }

  void _finalizeStartingOrder() {
    players.sort((a, b) {
      final diceA = startingDiceRolls[a.id] ?? 0;
      final diceB = startingDiceRolls[b.id] ?? 0;
      return diceB.compareTo(diceA);
    });

    isDeterminingStartingOrder = false;
    gameState = GameState.waitingForDice;
    currentPlayerIndex = 0;
    canRollDice = true;
    turnFeedback = '${players[0].name} başlıyor';
    currentlyRollingPlayerId = null;
    startingDiceRolls.clear();
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1500), () {
      turnFeedback = null;
      notifyListeners();
    });
  }

  double calculateStartingPanelHeight(int playerCount) {
    const double containerPaddingTop = 10.0;
    const double containerPaddingBottom = 7.0;
    const double headerHeight = 24.0;
    const double headerSpacing = 8.0;
    const double playerItemHeight = 34.0;
    const double lastItemMarginAdjustment = 6.0;

    return containerPaddingTop +
        containerPaddingBottom +
        headerHeight +
        headerSpacing +
        (playerItemHeight * playerCount) -
        lastItemMarginAdjustment;
  }

  // ============================================================================
  // DICE ROLLING
  // ============================================================================

  void rollDice() {
    if (isGameEnded) {
      _debugLog('[TURN_FLOW] BLOCKED: Game has ended');
      return;
    }

    if (gameState != GameState.waitingForDice) {
      _debugLog('[TURN_FLOW] BLOCKED: Wrong game state: $gameState');
      return;
    }

    if (!canRollDice) {
      _debugLog('[TURN_FLOW] BLOCKED: canRollDice is false');
      return;
    }

    _debugLog('[TURN_FLOW] ========================================');
    _debugLog(
        '[TURN_FLOW] Dice rolled by: ${players[currentPlayerIndex].name}');

    canRollDice = false;
    notifyListeners();
    _animateDiceRoll();
  }

  void _animateDiceRoll() {
    final finalValue = _random.nextInt(6) + 1;
    int rollCount = 0;
    const maxRolls = 8;

    isDiceRolling = true;
    turnFeedback = 'Zar atılıyor...';
    notifyListeners();

    void rollStep() {
      if (rollCount >= maxRolls) {
        diceValue = finalValue;
        isDiceRolling = false;
        turnFeedback = 'Zar: $finalValue';
        notifyListeners();

        Future.delayed(const Duration(milliseconds: 300), () {
          gameState = GameState.movingPawn;
          notifyListeners();
          _processTurn();
        });
        return;
      }

      final randomValue = _random.nextInt(6) + 1;
      diceValue = randomValue;
      turnFeedback = 'Zar: $randomValue';
      notifyListeners();

      rollCount++;
      final delay = rollCount < maxRolls / 2 ? 80 : 120;
      Future.delayed(Duration(milliseconds: delay), () {
        rollStep();
      });
    }

    Future.delayed(const Duration(milliseconds: 50), () {
      rollStep();
    });
  }

  // ============================================================================
  // PLAYER MOVEMENT
  // ============================================================================

  void _processTurn() {
    _movePlayerStepByStep();
  }

  void _movePlayerStepByStep() {
    final currentPlayer = players[currentPlayerIndex];
    final startPosition = currentPlayer.position;
    final targetPosition = (startPosition + diceValue) % 40;
    int currentStep = 0;

    gameState = GameState.movingPawn;
    turnFeedback = '${currentPlayer.name} hareket ediyor...';
    highlightedTileIndex = null;
    notifyListeners();

    void moveStep() {
      if (currentStep >= diceValue) {
        highlightedTileIndex = targetPosition;
        turnFeedback =
            '${currentPlayer.name} kare ${targetPosition + 1} üzerinde';
        notifyListeners();

        Future.delayed(const Duration(milliseconds: 500), () {
          _processTileEffect(targetPosition);
        });
        return;
      }

      final nextPosition = (startPosition + currentStep + 1) % 40;
      currentPlayer.position = nextPosition;
      highlightedTileIndex = nextPosition;
      turnFeedback = '${currentPlayer.name} kare ${nextPosition + 1}';
      notifyListeners();

      currentStep++;
      Future.delayed(const Duration(milliseconds: 200), () {
        moveStep();
      });
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      moveStep();
    });
  }

  // ============================================================================
  // TILE EFFECT PROCESSING
  // ============================================================================

  int _getTargetPlayerIndex(String tileTitle, int currentIndex) {
    if (tileTitle.contains('KARŞINDAKİ')) {
      return (currentIndex + players.length ~/ 2) % players.length;
    } else if (tileTitle.contains('SAĞINDAKİ')) {
      return (currentIndex + 1) % players.length;
    } else if (tileTitle.contains('SOLUNDAKİ')) {
      return (currentIndex - 1 + players.length) % players.length;
    }
    return -1;
  }

  void _processTileEffect(int position) {
    final currentPlayer = players[currentPlayerIndex];
    final tile = tiles[position];
    final normalizedTitle = tile.title.trim().toUpperCase();
    final isBankruptTitle = normalizedTitle == 'İFLAS!';

    // ABSOLUTE BANKRUPTCY RULE (FIRST CHECK):
    // If this tile is flagged as bankrupt OR its title is exactly 'İFLAS!',
    // immediately apply bankruptcy logic and NEVER fall through to any
    // question / bonus logic.
    if (tile.type == TileType.bankrupt || isBankruptTitle) {
      _debugLog('[BANKRUPT] Absolute bankrupt tile hit at position $position');

      _isProcessingTileEffect = true;
      _enterPlanningState();

      currentPlayer.stars = 0;
      currentPlayer.bankruptCount++;

      isTileEffectPanelVisible = true;
      tileEffectTitle = _getTileTypeTitle(TileType.bankrupt);
      tileEffectMessage = 'İFLAS! Tüm puanlarınız silindi.';
      turnFeedback = tileEffectMessage;
      notifyListeners();

      _debugLog(
          '[BANKRUPT] Player ${currentPlayer.name} went bankrupt. Score reset to 0.');
      _debugLog(
          '[BANKRUPT] TileEffectPanel shown with message: $tileEffectMessage');

      // CRITICAL: Exit immediately so no other tile logic or questions can run.
      return;
    }

    // EMERGENCY GUARD: if the game has already been ended (for example via the
    // "Oyunu Bitir" button), ignore any late tile effects entirely so that no
    // new questions or panels are triggered.
    if (isGameEnded) {
      _debugLog(
          '[TURN_FLOW] BLOCKED: _processTileEffect called after game ended');
      return;
    }

    if (_isProcessingTileEffect) {
      _debugLog('[TURN_FLOW] BLOCKED: _processTileEffect already in progress');
      return;
    }

    assert(
      !(isPlanningNextMove && isQuestionPanelVisible),
      "INVALID STATE: planning while question panel open",
    );

    final scoreBefore = currentPlayer.stars;

    _debugLog('[TURN_FLOW] ========================================');
    _debugLog('[TURN_FLOW] Player: ${currentPlayer.name}');
    _debugLog('[TURN_FLOW] Dice Value: $diceValue');
    _debugLog('[TURN_FLOW] Landing Position: $position');
    _debugLog('[TURN_FLOW] Tile Type: ${tile.type}');
    _debugLog('[TURN_FLOW] Score Before: $scoreBefore');

    _isProcessingTileEffect = true;
    _enterPlanningState();

    gameState = GameState.resolvingTile;
    highlightedTileIndex = position;
    turnFeedback = '${currentPlayer.name}: ${tile.title}';
    notifyListeners();

    String effectMessage = '';
    bool hasEffect = false;
    bool shouldShowPanel = false;

    switch (tile.type) {
      case TileType.start:
        effectMessage = 'Başlangıç karesi - etki yok';
        shouldShowPanel = false;
        break;

      case TileType.penalty:
        final amount = _parseStarAmount(tile.title);
        if (amount > 0) {
          currentPlayer.stars =
              (currentPlayer.stars - amount).clamp(0, double.infinity).toInt();
          effectMessage =
              '⭐ -$amount yıldız kaybettiniz (Kalan: ${currentPlayer.stars})';
          hasEffect = true;
          shouldShowPanel = true;
        } else {
          effectMessage = 'Ceza aldınız';
          shouldShowPanel = true;
        }
        break;

      case TileType.bankrupt:
        // Handled by absolute bankruptcy guard above; we should never reach here.
        _debugLog(
            '[BANKRUPT] WARNING: Reached TileType.bankrupt switch case unexpectedly.');
        break;

      case TileType.bonus:
        if (tile.title.contains('⭐') && tile.title.contains('AL')) {
          final amount = _parseStarAmount(tile.title);
          if (amount > 0) {
            final targetIndex =
                _getTargetPlayerIndex(tile.title, currentPlayerIndex);
            if (targetIndex >= 0 && targetIndex < players.length) {
              final targetPlayer = players[targetIndex];
              final transferAmount = amount.clamp(0, targetPlayer.stars);
              targetPlayer.stars -= transferAmount;
              currentPlayer.stars += transferAmount;
              effectMessage =
                  '${targetPlayer.name}\'den ⭐ $transferAmount aldınız (Toplam: ${currentPlayer.stars})';
            } else {
              currentPlayer.stars += amount;
              effectMessage =
                  '⭐ +$amount yıldız kazandınız (Toplam: ${currentPlayer.stars})';
            }
            hasEffect = true;
            shouldShowPanel = true;
          }
        } else {
          // BONUS QUESTION FLOW:
          // When landing on a pure "BONUS" tile (no direct star transfer),
          // we trigger a difficult bonus question worth 150 points.
          final bonusQuestions = questionPool.where((q) => q.isBonus).toList();

          if (bonusQuestions.isNotEmpty) {
            final question = _drawBonusQuestionFromPool();
            if (question != null) {
              isQuestionPanelVisible = true;
              currentQuestion = question;
              questionFeedback = null;
              canRollDice = false;
              notifyListeners();

              _debugLog(
                  '[BONUS] Bonus question shown: ${question.questionText} '
                  '(difficulty: ${question.difficulty})');
              return; // Question panel will handle the rest
            }
          }

          // Fallback: no suitable bonus questions left
          effectMessage = 'Bonus karesi - soru yok';
          shouldShowPanel = true;
        }
        break;

      case TileType.question:
        // REGULAR QUESTION FLOW:
        // Prefer non-bonus (regular) questions for standard 50‑point rewards.
        final regularQuestion = _drawRegularQuestionFromPool();
        if (regularQuestion != null) {
          isQuestionPanelVisible = true;
          currentQuestion = regularQuestion;
          questionFeedback = null;
          canRollDice = false;
          notifyListeners();

          _debugLog(
              '[QUESTION] Showing regular question: ${regularQuestion.questionText} '
              '(difficulty: ${regularQuestion.difficulty})');
          _debugLog('[QUESTION] Remaining questions: ${questionPool.length}');
          return; // Question panel handles the rest
        }

        // Fallback when no questions are available at all (question-based mode
        // or complete exhaustion).
        effectMessage = 'Soru karesi - soru bulunamadı';
        hasEffect = true;
        shouldShowPanel = true;
        break;

      case TileType.special:
        if (tile.title.contains('BONUS SORU')) {
          effectMessage = 'Özel: Bonus soru sorabilirsiniz';
          hasEffect = true;
          shouldShowPanel = true;
        } else if (tile.title.contains('VER')) {
          final amount = _parseStarAmount(tile.title);
          if (amount > 0) {
            final targetIndex =
                _getTargetPlayerIndex(tile.title, currentPlayerIndex);
            if (targetIndex >= 0 && targetIndex < players.length) {
              final targetPlayer = players[targetIndex];
              final transferAmount = amount.clamp(0, currentPlayer.stars);
              currentPlayer.stars -= transferAmount;
              targetPlayer.stars += transferAmount;
              effectMessage =
                  '${targetPlayer.name}\'e ⭐ $transferAmount verdiniz (Kalan: ${currentPlayer.stars})';
            } else {
              currentPlayer.stars = (currentPlayer.stars - amount)
                  .clamp(0, double.infinity)
                  .toInt();
              effectMessage =
                  '⭐ -$amount yıldız kaybettiniz (Kalan: ${currentPlayer.stars})';
            }
            hasEffect = true;
            shouldShowPanel = true;
          }
        } else if (tile.title.contains('HERKESE')) {
          final amount = _parseStarAmount(tile.title);
          if (amount > 0) {
            final totalCost = amount * (players.length - 1);
            final actualCost = totalCost.clamp(0, currentPlayer.stars);
            final perPlayer = actualCost ~/ (players.length - 1);
            for (var player in players) {
              if (player.id != currentPlayer.id) {
                player.stars += perPlayer;
              }
            }
            currentPlayer.stars -= actualCost;
            effectMessage =
                'Herkese ⭐ $perPlayer verdiniz (Toplam: -$actualCost, Kalan: ${currentPlayer.stars})';
            hasEffect = true;
            shouldShowPanel = true;
          }
        } else {
          effectMessage = 'Özel kare etkisi';
          shouldShowPanel = false;
        }
        break;
    }

    turnFeedback = effectMessage;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 500), () {
      highlightedTileIndex = null;
      notifyListeners();
    });

    final scoreAfter = currentPlayer.stars;
    _debugLog('[TURN_FLOW] Score After: $scoreAfter');
    _debugLog('[TURN_FLOW] Should Show Panel: $shouldShowPanel');

    if (shouldShowPanel) {
      if (isTileEffectPanelVisible) {
        _debugLog('[TURN_FLOW] WARNING: Panel already visible, skipping');
        return;
      }

      isTileEffectPanelVisible = true;
      tileEffectTitle = _getTileTypeTitle(tile.type);
      tileEffectMessage = effectMessage;
      notifyListeners();
      _debugLog('[TURN_FLOW] Panel shown, waiting for user acknowledgement');
    } else {
      _exitPlanningState();
      _isProcessingTileEffect = false;
      final delay = hasEffect ? 1500 : 800;
      Future.delayed(Duration(milliseconds: delay), () {
        endTurn();
      });
      _debugLog('[TURN_FLOW] No panel, ending turn after delay');
    }
  }

  String _getTileTypeTitle(TileType type) {
    switch (type) {
      case TileType.bonus:
        return 'Bonus Karesi';
      case TileType.penalty:
        return 'Ceza Karesi';
      case TileType.question:
        return 'Soru Karesi';
      case TileType.bankrupt:
        return 'İflas';
      case TileType.special:
        return 'Özel Kare';
      default:
        return 'Kare Etkisi';
    }
  }

  int _parseStarAmount(String text) {
    final regex = RegExp(r'⭐(\d+)');
    final match = regex.firstMatch(text);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0;
  }

  // ============================================================================
  // QUESTION HANDLING
  // ============================================================================

  /// In turn-based mode, when the main question pool runs out, recycle the
  /// questions that have already been used so players never see "Soru bulunamadı".
  void _recycleQuestionsIfNeededForTurnBased() {
    if (gameMode != GameMode.turnBased) return;
    if (questionPool.isNotEmpty) return;
    if (_usedQuestions.isEmpty) return;

    questionPool.addAll(_usedQuestions);
    _usedQuestions.clear();
    questionPool.shuffle(_random);
    _debugLog(
        '[QUESTION] Question pool refilled from used questions (turn-based mode)');
  }

  /// Draw a regular (non-bonus) question from the main pool, preferring
  /// non-bonus entries so that standard tiles award 50 points.
  Question? _drawRegularQuestionFromPool() {
    if (questionPool.isEmpty) {
      _recycleQuestionsIfNeededForTurnBased();
      if (questionPool.isEmpty) return null;
    }

    // Prefer non-bonus, easy/medium questions
    final easyMed = questionPool
        .where((q) => !q.isBonus && q.difficulty != QuestionDifficulty.hard)
        .toList();

    List<Question> source;
    if (easyMed.isNotEmpty) {
      source = easyMed;
    } else {
      // Fallback: any non-bonus question
      final regular = questionPool.where((q) => !q.isBonus).toList();
      if (regular.isNotEmpty) {
        source = regular;
      } else {
        // Ultimate fallback: any remaining question
        source = List<Question>.from(questionPool);
      }
    }

    final chosen = source[_random.nextInt(source.length)];

    // Remove the chosen instance from questionPool so that question-based
    // games can terminate when the pool is exhausted.
    final indexInPool = questionPool.indexOf(chosen);
    if (indexInPool != -1) {
      questionPool.removeAt(indexInPool);
    }

    // Track as used so we can recycle in turn-based mode.
    _usedQuestions.add(chosen);

    return chosen;
  }

  /// Draw a bonus question from the pool, preferring HARD difficulty,
  /// then MEDIUM, then any bonus question.
  Question? _drawBonusQuestionFromPool() {
    if (questionPool.isEmpty) {
      _recycleQuestionsIfNeededForTurnBased();
      if (questionPool.isEmpty) return null;
    }

    final bonusInPool = questionPool.where((q) => q.isBonus).toList();
    if (bonusInPool.isEmpty) return null;

    List<Question> candidates = bonusInPool
        .where((q) => q.difficulty == QuestionDifficulty.hard)
        .toList();
    if (candidates.isEmpty) {
      candidates = bonusInPool
          .where((q) => q.difficulty == QuestionDifficulty.medium)
          .toList();
    }
    if (candidates.isEmpty) {
      candidates = bonusInPool;
    }

    final chosen = candidates[_random.nextInt(candidates.length)];

    final indexInPool = questionPool.indexOf(chosen);
    if (indexInPool != -1) {
      questionPool.removeAt(indexInPool);
    }

    // Track as used so we can recycle in turn-based mode.
    _usedQuestions.add(chosen);

    return chosen;
  }

  void handleQuestionAnswer(int selectedIndex) {
    if (currentQuestion == null) {
      _debugLog(
          '[QUESTION] ERROR: handleQuestionAnswer called but currentQuestion is null');
      return;
    }

    final currentPlayer = players[currentPlayerIndex];

    // SAFETY NET: If for any reason a question panel was opened while the
    // player is standing on the bankruptcy tile, immediately enforce the
    // bankrupt rules and close the panel without giving any points.
    final currentTile = tiles[currentPlayer.position];
    final normalizedTitle = currentTile.title.trim().toUpperCase();
    final isBankruptTitle = normalizedTitle == 'İFLAS!';
    if (currentTile.type == TileType.bankrupt || isBankruptTitle) {
      _debugLog(
          '[BANKRUPT] Safety in handleQuestionAnswer for tile "${currentTile.title}"');
      currentPlayer.stars = 0;
      currentPlayer.bankruptCount++;

      isQuestionPanelVisible = false;
      currentQuestion = null;
      questionFeedback = null;
      turnFeedback = null;
      notifyListeners();

      endTurn();
      return;
    }

    final question = currentQuestion!;
    final isCorrect = selectedIndex == question.correctIndex;

    _debugLog('[QUESTION] ========================================');
    _debugLog('[QUESTION] Answer selected: index $selectedIndex');
    _debugLog('[QUESTION] Is correct: $isCorrect');
    _debugLog('[QUESTION] Stars before: ${currentPlayer.stars}');

    if (isCorrect) {
      // Determine points based on whether this is a bonus question
      final points = question.isBonus
          ? GameConfig.bonusQuestionPoints
          : GameConfig.regularQuestionPoints;

      final before = currentPlayer.stars;
      currentPlayer.stars =
          (currentPlayer.stars + points).clamp(0, double.infinity).toInt();

      if (question.isBonus) {
        // Track correct bonus questions for tie‑breaker
        currentPlayer.bonusQuestionsAnswered++;
      }

      questionFeedback = question.isBonus
          ? 'Doğru! +$points puan (Bonus soru)'
          : 'Doğru! +$points puan';

      _debugLog(
          '[QUESTION] Correct. +$points points. Before: $before, After: ${currentPlayer.stars}');
    } else {
      // Wrong answers give 0 points (no deduction)
      questionFeedback = 'Yanlış cevap (0 puan)';
      _debugLog(
          '[QUESTION] Wrong answer. Score unchanged: ${currentPlayer.stars}');
    }

    // If we are in a sudden death round, track this player's result for the
    // current round so we can eliminate or keep them later.
    if (isSuddenDeathActive) {
      _suddenDeathRoundAnswers[currentPlayer.id] = isCorrect;
    }

    // NOTE: Do NOT auto-close the panel here. We only set feedback and wait for
    // the user to press the \"Devam\" button, which calls closeQuestionPanel().
    notifyListeners();
  }

  void closeQuestionPanel() {
    if (!isQuestionPanelVisible) {
      return;
    }

    _debugLog('[QUESTION] Question panel closed by user');

    _planningStateTimer?.cancel();
    _planningStateTimer = null;

    isQuestionPanelVisible = false;
    currentQuestion = null;
    questionFeedback = null;
    turnFeedback = null;

    // Release locks *after* the question has been answered and the user has
    // acknowledged the result, then continue turn flow.
    forceReleaseTurnLocks();

    // Dice will be re‑enabled for the next player in endTurn() for normal
    // gameplay. During sudden death, dice remain disabled.
    notifyListeners();

    endTurn();
  }

  // ============================================================================
  // TILE EFFECT PANEL
  // ============================================================================

  void closeTileEffectPanel() {
    _debugLog('[TURN_FLOW] Tile effect panel closed by user');

    // Release locks after the user confirms the panel, then end the turn.
    forceReleaseTurnLocks();

    isTileEffectPanelVisible = false;
    tileEffectTitle = null;
    tileEffectMessage = null;
    turnFeedback = null;
    notifyListeners();

    _debugLog('[TURN_FLOW] State reset complete - calling endTurn()');

    endTurn();
  }

  // ============================================================================
  // TURN MANAGEMENT
  // ============================================================================

  void endTurn() {
    // If the game has already ended (e.g. user pressed "Oyunu Bitir"),
    // ignore any late endTurn calls coming from delayed flows.
    if (isGameEnded) {
      _debugLog('[TURN_FLOW] BLOCKED: endTurn() called after game ended');
      return;
    }

    _debugLog('[TURN_FLOW] ========================================');
    _debugLog(
        '[TURN_FLOW] Ending turn for: ${players[currentPlayerIndex].name}');

    // If we are in sudden death mode, we don't advance normal turns.
    if (isSuddenDeathActive) {
      _advanceSuddenDeathAfterAnswer();
      return;
    }

    // Check for game end conditions based on mode
    if (gameMode == GameMode.turnBased) {
      if (currentPlayerIndex == players.length - 1) {
        // Completed a full round
        _debugLog('[TURN_FLOW] Round completed. Current turn: $currentTurn');
        if (currentTurn >= maxTurns) {
          _debugLog('[TURN_FLOW] Max turns reached, ending game');
          _checkGameEnd();
          return;
        }
        currentTurn++;
      }
    } else if (gameMode == GameMode.questionBased) {
      // In question-based mode, when there are no remaining questions,
      // we end the game and resolve the winner.
      if (questionPool.isEmpty) {
        _debugLog('[TURN_FLOW] No questions remaining, ending game');
        _checkGameEnd();
        return;
      }
    }

    // Move to next player
    final nextPlayerIndex = (currentPlayerIndex + 1) % players.length;
    final nextPlayer = players[nextPlayerIndex];

    _debugLog('[TURN_FLOW] Next Player: ${nextPlayer.name}');

    currentPlayerIndex = nextPlayerIndex;
    gameState = GameState.waitingForDice;
    diceValue = 0;
    canRollDice = true;
    turnFeedback = '${nextPlayer.name} sırası';
    highlightedTileIndex = null;
    isDiceRolling = false;
    _isProcessingTileEffect = false;
    isPlanningNextMove = false;
    turnTransitionMessage = 'Sıra: ${nextPlayer.name}';
    notifyListeners();

    _debugLog('[TURN_FLOW] Turn ended successfully');

    Future.delayed(const Duration(milliseconds: 400), () {
      turnTransitionMessage = null;
      notifyListeners();
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      turnFeedback = null;
      notifyListeners();
    });
  }

  // ============================================================================
  // WIN CONDITIONS
  // ============================================================================
  /// Evaluate final scores and resolve winner with tie-breakers:
  /// 1) Highest score
  /// 2) Highest bonusCorrectCount
  /// 3) Sudden death questions among remaining tied players
  void _checkGameEnd({bool allowSuddenDeath = true}) {
    _debugLog('[GAME_RULES] Evaluating final scores...');

    // Primary sort by score
    final sorted = List<Player>.from(players);
    sorted.sort((a, b) => b.stars.compareTo(a.stars));

    final topScore = sorted.first.stars;
    final topScorePlayers = sorted.where((p) => p.stars == topScore).toList();

    if (topScorePlayers.length == 1) {
      _endGameInternal(topScorePlayers.first);
      return;
    }

    // Tie‑breaker 1: most correct bonus questions
    topScorePlayers.sort(
      (a, b) => b.bonusQuestionsAnswered.compareTo(a.bonusQuestionsAnswered),
    );
    final topBonus = topScorePlayers.first.bonusQuestionsAnswered;
    final bonusLeaders = topScorePlayers
        .where((p) => p.bonusQuestionsAnswered == topBonus)
        .toList();

    if (bonusLeaders.length == 1) {
      _endGameInternal(bonusLeaders.first);
      return;
    }

    // If manual end has been requested, we do NOT want to start a new sudden
    // death round (which would show more questions). In that case, simply pick
    // the first bonus leader as the winner based on current scores.
    if (!allowSuddenDeath) {
      final manualWinner = bonusLeaders.first;
      _debugLog(
          '[GAME_RULES] Manual end: skipping sudden death, winner: ${manualWinner.name}');
      _endGameInternal(manualWinner);
      return;
    }

    // Tie‑breaker 2: Sudden death trivia round among the remaining tied players
    _startSuddenDeath(bonusLeaders);
  }

  void _endGameInternal(Player winningPlayer) {
    isSuddenDeathActive = false;
    _suddenDeathPlayers.clear();
    _suddenDeathRoundAnswers.clear();
    _suddenDeathIndex = 0;
    _suddenDeathRound = 0;

    isGameEnded = true;
    winner = winningPlayer;
    canRollDice = false;
    gameState = GameState.gameOver;
    notifyListeners();
    _debugLog(
        '[GAME_RULES] Game ended. Winner: ${winningPlayer.name} with ${winningPlayer.stars} points');
  }

  // ============================================================================
  // GAME RESTART
  // ============================================================================

  void restartGame() {
    _debugLog('[GAME_RULES] Restarting game...');

    for (var player in players) {
      player.stars = GameConfig.initialScore;
      player.position = 0;
      player.bankruptCount = 0;
      player.bonusQuestionsAnswered = 0;
    }

    currentPlayerIndex = 0;
    currentTurn = 1;
    gameState = GameState.waitingForDice;
    diceValue = 0;
    canRollDice = true;
    isGameEnded = false;
    winner = null;
    isQuestionPanelVisible = false;
    isTileEffectPanelVisible = false;
    currentQuestion = null;
    questionFeedback = null;
    tileEffectTitle = null;
    tileEffectMessage = null;
    turnFeedback = null;
    turnTransitionMessage = null;
    highlightedTileIndex = null;
    isDiceRolling = false;
    _isProcessingTileEffect = false;
    isPlanningNextMove = false;
    isDeterminingStartingOrder = true;
    startingDiceRolls.clear();
    currentlyRollingPlayerId = null;
    notifyListeners();

    _debugLog(
        '[GAME_RULES] Game reset complete, determining starting order...');

    Future.delayed(Duration.zero, () {
      _determineStartingOrder();
    });
  }

  /// Manually trigger end-of-game evaluation (used by the \"End Game\" button).
  void endGameNow() {
    if (isGameEnded) return;
    _debugLog('[GAME_RULES] Manual end game triggered');

    // HARD STOP: Immediately lock down the game so no further mechanics run.
    isGameEnded = true;
    gameState = GameState.gameOver;
    canRollDice = false;

    // Hide any open panels and clear popup/question state.
    isQuestionPanelVisible = false;
    isTileEffectPanelVisible = false;
    currentQuestion = null;
    questionFeedback = null;
    tileEffectTitle = null;
    tileEffectMessage = null;

    // Clear all turn locks / planning guards and update the UI.
    forceReleaseTurnLocks(preserveQuestionPanel: false);

    // Immediately evaluate final scores and show the winner panel based on the
    // current scores, without starting any sudden death question rounds.
    _checkGameEnd(allowSuddenDeath: false);
  }

  // ============================================================================
  // SUDDEN DEATH TIE-BREAKER
  // ============================================================================

  void _startSuddenDeath(List<Player> tiedPlayers) {
    isSuddenDeathActive = true;
    _suddenDeathPlayers
      ..clear()
      ..addAll(tiedPlayers);
    _suddenDeathIndex = 0;
    _suddenDeathRound = 1;
    _suddenDeathRoundAnswers.clear();
    _currentSuddenDeathQuestion = null;

    gameState = GameState.tieBreak;
    canRollDice = false;
    turnFeedback = 'Beraberlik! Ani ölüm turu başlıyor';
    _debugLog(
        '[SUDDEN_DEATH] Starting sudden death with players: ${_suddenDeathPlayers.map((p) => p.name).join(', ')}');
    notifyListeners();

    _askSuddenDeathQuestionForCurrentPlayer();
  }

  void _askSuddenDeathQuestionForCurrentPlayer() {
    if (!isSuddenDeathActive || _suddenDeathPlayers.isEmpty) {
      return;
    }

    if (_suddenDeathIndex < 0 ||
        _suddenDeathIndex >= _suddenDeathPlayers.length) {
      _suddenDeathIndex = 0;
    }

    final player = _suddenDeathPlayers[_suddenDeathIndex];
    final globalIndex = players.indexWhere((p) => p.id == player.id);
    if (globalIndex != -1) {
      currentPlayerIndex = globalIndex;
    }

    // Ensure we have a single shared question for this sudden death round.
    if (_currentSuddenDeathQuestion == null) {
      if (_allQuestions.isNotEmpty) {
        final idx = _random.nextInt(_allQuestions.length);
        _currentSuddenDeathQuestion = _allQuestions[idx];
      } else if (questionPool.isNotEmpty) {
        final idx = _random.nextInt(questionPool.length);
        _currentSuddenDeathQuestion = questionPool[idx];
      }
    }

    final question = _currentSuddenDeathQuestion;

    if (question == null) {
      // No questions available – as a fallback, end with the first player.
      _debugLog(
          '[SUDDEN_DEATH] No questions available, picking first tied player as winner.');
      _endGameInternal(player);
      return;
    }

    isQuestionPanelVisible = true;
    currentQuestion = question;
    questionFeedback = null;
    turnFeedback = 'Ani ölüm sorusu: ${player.name}';
    _debugLog(
        '[SUDDEN_DEATH] Asking question to ${player.name}: ${question.questionText}');
    notifyListeners();
  }

  void _advanceSuddenDeathAfterAnswer() {
    if (!isSuddenDeathActive || _suddenDeathPlayers.isEmpty) {
      return;
    }

    final current = _suddenDeathPlayers[_suddenDeathIndex];
    final answeredCorrect = _suddenDeathRoundAnswers[current.id] ?? false;
    _debugLog(
        '[SUDDEN_DEATH] Player ${current.name} answered: ${answeredCorrect ? 'CORRECT' : 'WRONG'}');

    _suddenDeathIndex++;

    // If there are still players in this round who haven't answered, move to next.
    if (_suddenDeathIndex < _suddenDeathPlayers.length) {
      _askSuddenDeathQuestionForCurrentPlayer();
      return;
    }

    // Round completed – evaluate survivors for this question.
    final survivors = _suddenDeathPlayers
        .where((p) => _suddenDeathRoundAnswers[p.id] == true)
        .toList();

    if (survivors.length == 1) {
      _debugLog(
          '[SUDDEN_DEATH] Single survivor after round $_suddenDeathRound: ${survivors.first.name}');
      _endGameInternal(survivors.first);
      return;
    }

    // If no one survived, everyone stays for the next round.
    final nextRoundPlayers =
        survivors.isEmpty ? List<Player>.from(_suddenDeathPlayers) : survivors;

    // Setup next sudden death round with survivors.
    _suddenDeathPlayers
      ..clear()
      ..addAll(nextRoundPlayers);
    _suddenDeathRoundAnswers.clear();
    _suddenDeathIndex = 0;
    _suddenDeathRound++;
    _currentSuddenDeathQuestion = null;

    _debugLog(
        '[SUDDEN_DEATH] Next round $_suddenDeathRound with players: ${_suddenDeathPlayers.map((p) => p.name).join(', ')}');
    _askSuddenDeathQuestionForCurrentPlayer();
  }

  // ============================================================================
  // DEVELOPER MODE
  // ============================================================================

  void updateDeveloperSelectedPlayer(int delta) {
    final newIndex = developerSelectedPlayerIndex + delta;
    if (newIndex >= 0 && newIndex < players.length) {
      developerSelectedPlayerIndex = newIndex;
      notifyListeners();
    }
  }

  void updateDeveloperMoveTiles(int delta) {
    final newValue = developerMoveTiles + delta;
    if (newValue >= 1 && newValue <= 39) {
      developerMoveTiles = newValue;
      notifyListeners();
    }
  }

  void developerForceMove() {
    // Developer move is a utility; it should never run after the game ended.
    if (isGameEnded) {
      _debugLog('[DEV_MODE] BLOCKED: developerForceMove called after game end');
      return;
    }

    if (developerSelectedPlayerIndex < 0 ||
        developerSelectedPlayerIndex >= players.length) {
      _debugLog(
          '[DEV_MODE] Invalid player index: $developerSelectedPlayerIndex');
      return;
    }

    if (_isProcessingTileEffect) {
      _debugLog('[DEV_MODE] BLOCKED: Tile effect already in progress');
      return;
    }

    // Treat this as a forced move for the selected player, aligned with
    // natural turn flow so that turn counters and currentPlayerIndex stay
    // consistent.
    currentPlayerIndex = developerSelectedPlayerIndex;
    final player = players[currentPlayerIndex];
    final currentPos = player.position;
    final moveAmount = developerMoveTiles.clamp(1, 39);
    final newPosition = (currentPos + moveAmount) % 40;

    _debugLog(
        '[DEV_MODE] Force moving ${player.name} from $currentPos to $newPosition (+$moveAmount)');

    // Update dice/gameState to reflect a movement-like action, but we do not
    // animate the pawn here.
    diceValue = moveAmount;
    gameState = GameState.resolvingTile;
    canRollDice = false;

    player.position = newPosition;
    highlightedTileIndex = newPosition;
    notifyListeners();

    _processTileEffect(newPosition);
  }
}
