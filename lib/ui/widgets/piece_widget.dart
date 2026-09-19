import 'package:flutter/material.dart';
import '../../models/chess_move.dart';

class PieceWidget extends StatelessWidget {
  final ChessPiece piece;
  final double size;
  final String pieceSet;

  const PieceWidget({
    super.key,
    required this.piece,
    required this.size,
    this.pieceSet = 'cburnett',
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/piece_sets/$pieceSet/${piece.color.isWhite ? "w" : "b"}${piece.type.charUpper}.webp';

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to default official Lichess cburnett set
        final fallbackPath = 'assets/piece_sets/cburnett/${piece.color.isWhite ? "w" : "b"}${piece.type.charUpper}.webp';
        return Image.asset(
          fallbackPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      },
    );
  }
}
