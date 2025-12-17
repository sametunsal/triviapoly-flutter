import 'dart:math';
import 'package:flutter/material.dart';
import 'models/player_model.dart';
import 'models/tile_model.dart';

class BoardPainter extends CustomPainter {
  final List<BoardTile> tiles;
  final List<Player> players;
  final double boardSize;
  final int? highlightedTileIndex;
  final int? currentPlayerIndex; // To highlight current player's tile

  BoardPainter({
    required this.tiles,
    required this.players,
    required this.boardSize,
    this.highlightedTileIndex,
    this.currentPlayerIndex,
  });

  Offset _getCellPosition(
      int index, double offsetX, double offsetY, double cellSize) {
    if (index >= 0 && index < 10) {
      final col = index;
      return Offset(
          offsetX + col * cellSize + cellSize / 2, offsetY + cellSize / 2);
    } else if (index >= 10 && index < 20) {
      final row = index - 10;
      return Offset(offsetX + boardSize - cellSize / 2,
          offsetY + row * cellSize + cellSize / 2);
    } else if (index >= 20 && index < 30) {
      final col = 29 - index;
      return Offset(offsetX + col * cellSize + cellSize / 2,
          offsetY + boardSize - cellSize / 2);
    } else {
      final row = 39 - index;
      return Offset(
          offsetX + cellSize / 2, offsetY + row * cellSize + cellSize / 2);
    }
  }

