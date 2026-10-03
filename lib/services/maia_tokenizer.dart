import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/chess_move.dart';
import '../models/chess_position.dart';

/// The official Maia-3 tokenizer, move vocabulary, and legal move probability decoder.
/// 
/// Corresponds to the official CSSLab Maia-3 architecture (Monroe et al., ICLR 2026).
/// Operates on 4352 move logits (4096 square-to-square moves + 256 promotions) and
/// (64, 12) one-hot board tokens.
class MaiaTokenizer {
  static const int totalMoves = 4352;
  static const int boardSquares = 64;
  static const int pieceChannels = 12;

  // Singletons initialized once
  static final List<String> _allMoves = _generateAllPossibleMoves();
  static final Map<String, int> _allMovesDict = {
    for (int i = 0; i < _allMoves.length; i++) _allMoves[i]: i
  };

  static List<String> get allMoves => _allMoves;
  static Map<String, int> get allMovesDict => _allMovesDict;

  /// Piece indices matching Python/ONNX model:
  /// White: P=0, N=1, B=2, R=3, Q=4, K=5
  /// Black: p=6, n=7, b=8, r=9, q=10, k=11
  static const List<String> pieceSymbols = [
    'P', 'N', 'B', 'R', 'Q', 'K',
    'p', 'n', 'b', 'r', 'q', 'k'
  ];

  static List<String> _generateAllPossibleMoves() {
    final moves = <String>[];
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final fromSq = _squareName(file, rank);
        for (int targetRank = 0; targetRank < 8; targetRank++) {
          for (int targetFile = 0; targetFile < 8; targetFile++) {
            final toSq = _squareName(targetFile, targetRank);
            moves.add('$fromSq$toSq');
          }
        }
      }
    }

    // 256 promotions (from rank 7 to rank 8)
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    const promoPieces = ['q', 'r', 'b', 'n'];
    for (final fromFile in files) {
      for (final toFile in files) {
        for (final piece in promoPieces) {
          moves.add('${fromFile}7${toFile}8$piece');
        }
      }
    }
    return moves;
  }

  static String _squareName(int file, int rank) {
    const fileChars = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    return '${fileChars[file]}${rank + 1}';
  }

  /// Inverts a square coordinate vertically (rank 1 <-> 8, 2 <-> 7, etc.)
  static String mirrorSquare(String square) {
    final file = square[0];
    final rank = (9 - int.parse(square[1])).toString();
    return '$file$rank';
  }

  /// Mirrors a UCI move string vertically for Black's perspective
  static String mirrorMove(String moveUci) {
    final isPromo = moveUci.length > 4;
    final start = mirrorSquare(moveUci.substring(0, 2));
    final end = mirrorSquare(moveUci.substring(2, 4));
    final promo = isPromo ? moveUci.substring(4) : '';
    return '$start$end$promo';
  }

  /// Converts a [ChessPosition] into a flat (64, 12) Float32List.
  /// 
  /// If Black to move, the board is mirrored so the active player is always
  /// evaluated from White's perspective.
  static Float32List tokenizePosition(ChessPosition position) {
    final tokens = Float32List(boardSquares * pieceChannels);
    final isBlack = position.turn == PieceColor.black;

    for (int sq = 0; sq < 64; sq++) {
      final rank = sq ~/ 8;
      final file = sq % 8;

      // When Black to move, mirror rank and invert piece color
      final srcRank = isBlack ? (7 - rank) : rank;
      final srcSq = srcRank * 8 + file;
      final piece = position.board[srcSq];

      if (piece != null) {
        String symbol;
        if (isBlack) {
          symbol = piece.color == PieceColor.white
              ? piece.type.charLower
              : piece.type.charUpper;
        } else {
          symbol = piece.fenChar;
        }
        final pieceIdx = pieceSymbols.indexOf(symbol);
        if (pieceIdx >= 0) {
          tokens[sq * pieceChannels + pieceIdx] = 1.0;
        }
      }
    }
    return tokens;
  }

  /// Generates the legal move mask for the position.
  /// 
  /// Returns a boolean list of length 4352 where true indicates a legal move.
  static List<bool> getLegalMoveMask(ChessPosition position) {
    final mask = List<bool>.filled(totalMoves, false);
    final isBlack = position.turn == PieceColor.black;

    for (final move in position.legalMoves) {
      final uci = isBlack ? mirrorMove(move.uci) : move.uci;
      final idx = _allMovesDict[uci];
      if (idx != null) {
        mask[idx] = true;
      }
    }
    return mask;
  }

  /// Applies legal move masking and numerically stable softmax over legal moves.
  /// 
  /// Returns a map of real board UCI moves to their probability (0.0 to 1.0).
  /// Probabilities sum to 1.0.
  static Map<String, double> decodePolicyLogits({
    required List<double> logits,
    required ChessPosition position,
  }) {
    assert(logits.length >= totalMoves);
    final isBlack = position.turn == PieceColor.black;
    final legalMask = getLegalMoveMask(position);

    final legalIndices = <int>[];
    double maxLogit = -double.infinity;

    for (int i = 0; i < totalMoves; i++) {
      if (legalMask[i]) {
        legalIndices.add(i);
        if (logits[i] > maxLogit) {
          maxLogit = logits[i];
        }
      }
    }

    if (legalIndices.isEmpty) {
      if (kDebugMode) {
        developer.log('decodePolicyLogits: legalIndices is EMPTY! position=${position.toFen()}', name: 'MaiaTokenizer');
      }
      return {};
    }

    if (kDebugMode) {
      developer.log(
        'decodePolicyLogits: legalIndices.length=${legalIndices.length}, maxLogit=$maxLogit',
        name: 'MaiaTokenizer',
      );
    }

    double sumExp = 0.0;
    final expValues = List<double>.filled(legalIndices.length, 0.0);
    for (int i = 0; i < legalIndices.length; i++) {
      final expVal = math.exp(logits[legalIndices[i]] - maxLogit);
      expValues[i] = expVal;
      sumExp += expVal;
    }

    final result = <String, double>{};
    for (int i = 0; i < legalIndices.length; i++) {
      final idx = legalIndices[i];
      final modelUci = _allMoves[idx];
      final realUci = isBlack ? mirrorMove(modelUci) : modelUci;
      final prob = sumExp > 0 ? (expValues[i] / sumExp) : 0.0;
      result[realUci] = prob;
    }

    return result;
  }
}
