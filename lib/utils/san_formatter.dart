import '../models/chess_move.dart';
import '../models/chess_position.dart';

/// Immutable representation of an individual move in an engine PV line or variation,
/// holding precomputed snapshots for instantaneous O(1) board display.
class PvMoveItem {
  final int index; // 0-based index in the PV line
  final String uci;
  final ChessMove move;
  final String san;
  final String figurineSan;
  final PieceColor color;
  final int moveNumber;
  final ChessPosition positionBefore;
  final ChessPosition positionAfter;

  const PvMoveItem({
    required this.index,
    required this.uci,
    required this.move,
    required this.san,
    required this.figurineSan,
    required this.color,
    required this.moveNumber,
    required this.positionBefore,
    required this.positionAfter,
  });

  bool get isWhite => color == PieceColor.white;
}

/// Pure functional utility for chess notation (Standard SAN & Unicode Figurine SAN)
/// and PV line parsing into O(1) navigable snapshots.
class SANFormatter {
  // Unicode figurines
  static const Map<PieceType, String> whiteFigurines = {
    PieceType.king: '♔',
    PieceType.queen: '♕',
    PieceType.rook: '♖',
    PieceType.bishop: '♗',
    PieceType.knight: '♘',
    PieceType.pawn: '',
  };

  static const Map<PieceType, String> blackFigurines = {
    PieceType.king: '♚',
    PieceType.queen: '♛',
    PieceType.rook: '♜',
    PieceType.bishop: '♝',
    PieceType.knight: '♞',
    PieceType.pawn: '',
  };

  /// Generates Standard Algebraic Notation (SAN) conforming strictly to FIDE rules:
  /// - Knights are always uppercase 'N'.
  /// - Pawns have no letter prefix ('e4', 'd5', 'exd5', 'e8=Q#').
  /// - Captures use 'x'.
  /// - Checks use '+', Checkmate uses '#'.
  /// - Castling uses 'O-O' or 'O-O-O'.
  /// - Disambiguation uses file first, then rank, then full square.
  static String formatSan(ChessPosition position, ChessMove move) {
    if (move.isCastling) {
      return move.to.file > move.from.file ? 'O-O' : 'O-O-O';
    }

    String san;
    if (move.piece.type == PieceType.pawn) {
      if (move.isCapture) {
        final promo = move.promotion != null ? '=${move.promotion!.sanChar}' : '';
        san = '${move.from.algebraic[0]}x${move.to.algebraic}$promo';
      } else {
        final promo = move.promotion != null ? '=${move.promotion!.sanChar}' : '';
        san = '${move.to.algebraic}$promo';
      }
    } else {
      // Find candidate moves for disambiguation
      final candidates = position.legalMoves.where((m) =>
          m.piece.type == move.piece.type &&
          m.piece.color == move.piece.color &&
          m.to == move.to &&
          m.from != move.from).toList();

      String disambig = '';
      if (candidates.isNotEmpty) {
        final sameFile = candidates.any((m) => m.from.file == move.from.file);
        final sameRank = candidates.any((m) => m.from.rank == move.from.rank);
        if (!sameFile) {
          disambig = move.from.algebraic[0];
        } else if (!sameRank) {
          disambig = move.from.algebraic[1];
        } else {
          disambig = move.from.algebraic;
        }
      }

      final capture = move.isCapture ? 'x' : '';
      san = '${move.piece.type.sanChar}$disambig$capture${move.to.algebraic}';
    }

    // Determine check / checkmate suffix
    final nextPos = position.applyMove(move);
    if (nextPos.isCheck()) {
      final oppLegal = nextPos.generateLegalMoves();
      if (oppLegal.isEmpty) {
        san = '$san#';
      } else {
        san = '$san+';
      }
    }

    return san;
  }

  /// Converts standard SAN into beautiful Unicode figurine SAN:
  /// - White pieces: ♔ ♕ ♖ ♗ ♘
  /// - Black pieces: ♚ ♛ ♜ ♝ ♞
  /// - Pawns have no piece figurine, but pawn promotions convert '=Q' to '=♕' (or '=♛')
  /// - Preserves captures ('x'), checks ('+'), checkmate ('#'), and castling ('O-O')
  static String toFigurine(
    String san,
    PieceColor color,
    PieceType type, {
    PieceType? promotion,
  }) {
    String result = san;

    // Handle promotion piece letter replacement if present
    if (promotion != null && result.contains('=')) {
      final promoFigurine = color == PieceColor.white
          ? (whiteFigurines[promotion] ?? promotion.sanChar)
          : (blackFigurines[promotion] ?? promotion.sanChar);
      result = result.replaceAll('=${promotion.sanChar}', '=$promoFigurine');
    }

    // Castling or pawn moves have no piece letter at start
    if (type == PieceType.pawn || result.startsWith('O-O')) {
      return result;
    }

    // Replace the first character (piece letter) with the figurine glyph
    final pieceGlyph = color == PieceColor.white
        ? (whiteFigurines[type] ?? type.sanChar)
        : (blackFigurines[type] ?? type.sanChar);

    if (result.isNotEmpty && result[0] == type.sanChar) {
      return '$pieceGlyph${result.substring(1)}';
    }

    return result;
  }

  /// Returns the move number prefix formatting:
  /// - White move: '12. '
  /// - Black move when starting a line/variation: '12... '
  /// - Black move following White sequentially: '' (empty string)
  static String formatMovePrefix(
    int moveNumber,
    bool isWhite, {
    bool isFirstMoveInVariation = false,
  }) {
    if (isWhite) {
      return '$moveNumber. ';
    }
    if (isFirstMoveInVariation) {
      return '$moveNumber... ';
    }
    return '';
  }

  /// Parses a list of UCI move strings starting from [startPosition] sequentially.
  /// Constructs immutable [PvMoveItem]s containing [positionBefore] and [positionAfter]
  /// snapshots for each move in the sequence.
  ///
  /// Stops cleanly if an illegal or unparseable move is encountered.
  static List<PvMoveItem> parsePvLine(
    ChessPosition startPosition,
    List<String> uciMoves,
  ) {
    final items = <PvMoveItem>[];
    var currentPos = startPosition;

    for (int i = 0; i < uciMoves.length; i++) {
      final uci = uciMoves[i];
      if (uci.length < 4) break;

      final move = currentPos.findLegalMoveByUci(uci);
      if (move == null) break;

      // Ensure SAN is generated and cached
      move.san ??= formatSan(currentPos, move);

      final figurineSan = toFigurine(
        move.san!,
        move.piece.color,
        move.piece.type,
        promotion: move.promotion,
      );

      final nextPos = currentPos.applyMove(move);

      items.add(
        PvMoveItem(
          index: i,
          uci: uci,
          move: move,
          san: move.san!,
          figurineSan: figurineSan,
          color: currentPos.turn,
          moveNumber: currentPos.fullmoveNumber,
          positionBefore: currentPos,
          positionAfter: nextPos,
        ),
      );

      currentPos = nextPos;
    }

    return items;
  }
}
