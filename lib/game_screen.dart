import 'package:flutter/material.dart';
import 'game_controller.dart';
import 'board_painter.dart';
import 'scoreboard_widget.dart';
import 'game_panels.dart';

/// Clean StatelessWidget that listens to GameController
class GameScreen extends StatelessWidget {
  final GameController controller;

  const GameScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Use AnimatedBuilder to listen to controller changes
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return _buildGameUI(context);
      },
    );
  }

  Widget _buildGameUI(BuildContext context) {
    if (controller.players.isEmpty) {
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
    const diceButtonWidth = 120.0;
    const diceButtonHeight = 50.0;
    final diceButtonLeft = (screenWidth - diceButtonWidth) / 2;
    final diceButtonTop = (screenHeight - diceButtonHeight) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Stack(
          children: [
            // Game board
            LayoutBuilder(
              builder: (context, constraints) {
                final shortestSide =
                    constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight;
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: BoardPainter(
                    tiles: controller.tiles,
                    players: controller.players,
                    boardSize: shortestSide * 0.9,
                    highlightedTileIndex: controller.highlightedTileIndex,
                    currentPlayerIndex: controller.currentPlayerIndex,
                  ),
                );
              },
            ),
            // Starting order panel
            if (controller.isDeterminingStartingOrder)
              _buildStartingOrderPanel(),
            // Tile effect panel
            if (controller.isTileEffectPanelVisible &&
                controller.tileEffectTitle != null &&
                controller.tileEffectMessage != null)
              TileEffectPanel(
                title: controller.tileEffectTitle!,
                message: controller.tileEffectMessage!,
                onClose: controller.closeTileEffectPanel,
              ),
            // Question panel
            if (controller.isQuestionPanelVisible &&
                controller.currentQuestion != null)
              QuestionPanel(
                question: controller.currentQuestion!,
                feedback: controller.questionFeedback,
                onAnswer: controller.handleQuestionAnswer,
                onClose: controller.closeQuestionPanel,
              ),
            // Turn transition feedback
            if (controller.turnTransitionMessage != null)
              _buildTurnTransitionMessage(context),
            // Winner panel
            if (controller.isGameEnded && controller.winner != null)
              _buildWinnerPanel(),
            // Developer panel
            if (controller.isDeveloperMode) _buildDeveloperPanel(context),
            // Turn indicator
            if (!controller.isDeterminingStartingOrder &&
                !controller.isTileEffectPanelVisible &&
                !controller.isQuestionPanelVisible &&
                controller.currentPlayerIndex < controller.players.length)
              _buildTurnIndicator(context),
            // Scoreboard (UPDATED with Sudden Death support)
            Positioned(
              top: 16,
              right: 16,
              width: 250,
              height: 400,
              child: Scoreboard(
                players: controller.players,
                gameMode: controller.gameMode,
                currentTurn: controller.currentTurn,
                maxTurns: controller.maxTurns,
                winner: controller.winner,
                isGameEnded: controller.isGameEnded,
                isSuddenDeath: controller.isSuddenDeathActive, // NEW PARAMETER
              ),
            ),
            // Game mode / progress indicator
            Positioned(
              bottom: 16,
              left: 16,
              child: _buildModeAndTurnInfo(context),
            ),
            // Dice button
            if (controller.gameState == GameState.waitingForDice &&
                !controller.isQuestionPanelVisible &&
                !controller.isTileEffectPanelVisible)
              _buildDiceButton(context, diceButtonLeft, diceButtonTop,
                  diceButtonWidth, diceButtonHeight),
            // Turn feedback text
            if ((controller.isDeterminingStartingOrder ||
                    (controller.gameState != GameState.waitingForDice &&
                        controller.gameState != GameState.gameOver)) &&
                controller.turnFeedback != null)
              _buildTurnFeedback(context, screenWidth, diceButtonTop),
            // Status text
            if (!controller.isDeterminingStartingOrder &&
                controller.gameState != GameState.waitingForDice &&
                controller.gameState != GameState.gameOver &&
                controller.turnFeedback == null)
              _buildStatusText(context, screenWidth, diceButtonTop),
            // Dice value display
            if (controller.diceValue > 0 || controller.isDiceRolling)
              _buildDiceValueDisplay(
                  context, screenWidth, diceButtonTop, diceButtonHeight),
            // Manual end game button
            if (controller.gameState != GameState.gameOver &&
                !controller.isDeterminingStartingOrder)
              Positioned(
                left: (screenWidth - 150) / 2,
                top: diceButtonTop + diceButtonHeight + 80,
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: (!controller.isTileEffectPanelVisible &&
                          !controller.isQuestionPanelVisible)
                      ? controller.endGameNow
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('OYUNU BİTİR'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ... (Diğer widget metotları aynı kalacak, sadece WinnerPanel değişti)
  // Kolaylık olsun diye değişmeyenleri de ekledim ama WinnerPanel önemli.

  Widget _buildStartingOrderPanel() {
    return Positioned(
      left: 16,
      top: 16,
      width: 220,
      height:
          controller.calculateStartingPanelHeight(controller.players.length),
      child: Container(
        padding: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.casino, color: Colors.amber, size: 16),
                SizedBox(width: 6),
                Text(
                  'Başlangıç Sırası',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...controller.players.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              final isLast = index == controller.players.length - 1;
              final diceValue = controller.startingDiceRolls[player.id];
              final isRolling =
                  controller.currentlyRollingPlayerId == player.id;
              final hasRolled = diceValue != null;

              return Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                constraints: const BoxConstraints(minHeight: 28, maxHeight: 28),
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
                    Icon(player.pawnIcon, color: player.color, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        player.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight:
                              isRolling ? FontWeight.bold : FontWeight.normal,
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(player.color),
                        ),
                      )
                    else if (hasRolled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: player.color.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$diceValue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Icon(Icons.hourglass_empty,
                          color: Colors.grey.shade400, size: 14),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnTransitionMessage(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.1,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: controller.turnTransitionMessage != null ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: controller.players[controller.currentPlayerIndex].color
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
              controller.turnTransitionMessage!,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  // GÜNCELLENMİŞ KAZANAN EKRANI (Bonus Soru sayısı eklendi)
  Widget _buildWinnerPanel() {
    return Positioned.fill(
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
                  border: Border.all(color: controller.winner!.color, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: controller.winner!.color.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events,
                        size: 64, color: controller.winner!.color),
                    const SizedBox(height: 16),
                    Text(
                      '${controller.winner!.name} kazandı!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: controller.winner!.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '⭐ ${controller.winner!.stars} puan',
                      style:
                          const TextStyle(fontSize: 24, color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            'Doğru Bonus Soru: ${controller.winner!.bonusQuestionsAnswered}',
                            style: TextStyle(fontSize: 16, color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: controller.restartGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        child: const Text(
                          'TEKRAR OYNA',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildDeveloperPanel(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange, width: 3),
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
            const Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Developer Mode ON',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Player:',
                style: TextStyle(color: Colors.white, fontSize: 11)),
            const SizedBox(height: 4),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  IconButton(
                    onPressed: controller.developerSelectedPlayerIndex > 0
                        ? () => controller.updateDeveloperSelectedPlayer(-1)
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        controller
                            .players[controller.developerSelectedPlayerIndex]
                            .name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: controller.developerSelectedPlayerIndex <
                            controller.players.length - 1
                        ? () => controller.updateDeveloperSelectedPlayer(1)
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 18),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Move tiles:',
                style: TextStyle(color: Colors.white, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  onPressed: controller.developerMoveTiles > 1
                      ? () => controller.updateDeveloperMoveTiles(-1)
                      : null,
                  icon: const Icon(Icons.remove, size: 16),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${controller.developerMoveTiles}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.developerMoveTiles < 39
                      ? () => controller.updateDeveloperMoveTiles(1)
                      : null,
                  icon: const Icon(Icons.add, size: 16),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                onPressed: controller.developerForceMove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text(
                  'Force Move',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnIndicator(BuildContext context) {
    return Positioned(
      top: 16,
      left: controller.isDeveloperMode ? 240 : 16,
      width: 200,
      height: 80,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: controller.players[controller.currentPlayerIndex].color
              .withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: controller.players[controller.currentPlayerIndex].color,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: controller.players[controller.currentPlayerIndex].color
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
            const Row(
              children: [
                Icon(Icons.play_circle_filled, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  'SIRA',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  controller.players[controller.currentPlayerIndex].pawnIcon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.players[controller.currentPlayerIndex].name,
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
    );
  }

  Widget _buildDiceButton(
    BuildContext context,
    double left,
    double top,
    double width,
    double height,
  ) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: controller.canRollDice && !controller.isDiceRolling
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
          onPressed: (!controller.isDeterminingStartingOrder &&
                  !controller.isTileEffectPanelVisible &&
                  !controller.isQuestionPanelVisible &&
                  controller.gameState == GameState.waitingForDice &&
                  controller.canRollDice)
              ? controller.rollDice
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: controller.isDiceRolling
                ? Colors.orange.shade700
                : controller.canRollDice
                    ? Colors.orange
                    : Colors.grey,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            controller.isDiceRolling ? '...' : 'ZAR',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildTurnFeedback(
      BuildContext context, double screenWidth, double diceButtonTop) {
    return Positioned(
      left: (screenWidth - 300) / 2,
      top: diceButtonTop - 50,
      width: 300,
      height: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            controller.turnFeedback!,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(
      BuildContext context, double screenWidth, double diceButtonTop) {
    return Positioned(
      left: (screenWidth - 300) / 2,
      top: diceButtonTop - 50,
      width: 300,
      height: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            controller.gameState == GameState.movingPawn
                ? 'Hareket ediliyor...'
                : controller.gameState == GameState.resolvingTile
                    ? 'Kare işleniyor...'
                    : 'Sıra işleniyor...',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDiceValueDisplay(
    BuildContext context,
    double screenWidth,
    double diceButtonTop,
    double diceButtonHeight,
  ) {
    return Positioned(
      left: (screenWidth - 80) / 2,
      top: diceButtonTop + diceButtonHeight + 20,
      width: 80,
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          color: controller.isDiceRolling
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: controller.isDiceRolling
              ? Border.all(color: Colors.orange, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            '${controller.diceValue}',
            style: TextStyle(
              fontSize: controller.isDiceRolling ? 28 : 32,
              fontWeight: FontWeight.bold,
              color: controller.isDiceRolling ? Colors.orange : Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildModeAndTurnInfo(BuildContext context) {
    final modeLabel = controller.gameMode == GameMode.turnBased
        ? 'Mod: Tur Bazlı'
        : 'Mod: Soru Bazlı';

    String detail;
    if (controller.gameMode == GameMode.turnBased) {
      detail = 'Tur: ${controller.currentTurn}/${controller.maxTurns}';
    } else {
      detail = 'Kalan Soru: ${controller.questionPool.length}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$modeLabel | $detail',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
