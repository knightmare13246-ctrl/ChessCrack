import 'dart:ui';
import '../models/chess_move.dart';

/// Centralized coordinate and geometry calculation service for the chessboard.
///
/// Ensures single source of truth for all arrow painters, piece renderers,
/// move highlights, and interaction layers across all screen orientations.
class BoardGeometry {
  final double boardSize;
  final bool isFlipped;
  final double squareSize;

  BoardGeometry({
    required this.boardSize,
    required this.isFlipped,
  }) : squareSize = boardSize / 8.0;

  /// Gets the screen center coordinate of a given [Square].
  Offset getSquareCenter(Square sq) {
    // White orientation: sq.file 0..7 (a..h, left-to-right), sq.rank 0..7 (1..8, bottom-to-top)
    // Black orientation: sq.file 7..0 (h..a, left-to-right), sq.rank 7..0 (8..1, bottom-to-top)
    final f = isFlipped ? (7 - sq.file) : sq.file;
    final r = isFlipped ? sq.rank : (7 - sq.rank);
    return Offset((f + 0.5) * squareSize, (r + 0.5) * squareSize);
  }

  /// Gets the square bounding box rect on screen.
  Rect getSquareRect(Square sq) {
    final f = isFlipped ? (7 - sq.file) : sq.file;
    final r = isFlipped ? sq.rank : (7 - sq.rank);
    return Rect.fromLTWH(f * squareSize, r * squareSize, squareSize, squareSize);
  }

  /// Converts a screen touch coordinate [point] to the corresponding [Square].
  Square? screenToSquare(Offset point) {
    if (point.dx < 0 || point.dx >= boardSize || point.dy < 0 || point.dy >= boardSize) {
      return null;
    }
    final col = (point.dx / squareSize).floor().clamp(0, 7);
    final row = (point.dy / squareSize).floor().clamp(0, 7);
    final file = isFlipped ? (7 - col) : col;
    final rank = isFlipped ? row : (7 - row);
    return Square(file, rank);
  }

  /// Board bounding box with safe insets.
  Rect get boardBounds => Rect.fromLTWH(0, 0, boardSize, boardSize);
}
