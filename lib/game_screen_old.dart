import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'player_setup_screen.dart';
import 'board_painter.dart';
import 'scoreboard_widget.dart';
import 'game_panels.dart';

enum GameMode {
  turnBased,
  questionUntilEnd,
}

enum GameState {
  waitingForDice,
  movingPawn,
  resolvingTile,
  showingPopup,
  endTurn,
  gameOver,
  tieBreak,
}

enum TileType {
  start,
  question,
  bonus,
  penalty,
  bankrupt,
  special,
}

// Game configuration constants
class GameConfig {
  static const int winStarsThreshold =
      10; // Player wins when reaching this many stars
}

class Player {
  final int id;
  final String name;
  final Color color;
  final IconData pawnIcon;
  int position;
  int stars;
  int bankruptCount;
  int bonusQuestionsAnswered;

  Player({
    required this.id,
    required this.name,
    required this.color,
    required this.pawnIcon,
    required this.position,
    required this.stars,
    this.bankruptCount = 0,
    this.bonusQuestionsAnswered = 0,
  });
}

class BoardTile {
  final int index;
  final String title;
  final TileType type;

  BoardTile({
    required this.index,
    required this.title,
    required this.type,
  });
}

enum QuestionDifficulty {
  easy,
  medium,
  hard,
}

class Question {
  final String questionText; // Renamed from 'question' for clarity
  final List<String> options; // A, B, C, D
  final int correctIndex; // Index of correct answer (0-3)
  final QuestionDifficulty difficulty;
  final bool isBonus; // Legacy field for bonus questions

  Question({
    required this.questionText,
    required this.options,
    required this.correctIndex,
    this.difficulty = QuestionDifficulty.medium,
    this.isBonus = false,
  });
}

class GameScreen extends StatefulWidget {
  final List<Player> players;

