/// Tile types in the game
enum TileType {
  start,
  question,
  bonus,
  penalty,
  bankrupt,
  special,
}

/// Board tile model - represents a single tile on the game board
class BoardTile {
  final int index; // Tile position (0-39)
  final String title; // Display title
  final TileType type; // Tile type

  BoardTile({
    required this.index,
    required this.title,
    required this.type,
  });
}

