import 'package:flutter/material.dart';

/// Player model - represents a player in the game
class Player {
  final int id;
  final String name;
  final Color color;
  final IconData pawnIcon;
  int position; // Current tile index (0-39)

  /// Total score/points for the player.
  /// Historically this was called "stars" – we keep a stars getter/setter
  /// for backwards compatibility with existing UI code.
  int score;

  /// Number of times player went bankrupt.
  int bankruptCount;

  /// Number of correctly answered bonus questions.
  /// We keep a legacy alias getter/setter (bonusQuestionsAnswered) so existing
  /// code continues to work without large refactors.
  int bonusCorrectCount;

  // Backwards‑compatibility accessors
  int get stars => score;
  set stars(int value) => score = value;

  int get bonusQuestionsAnswered => bonusCorrectCount;
  set bonusQuestionsAnswered(int value) => bonusCorrectCount = value;

  Player({
    required this.id,
    required this.name,
    required this.color,
    required this.pawnIcon,
    required this.position,
    required int stars,
    this.bankruptCount = 0,
    int bonusCorrectCount = 0,
  })  : score = stars,
        bonusCorrectCount = bonusCorrectCount;

  /// Create a copy of this player with updated values
  Player copyWith({
    int? position,
    int? score,
    int? bankruptCount,
    int? bonusCorrectCount,
  }) {
    return Player(
      id: id,
      name: name,
      color: color,
      pawnIcon: pawnIcon,
      position: position ?? this.position,
      stars: score ?? this.score,
      bankruptCount: bankruptCount ?? this.bankruptCount,
      bonusCorrectCount: bonusCorrectCount ?? this.bonusCorrectCount,
    );
  }
}

