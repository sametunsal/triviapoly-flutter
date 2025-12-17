import 'package:flutter/material.dart';
import 'models/player_model.dart';
import 'game_controller.dart';

class Scoreboard extends StatelessWidget {
  final List<Player> players;
  final GameMode? gameMode;
  final int currentTurn;
  final int? maxTurns;
  final Player? winner; // Winner of the game
  final bool isGameEnded; // Whether game has ended

  const Scoreboard({
    super.key,
    required this.players,
    this.gameMode,
    required this.currentTurn,
    this.maxTurns,
    this.winner,
    this.isGameEnded = false,
  });

  List<Player> _getSortedPlayers() {
    final sorted = List<Player>.from(players);
    sorted.sort((a, b) {
      if (b.stars != a.stars) return b.stars.compareTo(a.stars);
      if (b.bonusQuestionsAnswered != a.bonusQuestionsAnswered) {
        return b.bonusQuestionsAnswered.compareTo(a.bonusQuestionsAnswered);
      }
      return a.bankruptCount.compareTo(b.bankruptCount);
    });
    return sorted;
  }

  int? _getLeadingPlayerIndex(List<Player> sorted) {
    if (sorted.isEmpty) return null;
    final topScore = sorted[0].stars;
    final topBonus = sorted[0].bonusQuestionsAnswered;
    final topBankrupt = sorted[0].bankruptCount;

    final leadingPlayers = sorted.where((p) =>
        p.stars == topScore &&
        p.bonusQuestionsAnswered == topBonus &&
        p.bankruptCount == topBankrupt);

    if (leadingPlayers.length == 1) {
      return players.indexWhere((p) => p.id == sorted[0].id);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = _getSortedPlayers();
    final leadingPlayerIndex = _getLeadingPlayerIndex(sortedPlayers);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gameMode == GameMode.turnBased)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Tur: $currentTurn / $maxTurns',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ...sortedPlayers.map((player) {
            final playerIndex = players.indexWhere((p) => p.id == player.id);
            final isLeading = playerIndex == leadingPlayerIndex;
            final hasZeroStars = player.stars == 0;
            final isBankrupt = player.bankruptCount > 0;
            final isWinner = winner != null && player.id == winner!.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isWinner
                    ? player.color.withValues(alpha: 0.3)
                    : hasZeroStars || isBankrupt
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isWinner
                      ? player.color
                      : hasZeroStars || isBankrupt
                          ? Colors.red.shade400
                          : Colors.white.withValues(alpha: 0.1),
                  width: isWinner ? 3 : (hasZeroStars || isBankrupt ? 2 : 1),
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
                        player.pawnIcon,
                        color: player.color,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                player.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isWinner
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isWinner)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.emoji_events,
                                  size: 16,
                                  color: Colors.amber.shade400,
                                ),
                              ),
                            if (isBankrupt)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            if (isLeading && !isBankrupt && !isWinner)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.trending_up,
                                  size: 14,
                                  color: Colors.amber.shade400,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Position indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: player.color.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: player.color,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Kare ${player.position + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: player.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Stars
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasZeroStars
                              ? Colors.red.withValues(alpha: 0.3)
                              : Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '⭐',
                              style: TextStyle(
                                fontSize: 14,
                                color: hasZeroStars
                                    ? Colors.red.shade300
                                    : Colors.amber.shade300,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${player.stars}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: hasZeroStars
                                    ? Colors.red.shade300
                                    : Colors.amber.shade300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatBadge(
                        Icons.star,
                        '${player.bonusQuestionsAnswered}',
                        Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      if (player.bankruptCount > 0)
                        _buildStatBadge(
                          Icons.warning,
                          '${player.bankruptCount}',
                          Colors.red,
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