  const GameScreen({
    super.key,
    required this.players,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void dispose() {
    // Clean up planning state timer
    _planningStateTimer?.cancel();
    _planningStateTimer = null;
    super.dispose();
  }

  late List<Player> players;
  List<BoardTile> tiles = [];
  List<Question> questionPool = [];
  GameMode? gameMode;
  int? maxTurns;
  int currentTurn = 0;
  int currentPlayerIndex = 0;
  GameState gameState = GameState.waitingForDice;
  int diceValue = 0;
  List<Player> tiedPlayers = [];
  int tieBreakQuestionIndex = 0;
  Map<int, bool?> tieBreakAnswers = {};
  final Random _random = Random();
  bool isModalVisible = false;
  Widget? activeModalContent;
  bool canRollDice = true;
  String? turnFeedback; // Text feedback for current turn action
  bool isDiceRolling = false; // Track dice animation
  int? highlightedTileIndex; // Track which tile is highlighted
  bool _isProcessingTileEffect =
      false; // Guard to prevent duplicate _processTileEffect calls
  bool isPlanningNextMove =
      false; // Track if game is in planning/processing state
  Timer? _planningStateTimer; // Timer for planning state timeout failsafe
  bool isDeterminingStartingOrder =
      false; // Track if we're determining starting order
  Map<int, int> startingDiceRolls =
      {}; // Track dice rolls for starting order (playerId -> diceValue)
  int? currentlyRollingPlayerId; // Track which player is currently rolling
  bool isTileEffectPanelVisible =
      false; // Track if tile effect panel is visible
  String? tileEffectTitle; // Title for tile effect panel
  String? tileEffectMessage; // Message for tile effect panel
  // Question panel state
  bool isQuestionPanelVisible = false; // Track if question panel is visible
  Question? currentQuestion; // Current question being displayed
  String? questionFeedback; // Feedback message after answering (correct/wrong)
  // Developer mode
  bool isDeveloperMode =
      true; // Set to true to enable developer panel (default: true for development)
  int developerSelectedPlayerIndex = 0; // Selected player for force move
  int developerMoveTiles = 1; // Number of tiles to move
  // Debug logs
  bool enableDebugLogs = false; // Set to true to enable debug logging
  // Turn transition feedback
  String? turnTransitionMessage; // Brief message shown when turn transitions
  // Game end state
  Player? winner; // Winner of the game (null if game not ended)
  bool isGameEnded = false; // True when game has ended

  // Debug log helper - only prints if enableDebugLogs is true
  void _debugLog(String message) {
    if (enableDebugLogs) {
      debugPrint(message);
    }
  }

  /// HARD RESET RULE: Force release all turn locks to prevent deadlock
  /// NOTE: Does NOT reset isQuestionPanelVisible if question is active
  void _forceReleaseTurnLocks({bool preserveQuestionPanel = false}) {
    _debugLog('[SAFEGUARD] Force releasing all turn locks');
    _isProcessingTileEffect = false;
    isPlanningNextMove = false;
    // Only reset question panel if not preserving it
    if (!preserveQuestionPanel) {
      isQuestionPanelVisible = false;
    }
    isTileEffectPanelVisible = false;
    // Cancel any active planning timer
    _planningStateTimer?.cancel();
    _planningStateTimer = null;
  }

  /// Start planning state with timeout failsafe
  void _enterPlanningState() {
    isPlanningNextMove = true;
    // Cancel any existing timer
    _planningStateTimer?.cancel();
    // Start timeout failsafe (500ms max)
    _planningStateTimer = Timer(const Duration(milliseconds: 500), () {
      if (isPlanningNextMove && mounted) {
        _debugLog('[SAFEGUARD] Planning state auto-released after timeout');
        _forceReleaseTurnLocks();
      }
    });
  }

  /// Exit planning state
  void _exitPlanningState() {
    isPlanningNextMove = false;
    _planningStateTimer?.cancel();
    _planningStateTimer = null;
  }

  // MODAL DISABLED - Stabilization step
  void _showModal(Widget content) {
    // Temporarily disabled to prevent freeze
    // setState(() {
    //   activeModalContent = content;
    //   isModalVisible = true;
    // });
  }

  void _hideModal() {
    // Temporarily disabled to prevent freeze
    // setState(() {
    //   isModalVisible = false;
    //   activeModalContent = null;
    // });
  }

  @override
  void initState() {
    super.initState();
    players = List.from(widget.players);
    _initializeTiles();
    _initializeQuestions();
    // Initialize default game mode since dialogs are disabled
    setState(() {
      gameMode = GameMode.turnBased;
      maxTurns = 10;
      currentTurn = 1;
      isDeterminingStartingOrder = true;
      canRollDice = false; // Disable until starting order is determined
      startingDiceRolls.clear();
    });
    // Start determining player order
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _determineStartingOrder();
      }
    });
  }

  void _determineStartingOrder() {
    setState(() {
      isDeterminingStartingOrder = true;
      turnFeedback = 'Başlangıç sırası belirleniyor...';
    });

    // Roll dice for all players
    _rollStartingDice();
  }

  void _rollStartingDice() {
    // Roll dice for all players who don't have a roll yet
    final playersToRoll =
        players.where((p) => !startingDiceRolls.containsKey(p.id)).toList();

    if (playersToRoll.isEmpty) {
      // All players have rolled, check for ties
      _checkStartingOrderTies();
      return;
    }

    // Roll dice for next player
    final player = playersToRoll[0];
    final diceValue = _random.nextInt(6) + 1;

    setState(() {
      currentlyRollingPlayerId = player.id;
      startingDiceRolls[player.id] = diceValue;
      turnFeedback = '${player.name}: Zar $diceValue';
    });

    // Continue with next player after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _rollStartingDice();
    });
  }

  void _checkStartingOrderTies() {
    // Group players by dice value
    final Map<int, List<Player>> diceGroups = {};
    for (final player in players) {
      final diceValue = startingDiceRolls[player.id]!;
      diceGroups.putIfAbsent(diceValue, () => []).add(player);
    }

    // Check if there are any ties (multiple players with same dice value)
    final tiedGroups =
        diceGroups.entries.where((e) => e.value.length > 1).toList();

    if (tiedGroups.isEmpty) {
      // No ties, sort players and start game
      _finalizeStartingOrder();
      return;
    }

    // There are ties, roll again for tied players
    setState(() {
      turnFeedback = 'Beraberlik! Tekrar zar atılıyor...';
      currentlyRollingPlayerId =
          null; // Reset rolling indicator during tie message
      // Clear rolls for tied players only
      for (final group in tiedGroups) {
        for (final player in group.value) {
          startingDiceRolls.remove(player.id);
        }
      }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      _rollStartingDice();
    });
  }

  void _finalizeStartingOrder() {
    // Sort players by dice value (highest first)
    players.sort((a, b) {
      final diceA = startingDiceRolls[a.id] ?? 0;
      final diceB = startingDiceRolls[b.id] ?? 0;
      return diceB.compareTo(diceA); // Descending order
    });

    setState(() {
      isDeterminingStartingOrder = false;
      gameState = GameState.waitingForDice;
      currentPlayerIndex = 0;
      canRollDice = true;
      turnFeedback = '${players[0].name} başlıyor';
      currentlyRollingPlayerId = null; // Clear rolling indicator
      startingDiceRolls.clear(); // Clear starting rolls
    });

    // Clear feedback after showing starting message
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        turnFeedback = null;
      });
    });
  }

  double _calculateStartingPanelHeight(int playerCount) {
    // Container padding: 10px top + 7px bottom = 17px (reduced bottom by 3px to prevent overflow)
    // Header row: ~24px (icon 16px + text 12px + spacing)
    // SizedBox between header and list: 8px
    // Each player item: 34px (container 28px with constraints + margin 6px)
    //   - Container has constraints: minHeight 28, maxHeight 28 (includes padding 8px)
    //   - Margin bottom: 6px (except last)
    // Last player has no bottom margin, so subtract 6px
    const double containerPaddingTop = 10.0;
    const double containerPaddingBottom =
        7.0; // Reduced by 3px to prevent overflow
    const double headerHeight = 24.0;
    const double headerSpacing = 8.0;
    const double playerItemHeight = 34.0; // container 28px + margin 6px
    const double lastItemMarginAdjustment = 6.0; // no margin on last item

    final double totalHeight = containerPaddingTop +
        containerPaddingBottom +
        headerHeight +
        headerSpacing +
        (playerItemHeight * playerCount) -
        lastItemMarginAdjustment;

    return totalHeight;
  }

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
    if (title == 'BAŞLANGIÇ') return TileType.start;
    if (title == 'İFLAS!') return TileType.bankrupt;
    if (title == 'BONUS') return TileType.bonus;
    if (title.contains('⭐') && title.contains('VER')) return TileType.penalty;
    if (title.contains('⭐') && title.contains('AL')) return TileType.bonus;
    if (title == 'BEN KİMİM?' ||
        title == 'TÜRK EDEBİYATINDA İLKLER' ||
        title == 'ESER-KARAKTER' ||
        title == 'EDEBİYAT AKIMLARI' ||
        title == 'EDEBİ SANATLAR') {
      return TileType.question;
    }
    if (title.contains('BONUS SORU')) return TileType.special;
    return TileType.special;
  }

  void _initializeQuestions() {
    questionPool.addAll([
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
        isBonus: true,
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
        difficulty: QuestionDifficulty.hard,
        isBonus: true,
      ),
    ]);
  }

  void _rollDice() {
    // Force release any stale locks at start
    _forceReleaseTurnLocks();

    // Block if game has ended
    if (isGameEnded) {
      _debugLog('[TURN_FLOW] BLOCKED: Game has ended');
      return;
    }

    // Only allow rolling when waiting for dice and canRollDice is true
    if (gameState != GameState.waitingForDice) {
      _debugLog('[TURN_FLOW] BLOCKED: Wrong game state: $gameState');
      return;
    }
    if (!canRollDice) {
      _debugLog('[TURN_FLOW] BLOCKED: canRollDice is false');
      return;
    }
    if (gameMode == null) {
      _debugLog('[TURN_FLOW] BLOCKED: Game not initialized');
      return; // Game not initialized
    }

    _debugLog('[TURN_FLOW] ========================================');
    _debugLog(
        '[TURN_FLOW] Dice rolled by: ${players[currentPlayerIndex].name}');
    _debugLog('[TURN_FLOW] canRollDice set to: false');

    // Step a) Player clicks dice
    // Step b) Dice animation - roll numbers before final value
    setState(() {
      canRollDice = false; // Disable dice immediately
    });
    _animateDiceRoll();
  }

  void _animateDiceRoll() {
    final finalValue = _random.nextInt(6) + 1;
    int rollCount = 0;
    const maxRolls = 8; // Number of rolling animations

    setState(() {
      isDiceRolling = true;
      canRollDice = false;
      turnFeedback = 'Zar atılıyor...';
    });

    void rollStep() {
      if (rollCount >= maxRolls) {
        // Animation complete, set final value
        setState(() {
          diceValue = finalValue;
          isDiceRolling = false;
          turnFeedback = 'Zar: $finalValue';
        });

        // Start movement after dice animation
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() {
            gameState = GameState.movingPawn;
          });
          _processTurn();
        });
        return;
      }

      // Show random dice value during animation
      final randomValue = _random.nextInt(6) + 1;
      setState(() {
        diceValue = randomValue;
        turnFeedback = 'Zar: $randomValue';
      });

      rollCount++;
      // Faster at start, slower near end
      final delay = rollCount < maxRolls / 2 ? 80 : 120;
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        rollStep();
      });
    }

    // Start rolling animation
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      rollStep();
    });
  }

  void _processTurn() {
    // Step c) Player position updates - step by step movement
    _movePlayerStepByStep();
  }

  void _movePlayerStepByStep() {
    final currentPlayer = players[currentPlayerIndex];
    final startPosition = currentPlayer.position;
    final targetPosition = (startPosition + diceValue) % 40;
    int currentStep = 0;

    setState(() {
      gameState = GameState.movingPawn;
      turnFeedback = '${currentPlayer.name} hareket ediyor...';
      highlightedTileIndex = null; // Clear any previous highlight
    });

    // Move one step at a time
    void moveStep() {
      if (currentStep >= diceValue) {
        // Movement complete - highlight landing tile
        setState(() {
          highlightedTileIndex = targetPosition;
          turnFeedback =
              '${currentPlayer.name} kare ${targetPosition + 1} üzerinde';
        });

        // Keep highlight for a moment, then process tile
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _processTileEffect(targetPosition);
        });
        return;
      }

      final nextPosition = (startPosition + currentStep + 1) % 40;
      setState(() {
        currentPlayer.position = nextPosition;
        highlightedTileIndex =
            nextPosition; // Highlight current tile during movement
        turnFeedback = '${currentPlayer.name} kare ${nextPosition + 1}';
      });

      currentStep++;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        moveStep();
      });
    }

    // Start movement
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      moveStep();
    });
  }

  int _getTargetPlayerIndex(String tileTitle, int currentIndex) {
    // Determine target player based on tile title
    if (tileTitle.contains('KARŞINDAKİ')) {
      // Opposite player (if 2 players: index 1->0, 0->1; if 4 players: 0->2, 1->3, etc.)
      return (currentIndex + players.length ~/ 2) % players.length;
    } else if (tileTitle.contains('SAĞINDAKİ')) {
      // Right player (next in order)
      return (currentIndex + 1) % players.length;
    } else if (tileTitle.contains('SOLUNDAKİ')) {
      // Left player (previous in order)
      return (currentIndex - 1 + players.length) % players.length;
    }
    // Default: no specific target
    return -1;
  }

  /// Centralized tile effect handler - ALL square effects are resolved here
  /// This is the single entry point when a player lands on a square
  void _processTileEffect(int position) {
    // GUARD: Prevent duplicate calls
    if (_isProcessingTileEffect) {
      _debugLog('[TURN_FLOW] BLOCKED: _processTileEffect already in progress');
      return;
    }

    // DEBUG ASSERTION (DEV ONLY)
    assert(
      !(isPlanningNextMove && isQuestionPanelVisible),
      "INVALID STATE: planning while question panel open",
    );

    // Force release any stale locks before starting (but preserve question panel if it's being shown)
    // This ensures we don't reset a question panel that's about to be shown
    final wasQuestionPanelVisible = isQuestionPanelVisible;
    _forceReleaseTurnLocks(preserveQuestionPanel: wasQuestionPanelVisible);

    final currentPlayer = players[currentPlayerIndex];
    final tile = tiles[position];
    final scoreBefore = currentPlayer.stars;

    // DEBUG LOG: Turn flow tracking
    _debugLog('[TURN_FLOW] ========================================');
    _debugLog('[TURN_FLOW] Player: ${currentPlayer.name}');
    _debugLog('[TURN_FLOW] Dice Value: $diceValue');
    _debugLog('[TURN_FLOW] Landing Position: $position');
    _debugLog('[TURN_FLOW] Tile Type: ${tile.type}');
    _debugLog('[TURN_FLOW] Tile Title: ${tile.title}');
    _debugLog('[TURN_FLOW] Score Before: $scoreBefore');

    _isProcessingTileEffect = true;
    _enterPlanningState();

    setState(() {
      gameState = GameState.resolvingTile;
      highlightedTileIndex =
          position; // Keep tile highlighted during effect processing
      turnFeedback = '${currentPlayer.name}: ${tile.title}';
    });

    // CENTRALIZED TILE EFFECT PROCESSING - Single switch-case for all tile types
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
          setState(() {
            currentPlayer.stars = (currentPlayer.stars - amount)
                .clamp(0, double.infinity)
                .toInt();
          });
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
        // BANKRUPTCY: Reset score to 0, show dedicated panel, NEVER trigger question popup
        // SIMPLE PENALTY ONLY - no elimination, no skipping turns
        final wasAlreadyBankrupt = currentPlayer.stars == 0;
        setState(() {
          // Only reset if player has stars (idempotency)
          if (currentPlayer.stars > 0) {
            currentPlayer.stars = 0;
          }
          // Only increment bankruptCount if this is a new bankruptcy
          if (!wasAlreadyBankrupt) {
            currentPlayer.bankruptCount++;
          }
        });
        if (wasAlreadyBankrupt) {
          effectMessage = 'İflas karesindesiniz (zaten iflas ettiniz).';
        } else {
          effectMessage = 'İflas ettiniz! Tüm yıldızlarınız sıfırlandı.';
        }
        hasEffect = true;
        shouldShowPanel = true; // Show dedicated bankruptcy panel
        _debugLog(
            '[TURN_FLOW] Bankruptcy processed - Was already bankrupt: $wasAlreadyBankrupt');
        break;

      case TileType.bonus:
        // Check if it's a "take stars from other player" bonus
        if (tile.title.contains('⭐') && tile.title.contains('AL')) {
          final amount = _parseStarAmount(tile.title);
          if (amount > 0) {
            final targetIndex =
                _getTargetPlayerIndex(tile.title, currentPlayerIndex);
            if (targetIndex >= 0 && targetIndex < players.length) {
              final targetPlayer = players[targetIndex];
              final transferAmount = amount.clamp(0, targetPlayer.stars);
              setState(() {
                targetPlayer.stars -= transferAmount;
                currentPlayer.stars += transferAmount;
              });
              effectMessage =
                  '${targetPlayer.name}\'den ⭐ $transferAmount aldınız (Toplam: ${currentPlayer.stars})';
            } else {
              // No specific target, just award
              setState(() {
                currentPlayer.stars += amount;
              });
              effectMessage =
                  '⭐ +$amount yıldız kazandınız (Toplam: ${currentPlayer.stars})';
            }
            hasEffect = true;
            shouldShowPanel = true;
          }
        } else {
          // Regular bonus - award stars (balanced to match win threshold)
          final bonusQuestions = questionPool.where((q) => q.isBonus).toList();
          if (bonusQuestions.isNotEmpty) {
            const bonusStars = 3; // Balanced reward (win threshold is 10)
            setState(() {
              currentPlayer.stars += bonusStars;
              currentPlayer.bonusQuestionsAnswered++;
            });
            effectMessage =
                'Bonus! ⭐ +$bonusStars yıldız kazandınız (Toplam: ${currentPlayer.stars})';
            hasEffect = true;
            shouldShowPanel = true;
          } else {
            effectMessage = 'Bonus karesi - soru yok';
            shouldShowPanel = true;
          }
        }
        break;

      case TileType.question:
        // QUESTION TILE: Show question panel
        // Turn MUST PAUSE until question is resolved
        if (questionPool.isNotEmpty) {
          final randomQuestion =
              questionPool[_random.nextInt(questionPool.length)];
          setState(() {
            isQuestionPanelVisible = true;
            currentQuestion = randomQuestion;
            questionFeedback = null;
            canRollDice = false; // Disable dice while question is active
            // DO NOT reset processing flags - question panel will handle turn end
          });
          _debugLog(
              '[QUESTION] Showing question: ${randomQuestion.questionText}');
          // DO NOT call _forceReleaseTurnLocks() here - it would reset isQuestionPanelVisible
          // DO NOT call _endTurn() automatically - only answer button callback can do that
          // IMMEDIATELY EXIT - question panel handles the rest
          return; // EXIT IMMEDIATELY - question panel handles the rest
        } else {
          // No questions available - fallback message
          effectMessage = 'Soru karesi - soru bulunamadı';
          hasEffect = true;
          shouldShowPanel = true;
        }
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
              setState(() {
                currentPlayer.stars -= transferAmount;
                targetPlayer.stars += transferAmount;
              });
              effectMessage =
                  '${targetPlayer.name}\'e ⭐ $transferAmount verdiniz (Kalan: ${currentPlayer.stars})';
            } else {
              // No specific target, just deduct
              setState(() {
                currentPlayer.stars = (currentPlayer.stars - amount)
                    .clamp(0, double.infinity)
                    .toInt();
              });
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
            setState(() {
              // Give stars to all other players
              for (var player in players) {
                if (player.id != currentPlayer.id) {
                  player.stars += perPlayer;
                }
              }
              currentPlayer.stars -= actualCost;
            });
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

    // Update feedback with effect message
    setState(() {
      turnFeedback = effectMessage;
    });

    // Clear tile highlight after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        highlightedTileIndex = null;
      });
    });

    // DEBUG LOG: Score after tile effect
    final scoreAfter = currentPlayer.stars;
    _debugLog('[TURN_FLOW] Score After: $scoreAfter');
    _debugLog('[TURN_FLOW] Effect Message: $effectMessage');
    _debugLog('[TURN_FLOW] Should Show Panel: $shouldShowPanel');

    // Show panel for tiles that require user acknowledgement
    if (shouldShowPanel) {
      // GUARD: Prevent duplicate panel if already visible
      if (isTileEffectPanelVisible) {
        _debugLog('[TURN_FLOW] WARNING: Panel already visible, skipping');
        _forceReleaseTurnLocks();
        return;
      }

      setState(() {
        isTileEffectPanelVisible = true;
        tileEffectTitle = _getTileTypeTitle(tile.type);
        tileEffectMessage = effectMessage;
      });
      _debugLog('[TURN_FLOW] Panel shown, waiting for user acknowledgement');
      // Guard will be reset when panel is closed
      // Planning state remains active until panel is closed
    } else {
      // For tiles without effects, end turn normally
      _exitPlanningState();
      _isProcessingTileEffect = false; // Reset guard before ending turn
      final delay = hasEffect ? 1500 : 800;
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        _endTurn();
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

  /// Handle question answer selection
  void _handleQuestionAnswer(int selectedIndex) {
    if (currentQuestion == null) {
      _debugLog(
          '[QUESTION] ERROR: _handleQuestionAnswer called but currentQuestion is null');
      return;
    }

    final currentPlayer = players[currentPlayerIndex];
    final isCorrect = selectedIndex == currentQuestion!.correctIndex;

    _debugLog('[QUESTION] ========================================');
    _debugLog('[QUESTION] Answer selected: index $selectedIndex');
    _debugLog('[QUESTION] Correct index: ${currentQuestion!.correctIndex}');
    _debugLog('[QUESTION] Is correct: $isCorrect');
    _debugLog('[QUESTION] Player: ${currentPlayer.name}');
    _debugLog('[QUESTION] Stars before: ${currentPlayer.stars}');

    // STEP 1: Set feedback state first - do NOT close panel instantly
    setState(() {
      if (isCorrect) {
        // Correct answer: +1 star (STRICT: exactly 1 star, no more)
        final starsBefore = currentPlayer.stars;
        currentPlayer.stars = starsBefore + 1; // Explicit: add exactly 1
        questionFeedback = 'Doğru! +1 yıldız';
        _debugLog(
            '[QUESTION] Correct answer! Player ${currentPlayer.name} gained 1 star');
        _debugLog(
            '[QUESTION] Stars before: $starsBefore, Stars after: ${currentPlayer.stars}');
        // CRITICAL: Verify star count is correct
        assert(currentPlayer.stars == starsBefore + 1,
            'Star count mismatch: expected ${starsBefore + 1}, got ${currentPlayer.stars}');
      } else {
        // Wrong answer: No penalty (0 stars awarded)
        questionFeedback = 'Yanlış cevap';
        _debugLog(
            '[QUESTION] Wrong answer. Correct was: ${currentQuestion!.options[currentQuestion!.correctIndex]}');
        _debugLog('[QUESTION] Stars remain: ${currentPlayer.stars}');
      }
    });

    _debugLog('[QUESTION] Feedback set to: $questionFeedback');
    _debugLog('[QUESTION] Waiting 1 second before closing panel...');
    _debugLog('[QUESTION] ========================================');

    // STEP 2: Add delay so user can see feedback, then close and end turn
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      // STEP 3: Mandatory state release before ending turn
      // Cancel planning timer first
      _planningStateTimer?.cancel();
      _planningStateTimer = null;

      // Explicitly reset guard to ensure _endTurn can complete
      _isProcessingTileEffect = false;
      isPlanningNextMove = false;

      // Reset all state flags and UI visibility in a single setState
      setState(() {
        // Reset processing flags (explicitly set to false)
        _isProcessingTileEffect = false;
        isPlanningNextMove = false;

        // Hide panel and clear content
        isQuestionPanelVisible = false;
        currentQuestion = null;
        questionFeedback = null;

        // Clear any lingering feedback
        turnFeedback = null;
      });

      // STEP 4: End turn - this will set canRollDice = true for next player
      _endTurn();
    });
  }

  /// Close question panel and end turn
  /// NOTE: This may be called manually via "Devam" button, but auto-close after answer
  /// also handles closing. This method is safe to call multiple times (guarded).
  void _closeQuestionPanel() {
    // Guard: Prevent double-closing if panel is already closed or closing
    if (!isQuestionPanelVisible) {
      return;
    }

    _debugLog('[QUESTION] ========================================');
    _debugLog('[QUESTION] Question panel closed by user (Devam button)');
    _debugLog(
        '[QUESTION] Before reset - isQuestionPanelVisible: $isQuestionPanelVisible');
    _debugLog(
        '[QUESTION] Before reset - _isProcessingTileEffect: $_isProcessingTileEffect');
    _debugLog(
        '[QUESTION] Before reset - isPlanningNextMove: $isPlanningNextMove');
    _debugLog('[QUESTION] Before reset - canRollDice: $canRollDice');
    _debugLog('[QUESTION] Before reset - gameState: $gameState');
    _debugLog('[QUESTION] Before reset - questionFeedback: $questionFeedback');

    // Cancel planning timer first
    _planningStateTimer?.cancel();
    _planningStateTimer = null;

    // Reset all state flags and UI visibility in a single setState
    setState(() {
      // Reset processing flags
      _isProcessingTileEffect = false;
      isPlanningNextMove = false;

      // Hide panel and clear content
      isQuestionPanelVisible = false;
      currentQuestion = null;
      questionFeedback = null;

      // Clear any lingering feedback that might block UI
      turnFeedback = null;

      // Re-enable dice (though turn will end, this ensures state is correct)
      canRollDice = true;
    });

    _debugLog('[QUESTION] State reset complete - calling _endTurn()');
    _debugLog('[QUESTION] ========================================');

    // End turn after closing panel - this will set canRollDice = true for next player
    _endTurn();
  }

  void _closeTileEffectPanel() {
    _debugLog('[TURN_FLOW] ========================================');
    _debugLog('[TURN_FLOW] Tile effect panel closed by user');

    // Force release all locks first to ensure clean state
    _forceReleaseTurnLocks();

    // Reset all state flags and UI visibility in a single setState
    setState(() {
      // Hide panel and clear content
      isTileEffectPanelVisible = false;
      tileEffectTitle = null;
      tileEffectMessage = null;

      // Clear any lingering feedback that might block UI
      turnFeedback = null;
    });

    _debugLog('[TURN_FLOW] State reset complete - calling _endTurn()');
    _debugLog('[TURN_FLOW] ========================================');

    // End turn after closing panel - this will set canRollDice = true for next player
    _endTurn();
  }

  // Developer mode: Force move a player
  void _developerForceMove() {
    if (developerSelectedPlayerIndex < 0 ||
        developerSelectedPlayerIndex >= players.length) {
      _debugLog(
          '[DEV_MODE] Invalid player index: $developerSelectedPlayerIndex');
      return;
    }

    // GUARD: Prevent force move if tile effect is being processed
    if (_isProcessingTileEffect) {
      _debugLog('[DEV_MODE] BLOCKED: Tile effect already in progress');
      return;
    }

    final player = players[developerSelectedPlayerIndex];
    final currentPos = player.position;
    final moveAmount = developerMoveTiles.clamp(1, 39);
    final newPosition = (currentPos + moveAmount) % 40;

    _debugLog(
        '[DEV_MODE] Force moving ${player.name} from $currentPos to $newPosition (+$moveAmount)');

    // Update player position
    setState(() {
      player.position = newPosition;
      highlightedTileIndex = newPosition;
    });

    // Process tile effect using existing logic
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _processTileEffect(newPosition);
    });
  }

  int _parseStarAmount(String text) {
    final regex = RegExp(r'⭐(\d+)');
    final match = regex.firstMatch(text);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0;
  }

  void _endTurn() {
    // Force release all locks at start of turn end
    _forceReleaseTurnLocks();

    // Step e) Turn ENDS
    _debugLog('[TURN_FLOW] ========================================');
    _debugLog(
        '[TURN_FLOW] Ending turn for: ${players[currentPlayerIndex].name}');
    _debugLog('[TURN_FLOW] Current Player Index: $currentPlayerIndex');
    _debugLog('[TURN_FLOW] Current Turn: $currentTurn');

    // Check for win conditions FIRST (before checking game mode end conditions)
    // CRITICAL: Only check win conditions if game is not already ended
    if (!isGameEnded) {
      final currentPlayer = players[currentPlayerIndex];
      _debugLog(
          '[WIN_CHECK] Checking win conditions for ${currentPlayer.name} (${currentPlayer.stars} stars)');

      Player? potentialWinner = _checkWinConditions(currentPlayer);

      if (potentialWinner != null) {
        _debugLog(
            '[GAME_RULES] Win condition met! Winner: ${potentialWinner.name} with ${potentialWinner.stars} stars');
        _endGame(potentialWinner);
        return;
      } else {
        _debugLog(
            '[WIN_CHECK] No winner yet - ${currentPlayer.name} has ${currentPlayer.stars} stars (threshold: ${GameConfig.winStarsThreshold})');
      }
    }

    // Check for game end conditions (turn-based or question-based)
    if (gameMode == GameMode.turnBased) {
      if (currentPlayerIndex == players.length - 1) {
        currentTurn++;
        _debugLog('[TURN_FLOW] Turn incremented to: $currentTurn');
        if (currentTurn > maxTurns!) {
          _debugLog('[TURN_FLOW] Max turns reached, ending game');
          _checkGameEnd();
          return;
        }
      }
    } else if (gameMode == GameMode.questionUntilEnd) {
      final remainingQuestions = questionPool.length;
      if (remainingQuestions == 0) {
        _debugLog('[TURN_FLOW] No questions remaining, ending game');
        _checkGameEnd();
        return;
      }
    }

    // Step f) currentPlayerIndex moves to next player
    // Step g) canRollDice = true again
    final nextPlayerIndex = (currentPlayerIndex + 1) % players.length;
    final nextPlayer = players[nextPlayerIndex];

    _debugLog(
        '[TURN_FLOW] Next Player: ${nextPlayer.name} (Index: $nextPlayerIndex)');
    _debugLog('[TURN_FLOW] canRollDice will be set to: true');

    // Show turn transition feedback
    setState(() {
      currentPlayerIndex = nextPlayerIndex;
      gameState = GameState.waitingForDice;
      diceValue = 0;
      canRollDice = true; // Re-enable dice for next player
      turnFeedback = '${nextPlayer.name} sırası'; // Show next player's turn
      highlightedTileIndex = null; // Clear any tile highlight
      isDiceRolling = false; // Ensure dice animation is stopped
      _isProcessingTileEffect = false; // Reset guard for next turn
      isPlanningNextMove = false; // Exit planning state
      turnTransitionMessage =
          'Sıra: ${nextPlayer.name}'; // Brief transition message
    });

    _debugLog('[TURN_FLOW] Turn ended successfully');
    _debugLog('[TURN_FLOW] ========================================');

    // Clear transition message after 400ms (non-blocking)
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        turnTransitionMessage = null;
      });
    });

    // Clear feedback after a short delay to show next player message
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        turnFeedback = null;
      });
    });
  }

  /// Check win conditions: stars threshold OR all other players bankrupt
  /// IMPORTANT: Only returns a winner if conditions are STRICTLY met
  Player? _checkWinConditions(Player player) {
    // CRITICAL: Ensure win threshold is exactly 10 and player has AT LEAST 10 stars
    if (player.stars < GameConfig.winStarsThreshold) {
      // Player has not reached threshold - no winner
      return null;
    }

    // Win condition 1: Player reached stars threshold (STRICT CHECK: >= 10)
    if (player.stars >= GameConfig.winStarsThreshold) {
      _debugLog(
          '[WIN_CHECK] Player ${player.name} has ${player.stars} stars (threshold: ${GameConfig.winStarsThreshold})');
      return player;
    }

    // Win condition 2: All other players are bankrupt (0 stars)
    // Only check this if player has at least some stars (prevents early game wins)
    if (player.stars > 0) {
      final otherPlayers = players.where((p) => p.id != player.id).toList();
      if (otherPlayers.isEmpty) {
        return null; // Shouldn't happen - at least 2 players required
      }

      // Check if all other players have 0 stars (bankrupt)
      final allOthersBankrupt = otherPlayers.every((p) => p.stars == 0);
      if (allOthersBankrupt) {
        _debugLog(
            '[WIN_CHECK] Player ${player.name} wins - all others bankrupt');
        return player;
      }
    }

    return null; // No winner yet
  }

  /// End the game with a winner
  /// CRITICAL: Only call this when win conditions are STRICTLY met
  void _endGame(Player winningPlayer) {
    // CRITICAL: Double-check win conditions before ending game
    if (winningPlayer.stars < GameConfig.winStarsThreshold) {
      _debugLog(
          '[GAME_RULES] ERROR: Attempted to end game but player ${winningPlayer.name} only has ${winningPlayer.stars} stars (threshold: ${GameConfig.winStarsThreshold})');
      return; // Do not end game if threshold not met
    }

    // Force release all locks before showing winner panel
    _forceReleaseTurnLocks();
    setState(() {
      isGameEnded = true;
      winner = winningPlayer;
      canRollDice = false; // Permanently disable dice rolling
      gameState = GameState.gameOver;
    });
    _debugLog(
        '[GAME_RULES] Game ended. Winner: ${winningPlayer.name} with ${winningPlayer.stars} stars');
  }

  /// Restart the game - reset all players and game state
  void _restartGame() {
    _debugLog('[GAME_RULES] Restarting game...');

    // Force release all locks first
    _forceReleaseTurnLocks();

    // Reset all game state
    setState(() {
      // Reset all players
      for (var player in players) {
        player.stars = 0;
        player.position = 0;
        player.bankruptCount = 0;
        player.bonusQuestionsAnswered = 0;
      }

      // Reset game state
      currentPlayerIndex = 0;
      currentTurn = 1;
      gameState = GameState.waitingForDice;
      diceValue = 0;
      canRollDice = true;

      // Hide all panels
      isGameEnded = false;
      winner = null;
      isQuestionPanelVisible = false;
      isTileEffectPanelVisible = false;
      currentQuestion = null;
      questionFeedback = null;
      tileEffectTitle = null;
      tileEffectMessage = null;

      // Clear feedback
      turnFeedback = null;
      turnTransitionMessage = null;
      highlightedTileIndex = null;
      isDiceRolling = false;

      // Reset processing flags
      _isProcessingTileEffect = false;
      isPlanningNextMove = false;

      // Reset starting order state
      isDeterminingStartingOrder = true;
      startingDiceRolls.clear();
      currentlyRollingPlayerId = null;
    });

    _debugLog(
        '[GAME_RULES] Game reset complete, determining starting order...');

    // Start determining player order again
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _determineStartingOrder();
      }
    });
  }

  void _checkGameEnd() {
    setState(() {
      gameState = GameState.gameOver;
    });

    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) {
      if (b.stars != a.stars) return b.stars.compareTo(a.stars);
      if (b.bonusQuestionsAnswered != a.bonusQuestionsAnswered) {
        return b.bonusQuestionsAnswered.compareTo(a.bonusQuestionsAnswered);
      }
      return a.bankruptCount.compareTo(b.bankruptCount);
    });

    final winner = sortedPlayers[0];
    final topScore = winner.stars;
    final topBonus = winner.bonusQuestionsAnswered;
    final topBankrupt = winner.bankruptCount;

    tiedPlayers = sortedPlayers
        .where((p) =>
            p.stars == topScore &&
            p.bonusQuestionsAnswered == topBonus &&
            p.bankruptCount == topBankrupt)
        .toList();

    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      if (tiedPlayers.length > 1) {
        _enterTieBreakMode();
      } else {
        _showWinnerDialog(winner);
      }
    });
  }

  void _enterTieBreakMode() {
    setState(() {
      gameState = GameState.tieBreak;
      tieBreakQuestionIndex = 0;
      tieBreakAnswers.clear();
    });
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _showTieBreakDialog();
      }
    });
  }

  void _showTieBreakDialog() {
    if (!mounted) return;
    _showModal(
      AlertDialog(
        title: const Text('Beraberlik Modu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Beraberlik durumu! Moderatör özel sorular soracak.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text('Berabere Kalan Oyuncular:'),
            ...tiedPlayers.map((p) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${p.name} (⭐ ${p.stars})'),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            const Text(
              'Moderatör, tüm berabere kalan oyunculara aynı soruyu soracak. Doğru cevap veren oyuncu kazanır.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _hideModal();
              Future.delayed(Duration.zero, () {
                if (mounted) {
                  _showTieBreakQuestionDialog();
                }
              });
            },
            child: const Text('SORU SOR'),
          ),
        ],
      ),
    );
  }

  void _showTieBreakQuestionDialog() {
    setState(() {
      tieBreakAnswers.clear();
    });
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      _showModal(
        _TieBreakQuestionDialog(
          tiedPlayers: tiedPlayers,
          tieBreakAnswers: tieBreakAnswers,
          onAnswer: (playerId, isCorrect) {
            setState(() {
              tieBreakAnswers[playerId] = isCorrect;
            });
          },
          onEvaluate: () {
            _hideModal();
            Future.delayed(Duration.zero, () => _evaluateTieBreak());
          },
        ),
      );
    });
  }

  void _evaluateTieBreak() {
    if (tieBreakAnswers.length < tiedPlayers.length) {
      return;
    }

    final correctPlayers =
        tiedPlayers.where((p) => tieBreakAnswers[p.id] == true).toList();
    final incorrectPlayers =
        tiedPlayers.where((p) => tieBreakAnswers[p.id] == false).toList();

    if (correctPlayers.length == 1 && incorrectPlayers.isNotEmpty) {
      setState(() {
        gameState = GameState.gameOver;
      });
      Future.delayed(Duration.zero, () {
        if (mounted) {
          _showWinnerDialog(correctPlayers[0]);
        }
      });
      return;
    }

    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      _showModal(
        AlertDialog(
          title: const Text('Beraberlik Devam Ediyor'),
          content: Text(
            correctPlayers.isEmpty
                ? 'Tüm oyuncular yanlış cevap verdiler. Başka bir soru sorun.'
                : 'Tüm oyuncular doğru cevap verdiler. Başka bir soru sorun.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _hideModal();
                Future.delayed(Duration.zero, () {
                  if (mounted) {
                    _showTieBreakQuestionDialog();
                  }
                });
              },
              child: const Text('YENİ SORU'),
            ),
          ],
        ),
      );
    });
  }

  void _showWinnerDialog(Player winner) {
    if (!mounted) return;
    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) {
      if (b.stars != a.stars) return b.stars.compareTo(a.stars);
      if (b.bonusQuestionsAnswered != a.bonusQuestionsAnswered) {
        return b.bonusQuestionsAnswered.compareTo(a.bonusQuestionsAnswered);
      }
      return a.bankruptCount.compareTo(b.bankruptCount);
    });

    _showModal(
      AlertDialog(
        title: const Text('Oyun Bitti!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: winner.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: winner.color, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      'Kazanan: ${winner.name}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('⭐ ${winner.stars}'),
                    Text('Bonus Sorular: ${winner.bonusQuestionsAnswered}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Sıralama:'),
              ...sortedPlayers.map((p) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: p.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${p.name}:')),
                        Text('⭐ ${p.stars}'),
                        const SizedBox(width: 8),
                        Text('Bonus: ${p.bonusQuestionsAnswered}'),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _hideModal();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const PlayerSetupScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text('YENİ OYUN'),
          ),
        ],
      ),
    );
  }

  void _manualEndGame() {
    if (gameState == GameState.gameOver || gameState == GameState.tieBreak) {
      return;
    }
    _checkGameEnd();
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF1a1a2e),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Calculate center positions for buttons
    final diceButtonWidth = 120.0;
    final diceButtonHeight = 50.0;
    final diceButtonLeft = (screenWidth - diceButtonWidth) / 2;
    final diceButtonTop = (screenHeight - diceButtonHeight) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final shortestSide =
                    constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight;
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: BoardPainter(
                    tiles: tiles,
                    players: players,
                    boardSize: shortestSide * 0.9,
                    highlightedTileIndex: highlightedTileIndex,
                    currentPlayerIndex: currentPlayerIndex,
                  ),
                );
              },
            ),
            // Starting order panel - shows dice rolls during initial sequence
            if (isDeterminingStartingOrder)
              Positioned(
                left: 16,
                top: 16,
                width: 220,
                height: _calculateStartingPanelHeight(players.length),
                child: Container(
                  padding: const EdgeInsets.only(
                    top: 10,
                    left: 10,
                    right: 10,
                    bottom: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.casino,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Başlangıç Sırası',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...players.asMap().entries.map((entry) {
                        final index = entry.key;
                        final player = entry.value;
                        final isLast = index == players.length - 1;
                        final diceValue = startingDiceRolls[player.id];
                        final isRolling = currentlyRollingPlayerId == player.id;
                        final hasRolled = diceValue != null;

                        return Container(
                          margin: EdgeInsets.only(bottom: isLast ? 0 : 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          constraints: const BoxConstraints(
                            minHeight: 28,
                            maxHeight: 28,
                          ),
                          decoration: BoxDecoration(
                            color: isRolling
                                ? player.color.withValues(alpha: 0.4)
                                : hasRolled
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isRolling
                                  ? player.color
                                  : Colors.white.withValues(alpha: 0.2),
                              width: isRolling ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                player.pawnIcon,
                                color: player.color,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  player.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: isRolling
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (isRolling)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      player.color,
                                    ),
                                  ),
                                )
                              else if (hasRolled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: player.color.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$diceValue',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.hourglass_empty,
                                  color: Colors.grey.shade400,
                                  size: 14,
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            // Tile effect panel - shows tile effects safely
            if (isTileEffectPanelVisible &&
                tileEffectTitle != null &&
                tileEffectMessage != null)
              TileEffectPanel(
                title: tileEffectTitle!,
                message: tileEffectMessage!,
                onClose: _closeTileEffectPanel,
              ),
            // Question panel - shown when landing on question tile
            if (isQuestionPanelVisible && currentQuestion != null)
              QuestionPanel(
                question: currentQuestion!,
                feedback: questionFeedback,
                onAnswer: _handleQuestionAnswer,
                onClose: _closeQuestionPanel,
              ),
            // Turn transition feedback - brief non-blocking message
            if (turnTransitionMessage != null)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.1,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: turnTransitionMessage != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: players[currentPlayerIndex]
                            .color
                            .withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        turnTransitionMessage!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Winner panel - shown when game ends
            if (isGameEnded && winner != null)
              Positioned.fill(
                child: SizedBox.expand(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Center(
                      child: Material(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 400,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: winner!.color,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: winner!.color.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                size: 64,
                                color: winner!.color,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${winner!.name} kazandı!',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: winner!.color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '⭐ ${winner!.stars} yıldız',
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _restartGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Text(
                                    'Restart Game',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Developer panel - only visible in developer mode
            if (isDeveloperMode)
              Positioned(
                top: 16,
                left: 16,
                width: 220,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bug_report,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Developer Mode ON',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Player:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: developerSelectedPlayerIndex > 0
                                  ? () {
                                      setState(() {
                                        developerSelectedPlayerIndex--;
                                      });
                                    }
                                  : null,
                              icon: Icon(Icons.chevron_left, size: 18),
                              color: Colors.white,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  players[developerSelectedPlayerIndex].name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: developerSelectedPlayerIndex <
                                      players.length - 1
                                  ? () {
                                      setState(() {
                                        developerSelectedPlayerIndex++;
                                      });
                                    }
                                  : null,
                              icon: Icon(Icons.chevron_right, size: 18),
                              color: Colors.white,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Move tiles:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          IconButton(
                            onPressed: developerMoveTiles > 1
                                ? () {
                                    setState(() {
                                      developerMoveTiles--;
                                    });
                                  }
                                : null,
                            icon: Icon(Icons.remove, size: 16),
                            color: Colors.white,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '$developerMoveTiles',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: developerMoveTiles < 39
                                ? () {
                                    setState(() {
                                      developerMoveTiles++;
                                    });
                                  }
                                : null,
                            icon: Icon(Icons.add, size: 16),
                            color: Colors.white,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: _developerForceMove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            'Force Move',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Turn indicator - shows current player clearly
            if (!isDeterminingStartingOrder &&
                !isTileEffectPanelVisible &&
                !isQuestionPanelVisible &&
                currentPlayerIndex < players.length)
              Positioned(
                top: 16,
                left: isDeveloperMode
                    ? 240
                    : 16, // Move right when dev panel is visible
                width: 200,
                height: 80,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: players[currentPlayerIndex]
                        .color
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: players[currentPlayerIndex].color,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: players[currentPlayerIndex]
                            .color
                            .withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SIRA',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            players[currentPlayerIndex].pawnIcon,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              players[currentPlayerIndex].name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 16,
              right: 16,
              width: 250,
              height: 400,
              child: Scoreboard(
                players: players,
                gameMode: gameMode,
                currentTurn: currentTurn,
                maxTurns: maxTurns,
                winner: winner,
                isGameEnded: isGameEnded,
              ),
            ),
            // Dice button - explicitly positioned with fixed size
            // Only show and enable when waiting for dice and canRollDice is true
            // Hide when any panel is visible
            if (gameState == GameState.waitingForDice &&
                !isQuestionPanelVisible &&
                !isTileEffectPanelVisible)
              Positioned(
                left: diceButtonLeft,
                top: diceButtonTop,
                width: diceButtonWidth,
                height: diceButtonHeight,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: canRollDice && !isDiceRolling
                        ? [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: (!isDeterminingStartingOrder &&
                            !isTileEffectPanelVisible &&
                            !isQuestionPanelVisible &&
                            gameState == GameState.waitingForDice &&
                            canRollDice)
                        ? _rollDice
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDiceRolling
                          ? Colors.orange.shade700
                          : canRollDice
                              ? Colors.orange
                              : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isDiceRolling ? '...' : 'ZAR',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            // Show turn status text and feedback
            if ((isDeterminingStartingOrder ||
                    (gameState != GameState.waitingForDice &&
                        gameState != GameState.gameOver)) &&
                turnFeedback != null)
              Positioned(
                left: (screenWidth - 300) / 2,
                top: diceButtonTop - 50,
                width: 300,
                height: 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      turnFeedback!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            // Show turn status text (when no feedback but not waiting)
            if (!isDeterminingStartingOrder &&
                gameState != GameState.waitingForDice &&
                gameState != GameState.gameOver &&
                turnFeedback == null)
              Positioned(
                left: (screenWidth - 300) / 2,
                top: diceButtonTop - 50,
                width: 300,
                height: 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gameState == GameState.movingPawn
                          ? 'Hareket ediliyor...'
                          : gameState == GameState.resolvingTile
                              ? 'Kare işleniyor...'
                              : 'Sıra işleniyor...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            // Dice value display - explicitly positioned with animation
            if (diceValue > 0 || isDiceRolling)
              Positioned(
                left: (screenWidth - 80) / 2,
                top: diceButtonTop + diceButtonHeight + 20,
                width: 80,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDiceRolling
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isDiceRolling
                        ? Border.all(color: Colors.orange, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$diceValue',
                      style: TextStyle(
                        fontSize: isDiceRolling ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: isDiceRolling ? Colors.orange : Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            // End game button - explicitly positioned with fixed size
            if (gameState == GameState.waitingForDice ||
                gameState == GameState.endTurn)
              Positioned(
                left: (screenWidth - 150) / 2,
                top: diceButtonTop + diceButtonHeight + 80,
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: _manualEndGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('OYUNU BİTİR'),
                ),
              ),
            // MODAL DISABLED - Stabilization step
            // if (isModalVisible && activeModalContent != null)
            //   Positioned.fill(...)
          ],
        ),
      ),
    );
  }
}

class _BonusQuestionDialog extends StatefulWidget {
  final Question question;
  final Function(bool) onAnswer;
  final VoidCallback onClose;

  const _BonusQuestionDialog({
    required this.question,
    required this.onAnswer,
    required this.onClose,
  });

  @override
  State<_BonusQuestionDialog> createState() => _BonusQuestionDialogState();
}

class _BonusQuestionDialogState extends State<_BonusQuestionDialog> {
  int? selectedIndex;
  bool answered = false;

  void _selectOption(int index) {
    if (answered) return;
    final isCorrect = index == widget.question.correctIndex;
    setState(() {
      selectedIndex = index;
      answered = true;
    });
    widget.onAnswer(isCorrect);
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = selectedIndex == widget.question.correctIndex;

    return AlertDialog(
      title: const Text('BONUS SORU'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.question.questionText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...widget.question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = selectedIndex == index;
              final isCorrectOption = index == widget.question.correctIndex;

              Color? buttonColor;
              if (answered) {
                if (isCorrectOption) {
                  buttonColor = Colors.green.shade100;
                } else if (isSelected && !isCorrectOption) {
                  buttonColor = Colors.red.shade100;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  onPressed: answered ? null : () => _selectOption(index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: Text(option),
                ),
              );
            }),
            if (answered) ...[
              const SizedBox(height: 16),
              Text(
                isCorrect ? 'DOĞRU!' : 'YANLIŞ!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isCorrect ? '⭐ +200 yıldız kazandınız!' : 'Ceza yok.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (answered)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onClose();
            },
            child: const Text('DEVAM'),
          ),
      ],
    );
  }
}

class _TieBreakQuestionDialog extends StatefulWidget {
  final List<Player> tiedPlayers;
  final Map<int, bool?> tieBreakAnswers;
  final Function(int playerId, bool isCorrect) onAnswer;
  final VoidCallback onEvaluate;

  const _TieBreakQuestionDialog({
    required this.tiedPlayers,
    required this.tieBreakAnswers,
    required this.onAnswer,
    required this.onEvaluate,
  });

  @override
  State<_TieBreakQuestionDialog> createState() =>
      _TieBreakQuestionDialogState();
}

class _TieBreakQuestionDialogState extends State<_TieBreakQuestionDialog> {
  @override
  Widget build(BuildContext context) {
    final allAnswered = widget.tiedPlayers.every(
      (player) => widget.tieBreakAnswers.containsKey(player.id),
    );

    return AlertDialog(
      title: const Text('Beraberlik Sorusu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Moderatör, tüm berabere kalan oyunculara aynı soruyu sorun.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...widget.tiedPlayers.map((player) {
              final hasAnswered = widget.tieBreakAnswers.containsKey(player.id);
              final isCorrect = widget.tieBreakAnswers[player.id];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasAnswered
                        ? (isCorrect == true
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2))
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasAnswered
                          ? (isCorrect == true ? Colors.green : Colors.red)
                          : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: player.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (hasAnswered)
                              Text(
                                isCorrect == true ? 'DOĞRU' : 'YANLIŞ',
                                style: TextStyle(
                                  color: isCorrect == true
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!hasAnswered) ...[
                        ElevatedButton(
                          onPressed: () {
                            widget.onAnswer(player.id, true);
                            if (widget.tiedPlayers.every((p) =>
                                widget.tieBreakAnswers.containsKey(p.id))) {
                              Future.delayed(const Duration(milliseconds: 500),
                                  () {
                                widget.onEvaluate();
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('DOĞRU'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            widget.onAnswer(player.id, false);
                            if (widget.tiedPlayers.every((p) =>
                                widget.tieBreakAnswers.containsKey(p.id))) {
                              Future.delayed(const Duration(milliseconds: 500),
                                  () {
                                widget.onEvaluate();
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('YANLIŞ'),
                        ),
                      ] else
                        Icon(
                          isCorrect == true ? Icons.check_circle : Icons.cancel,
                          color: isCorrect == true ? Colors.green : Colors.red,
                        ),
                    ],
                  ),
                ),
              );
            }),
            if (allAnswered)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Tüm oyuncular cevapladı. Değerlendiriliyor...',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