  // Calculate offsets for multiple players on the same tile
  List<Offset> _getPlayerOffsets(int playerCount, double cellSize) {
    final maxOffset = cellSize * 0.25; // Maximum offset from center
    final offsets = <Offset>[];

    switch (playerCount) {
      case 1:
        // Single player: center
        offsets.add(Offset.zero);
        break;
      case 2:
        // Two players: left and right
        offsets.add(Offset(-maxOffset, 0));
        offsets.add(Offset(maxOffset, 0));
        break;
      case 3:
        // Three players: triangle layout
        offsets.add(Offset(0, -maxOffset * 0.8)); // Top
        offsets.add(Offset(-maxOffset * 0.8, maxOffset * 0.8)); // Bottom left
        offsets.add(Offset(maxOffset * 0.8, maxOffset * 0.8)); // Bottom right
        break;
      case 4:
        // Four players: 2x2 grid
        offsets.add(Offset(-maxOffset * 0.7, -maxOffset * 0.7)); // Top left
        offsets.add(Offset(maxOffset * 0.7, -maxOffset * 0.7)); // Top right
        offsets.add(Offset(-maxOffset * 0.7, maxOffset * 0.7)); // Bottom left
        offsets.add(Offset(maxOffset * 0.7, maxOffset * 0.7)); // Bottom right
        break;
      default:
        // Fallback: distribute in a circle
        for (int i = 0; i < playerCount; i++) {
          final angle = (i * 2 * 3.14159) / playerCount;
          offsets.add(Offset(
            maxOffset * 0.8 * cos(angle),
            maxOffset * 0.8 * sin(angle),
          ));
        }
    }

    return offsets;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final offsetX = centerX - boardSize / 2;
    final offsetY = centerY - boardSize / 2;
    final cellSize = boardSize / 10;

    for (int i = 0; i < 40; i++) {
      final position = _getCellPosition(i, offsetX, offsetY, cellSize);
      final cellRect = Rect.fromCenter(
        center: position,
        width: cellSize,
        height: cellSize,
      );

      final tile = tiles[i];
      Color bgColor;

      // Assign colors based on tile type
      switch (tile.type) {
        case TileType.start:
          bgColor = Colors.green.shade200;
          break;
        case TileType.bankrupt:
          bgColor = Colors.red.shade300;
          break;
        case TileType.bonus:
          bgColor = Colors.amber.shade200;
          break;
        case TileType.penalty:
          bgColor = Colors.orange.shade200;
          break;
        case TileType.question:
          bgColor = Colors.blue.shade100;
          break;
        case TileType.special:
          bgColor = Colors.purple.shade100;
          break;
      }

      // Highlight tile if it's the highlighted one (during movement/landing)
      if (highlightedTileIndex == i) {
        bgColor = Colors.blue.shade300; // Stronger highlight for active tile
      }

      // Highlight current player's tile with a glow effect
      if (currentPlayerIndex != null) {
        final currentPlayer = players[currentPlayerIndex!];
        if (currentPlayer.position == i && highlightedTileIndex != i) {
          // Subtle glow for current player's position
          bgColor = Color.lerp(bgColor, currentPlayer.color, 0.3) ?? bgColor;
        }
      }

      final bgPaint = Paint()
        ..color = bgColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(cellRect, bgPaint);

      // Draw border - thicker for highlighted, colored for current player
      double borderWidth = 2.0;
      Color borderColor = Colors.black;

      if (highlightedTileIndex == i) {
        borderWidth = 4.0;
        borderColor = Colors.blue.shade700;
      } else if (currentPlayerIndex != null) {
        final currentPlayer = players[currentPlayerIndex!];
        if (currentPlayer.position == i) {
          borderWidth = 3.0;
          borderColor = currentPlayer.color;
        }
      }

      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawRect(cellRect, borderPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: tile.title,
          style: TextStyle(
            fontSize: cellSize * 0.12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: cellSize - 8);
      textPainter.paint(
        canvas,
        Offset(
          position.dx - textPainter.width / 2,
          position.dy - textPainter.height / 2,
        ),
      );
    }

    // Group players by tile position to handle overlapping
    // DETERMINISTIC: Sort by player ID to ensure consistent rendering order
    final Map<int, List<Player>> playersByTile = {};
    for (final player in players) {
      playersByTile.putIfAbsent(player.position, () => []).add(player);
    }

    // Draw players with offsets to prevent overlapping
    for (final entry in playersByTile.entries) {
      final tileIndex = entry.key;
      // Sort players by ID for deterministic rendering order
      final playersOnTile = List<Player>.from(entry.value)
        ..sort((a, b) => a.id.compareTo(b.id));
      final basePosition =
          _getCellPosition(tileIndex, offsetX, offsetY, cellSize);

      // Calculate offsets based on number of players
      final offsets = _getPlayerOffsets(playersOnTile.length, cellSize);

      for (int i = 0; i < playersOnTile.length; i++) {
        final player = playersOnTile[i];
        final offset = offsets[i];
        final pawnPosition = Offset(
          basePosition.dx + offset.dx,
          basePosition.dy + offset.dy,
        );

        // Determine if this is the current active player
        final isCurrentPlayer = currentPlayerIndex != null &&
            player.id == players[currentPlayerIndex!].id;

        // VISUAL DOMINANCE: Current player gets larger token and stronger effects
        final baseRadius = playersOnTile.length > 1 ? 12.0 : 15.0;
        final tokenRadius = isCurrentPlayer ? baseRadius * 1.3 : baseRadius;

        // INACTIVE PLAYERS: Dim non-active players
        final playerColor = isCurrentPlayer
            ? player.color
            : player.color.withValues(alpha: 0.5); // Dim inactive players

        // Draw glow effect for current player
        if (isCurrentPlayer) {
          final glowPaint = Paint()
            ..color = player.color.withValues(alpha: 0.3)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawCircle(pawnPosition, tokenRadius + 4, glowPaint);
        }

        // Draw player token
        final pawnPaint = Paint()
          ..color = playerColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pawnPosition, tokenRadius, pawnPaint);

        // STRONGER BORDER for current player
        final borderWidth = isCurrentPlayer ? 5.0 : 3.0;
        final borderColor = isCurrentPlayer
            ? Colors.white
            : Colors.white.withValues(alpha: 0.7);
        final pawnBorderPaint = Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;
        canvas.drawCircle(pawnPosition, tokenRadius, pawnBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) {
    if (oldDelegate.boardSize != boardSize) return true;
    if (oldDelegate.players.length != players.length) return true;
    if (oldDelegate.highlightedTileIndex != highlightedTileIndex) return true;
    if (oldDelegate.currentPlayerIndex != currentPlayerIndex) return true;
    for (int i = 0; i < players.length; i++) {
      if (oldDelegate.players[i].position != players[i].position) {
        return true;
      }
    }
    return false;
  }
}

