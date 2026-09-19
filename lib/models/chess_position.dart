import 'chess_move.dart';

class ChessPosition {
  final List<ChessPiece?> board; // length 64, index = rank * 8 + file
  final PieceColor turn;
  final bool whiteCanCastleKingside;
  final bool whiteCanCastleQueenside;
  final bool blackCanCastleKingside;
  final bool blackCanCastleQueenside;
  final Square? enPassantTarget;
  final int halfmoveClock;
  final int fullmoveNumber;

  List<ChessMove>? _cachedLegalMoves;
  Map<String, ChessMove>? _cachedUciMap;

  List<ChessMove> get legalMoves => _cachedLegalMoves ?? generateLegalMoves();

  static const String initialFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  ChessPosition({
    required this.board,
    required this.turn,
    required this.whiteCanCastleKingside,
    required this.whiteCanCastleQueenside,
    required this.blackCanCastleKingside,
    required this.blackCanCastleQueenside,
    this.enPassantTarget,
    this.halfmoveClock = 0,
    this.fullmoveNumber = 1,
  }) : assert(board.length == 64);

  ChessPiece? pieceAt(Square square) => board[square.index];
  ChessPiece? pieceAtCoords(int file, int rank) => board[rank * 8 + file];

  factory ChessPosition.initial() => ChessPosition.fromFen(initialFen);

  factory ChessPosition.fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) {
      throw FormatException('Invalid FEN: $fen');
    }

    final boardStr = parts[0];
    final turnStr = parts[1];
    final castlingStr = parts[2];
    final epStr = parts[3];
    final halfStr = parts.length > 4 ? parts[4] : '0';
    final fullStr = parts.length > 5 ? parts[5] : '1';

    final board = List<ChessPiece?>.filled(64, null);
    final ranks = boardStr.split('/');
    if (ranks.length != 8) {
      throw FormatException('Invalid FEN ranks: $boardStr');
    }

    for (int r = 0; r < 8; r++) {
      final rankIndex = 7 - r;
      int fileIndex = 0;
      for (int i = 0; i < ranks[r].length; i++) {
        final char = ranks[r][i];
        if (RegExp(r'[1-8]').hasMatch(char)) {
          fileIndex += int.parse(char);
        } else {
          final piece = ChessPiece.fromFenChar(char);
          if (piece != null && fileIndex < 8) {
            board[rankIndex * 8 + fileIndex] = piece;
          }
          fileIndex++;
        }
      }
    }

    final turn = turnStr == 'b' ? PieceColor.black : PieceColor.white;
    final wck = castlingStr.contains('K');
    final wcq = castlingStr.contains('Q');
    final bck = castlingStr.contains('k');
    final bcq = castlingStr.contains('q');

    Square? epTarget;
    if (epStr != '-') {
      try {
        epTarget = Square.fromAlgebraic(epStr);
      } catch (_) {
        epTarget = null;
      }
    }

    return ChessPosition(
      board: board,
      turn: turn,
      whiteCanCastleKingside: wck,
      whiteCanCastleQueenside: wcq,
      blackCanCastleKingside: bck,
      blackCanCastleQueenside: bcq,
      enPassantTarget: epTarget,
      halfmoveClock: int.tryParse(halfStr) ?? 0,
      fullmoveNumber: int.tryParse(fullStr) ?? 1,
    );
  }

  String toFen() {
    final buffer = StringBuffer();
    for (int r = 7; r >= 0; r--) {
      int empty = 0;
      for (int f = 0; f < 8; f++) {
        final piece = board[r * 8 + f];
        if (piece == null) {
          empty++;
        } else {
          if (empty > 0) {
            buffer.write(empty);
            empty = 0;
          }
          buffer.write(piece.fenChar);
        }
      }
      if (empty > 0) {
        buffer.write(empty);
      }
      if (r > 0) buffer.write('/');
    }

    buffer.write(' ');
    buffer.write(turn == PieceColor.white ? 'w' : 'b');
    buffer.write(' ');

    final castling = StringBuffer();
    if (whiteCanCastleKingside) castling.write('K');
    if (whiteCanCastleQueenside) castling.write('Q');
    if (blackCanCastleKingside) castling.write('k');
    if (blackCanCastleQueenside) castling.write('q');
    if (castling.isEmpty) castling.write('-');
    buffer.write(castling.toString());

    buffer.write(' ');
    buffer.write(enPassantTarget != null ? enPassantTarget!.algebraic : '-');
    buffer.write(' ');
    buffer.write(halfmoveClock);
    buffer.write(' ');
    buffer.write(fullmoveNumber);

    return buffer.toString();
  }

  Square? findKing(PieceColor color) {
    for (int i = 0; i < 64; i++) {
      final p = board[i];
      if (p != null && p.type == PieceType.king && p.color == color) {
        return Square.fromIndex(i);
      }
    }
    return null;
  }

  bool isSquareAttacked(Square target, PieceColor byColor) {
    // Knight attacks
    const knightOffsets = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1]
    ];
    for (final off in knightOffsets) {
      final f = target.file + off[0];
      final r = target.rank + off[1];
      if (f >= 0 && f < 8 && r >= 0 && r < 8) {
        final p = pieceAtCoords(f, r);
        if (p != null && p.color == byColor && p.type == PieceType.knight) {
          return true;
        }
      }
    }

    // Pawn attacks
    final pawnDir = byColor.isWhite ? -1 : 1;
    final pawnRank = target.rank + pawnDir;
    if (pawnRank >= 0 && pawnRank < 8) {
      for (final df in [-1, 1]) {
        final pf = target.file + df;
        if (pf >= 0 && pf < 8) {
          final p = pieceAtCoords(pf, pawnRank);
          if (p != null && p.color == byColor && p.type == PieceType.pawn) {
            return true;
          }
        }
      }
    }

    // King attacks
    for (int df = -1; df <= 1; df++) {
      for (int dr = -1; dr <= 1; dr++) {
        if (df == 0 && dr == 0) continue;
        final f = target.file + df;
        final r = target.rank + dr;
        if (f >= 0 && f < 8 && r >= 0 && r < 8) {
          final p = pieceAtCoords(f, r);
          if (p != null && p.color == byColor && p.type == PieceType.king) {
            return true;
          }
        }
      }
    }

    // Sliders: Bishops & Queens
    const diagDirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    for (final dir in diagDirs) {
      int f = target.file + dir[0];
      int r = target.rank + dir[1];
      while (f >= 0 && f < 8 && r >= 0 && r < 8) {
        final p = pieceAtCoords(f, r);
        if (p != null) {
          if (p.color == byColor && (p.type == PieceType.bishop || p.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        f += dir[0];
        r += dir[1];
      }
    }

    // Sliders: Rooks & Queens
    const straightDirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final dir in straightDirs) {
      int f = target.file + dir[0];
      int r = target.rank + dir[1];
      while (f >= 0 && f < 8 && r >= 0 && r < 8) {
        final p = pieceAtCoords(f, r);
        if (p != null) {
          if (p.color == byColor && (p.type == PieceType.rook || p.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        f += dir[0];
        r += dir[1];
      }
    }

    return false;
  }

  bool isCheck([PieceColor? color]) {
    final c = color ?? turn;
    final kingSq = findKing(c);
    if (kingSq == null) return false;
    return isSquareAttacked(kingSq, c.opponent);
  }

  List<ChessMove> generateLegalMoves() {
    if (_cachedLegalMoves != null) return _cachedLegalMoves!;

    final pseudoMoves = _generatePseudoLegalMoves(turn);
    final legalMoves = <ChessMove>[];

    for (final move in pseudoMoves) {
      final nextPos = applyMove(move);
      if (!nextPos.isCheck(turn)) {
        legalMoves.add(move);
      }
    }

    _populateSanMoves(legalMoves);
    _cachedLegalMoves = legalMoves;

    final uciMap = <String, ChessMove>{};
    for (final m in legalMoves) {
      final key = m.promotion != null
          ? '${m.from.algebraic}${m.to.algebraic}${m.promotion!.charLower}'
          : '${m.from.algebraic}${m.to.algebraic}';
      uciMap[key.toLowerCase()] = m;
    }
    _cachedUciMap = uciMap;

    return legalMoves;
  }

  List<ChessMove> _generatePseudoLegalMoves(PieceColor side) {
    final moves = <ChessMove>[];

    for (int idx = 0; idx < 64; idx++) {
      final piece = board[idx];
      if (piece == null || piece.color != side) continue;

      final from = Square.fromIndex(idx);

      switch (piece.type) {
        case PieceType.pawn:
          _generatePawnMoves(from, piece, moves);
          break;
        case PieceType.knight:
          _generateKnightMoves(from, piece, moves);
          break;
        case PieceType.bishop:
          _generateSlidingMoves(from, piece, const [[-1, -1], [-1, 1], [1, -1], [1, 1]], moves);
          break;
        case PieceType.rook:
          _generateSlidingMoves(from, piece, const [[-1, 0], [1, 0], [0, -1], [0, 1]], moves);
          break;
        case PieceType.queen:
          _generateSlidingMoves(from, piece, const [
            [-1, -1], [-1, 1], [1, -1], [1, 1],
            [-1, 0], [1, 0], [0, -1], [0, 1]
          ], moves);
          break;
        case PieceType.king:
          _generateKingMoves(from, piece, moves);
          break;
      }
    }

    return moves;
  }

  void _generatePawnMoves(Square from, ChessPiece piece, List<ChessMove> moves) {
    final f = from.file;
    final r = from.rank;
    final forward = piece.color.isWhite ? 1 : -1;
    final startRank = piece.color.isWhite ? 1 : 6;
    final promoRank = piece.color.isWhite ? 7 : 0;

    final nextRank = r + forward;
    if (nextRank >= 0 && nextRank < 8 && pieceAtCoords(f, nextRank) == null) {
      final to = Square(f, nextRank);
      if (nextRank == promoRank) {
        for (final promo in const [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
          moves.add(ChessMove(from: from, to: to, piece: piece, promotion: promo));
        }
      } else {
        moves.add(ChessMove(from: from, to: to, piece: piece));
        final doubleRank = r + forward * 2;
        if (r == startRank && pieceAtCoords(f, doubleRank) == null) {
          moves.add(ChessMove(from: from, to: Square(f, doubleRank), piece: piece));
        }
      }
    }

    for (final df in [-1, 1]) {
      final toFile = f + df;
      if (toFile >= 0 && toFile < 8 && nextRank >= 0 && nextRank < 8) {
        final targetPiece = pieceAtCoords(toFile, nextRank);
        final to = Square(toFile, nextRank);

        if (targetPiece != null && targetPiece.color != piece.color) {
          if (nextRank == promoRank) {
            for (final promo in const [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
              moves.add(ChessMove(from: from, to: to, piece: piece, promotion: promo, isCapture: true, capturedPiece: targetPiece));
            }
          } else {
            moves.add(ChessMove(from: from, to: to, piece: piece, isCapture: true, capturedPiece: targetPiece));
          }
        } else if (enPassantTarget != null && enPassantTarget == to) {
          final epCapturedPiece = pieceAtCoords(toFile, r);
          moves.add(ChessMove(from: from, to: to, piece: piece, isCapture: true, isEnPassant: true, capturedPiece: epCapturedPiece));
        }
      }
    }
  }

  void _generateKnightMoves(Square from, ChessPiece piece, List<ChessMove> moves) {
    const offsets = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1]
    ];
    for (final off in offsets) {
      final f = from.file + off[0];
      final r = from.rank + off[1];
      if (f >= 0 && f < 8 && r >= 0 && r < 8) {
        final target = pieceAtCoords(f, r);
        if (target == null) {
          moves.add(ChessMove(from: from, to: Square(f, r), piece: piece));
        } else if (target.color != piece.color) {
          moves.add(ChessMove(from: from, to: Square(f, r), piece: piece, isCapture: true, capturedPiece: target));
        }
      }
    }
  }

  void _generateSlidingMoves(Square from, ChessPiece piece, List<List<int>> dirs, List<ChessMove> moves) {
    for (final dir in dirs) {
      int f = from.file + dir[0];
      int r = from.rank + dir[1];
      while (f >= 0 && f < 8 && r >= 0 && r < 8) {
        final target = pieceAtCoords(f, r);
        if (target == null) {
          moves.add(ChessMove(from: from, to: Square(f, r), piece: piece));
        } else {
          if (target.color != piece.color) {
            moves.add(ChessMove(from: from, to: Square(f, r), piece: piece, isCapture: true, capturedPiece: target));
          }
          break;
        }
        f += dir[0];
        r += dir[1];
      }
    }
  }

  void _generateKingMoves(Square from, ChessPiece piece, List<ChessMove> moves) {
    for (int df = -1; df <= 1; df++) {
      for (int dr = -1; dr <= 1; dr++) {
        if (df == 0 && dr == 0) continue;
        final f = from.file + df;
        final r = from.rank + dr;
        if (f >= 0 && f < 8 && r >= 0 && r < 8) {
          final target = pieceAtCoords(f, r);
          if (target == null) {
            moves.add(ChessMove(from: from, to: Square(f, r), piece: piece));
          } else if (target.color != piece.color) {
            moves.add(ChessMove(from: from, to: Square(f, r), piece: piece, isCapture: true, capturedPiece: target));
          }
        }
      }
    }

    if (piece.color.isWhite) {
      if (from == const Square(4, 0) && !isCheck(PieceColor.white)) {
        if (whiteCanCastleKingside &&
            pieceAtCoords(5, 0) == null &&
            pieceAtCoords(6, 0) == null &&
            !isSquareAttacked(const Square(5, 0), PieceColor.black) &&
            !isSquareAttacked(const Square(6, 0), PieceColor.black)) {
          moves.add(ChessMove(from: from, to: const Square(6, 0), piece: piece, isCastling: true));
        }
        if (whiteCanCastleQueenside &&
            pieceAtCoords(3, 0) == null &&
            pieceAtCoords(2, 0) == null &&
            pieceAtCoords(1, 0) == null &&
            !isSquareAttacked(const Square(3, 0), PieceColor.black) &&
            !isSquareAttacked(const Square(2, 0), PieceColor.black)) {
          moves.add(ChessMove(from: from, to: const Square(2, 0), piece: piece, isCastling: true));
        }
      }
    } else {
      if (from == const Square(4, 7) && !isCheck(PieceColor.black)) {
        if (blackCanCastleKingside &&
            pieceAtCoords(5, 7) == null &&
            pieceAtCoords(6, 7) == null &&
            !isSquareAttacked(const Square(5, 7), PieceColor.white) &&
            !isSquareAttacked(const Square(6, 7), PieceColor.white)) {
          moves.add(ChessMove(from: from, to: const Square(6, 7), piece: piece, isCastling: true));
        }
        if (blackCanCastleQueenside &&
            pieceAtCoords(3, 7) == null &&
            pieceAtCoords(2, 7) == null &&
            pieceAtCoords(1, 7) == null &&
            !isSquareAttacked(const Square(3, 7), PieceColor.white) &&
            !isSquareAttacked(const Square(2, 7), PieceColor.white)) {
          moves.add(ChessMove(from: from, to: const Square(2, 7), piece: piece, isCastling: true));
        }
      }
    }
  }

  void _populateSanMoves(List<ChessMove> legalMoves) {
    for (final move in legalMoves) {
      if (move.isCastling) {
        move.san = move.to.file > move.from.file ? 'O-O' : 'O-O-O';
      } else if (move.piece.type == PieceType.pawn) {
        if (move.isCapture) {
          final promo = move.promotion != null ? '=${move.promotion!.sanChar}' : '';
          move.san = '${move.from.algebraic[0]}x${move.to.algebraic}$promo';
        } else {
          final promo = move.promotion != null ? '=${move.promotion!.sanChar}' : '';
          move.san = '${move.to.algebraic}$promo';
        }
      } else {
        final candidates = legalMoves.where((m) =>
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
        move.san = '${move.piece.type.sanChar}$disambig$capture${move.to.algebraic}';
      }

      final nextPos = applyMove(move);
      if (nextPos.isCheck()) {
        final oppLegal = nextPos.generateLegalMoves();
        if (oppLegal.isEmpty) {
          move.san = '${move.san}#';
        } else {
          move.san = '${move.san}+';
        }
      }
    }
  }

  ChessPosition applyMove(ChessMove move) {
    final nextBoard = List<ChessPiece?>.from(board);

    nextBoard[move.from.index] = null;

    if (move.isEnPassant) {
      final capturedRank = move.from.rank;
      final capturedFile = move.to.file;
      nextBoard[capturedRank * 8 + capturedFile] = null;
    }

    final placedPiece = move.promotion != null
        ? ChessPiece(move.promotion!, move.piece.color)
        : move.piece;
    nextBoard[move.to.index] = placedPiece;

    if (move.isCastling) {
      if (move.piece.color.isWhite) {
        if (move.to == const Square(6, 0)) {
          nextBoard[const Square(7, 0).index] = null;
          nextBoard[const Square(5, 0).index] = const ChessPiece(PieceType.rook, PieceColor.white);
        } else if (move.to == const Square(2, 0)) {
          nextBoard[const Square(0, 0).index] = null;
          nextBoard[const Square(3, 0).index] = const ChessPiece(PieceType.rook, PieceColor.white);
        }
      } else {
        if (move.to == const Square(6, 7)) {
          nextBoard[const Square(7, 7).index] = null;
          nextBoard[const Square(5, 7).index] = const ChessPiece(PieceType.rook, PieceColor.black);
        } else if (move.to == const Square(2, 7)) {
          nextBoard[const Square(0, 7).index] = null;
          nextBoard[const Square(3, 7).index] = const ChessPiece(PieceType.rook, PieceColor.black);
        }
      }
    }

    bool wck = whiteCanCastleKingside;
    bool wcq = whiteCanCastleQueenside;
    bool bck = blackCanCastleKingside;
    bool bcq = blackCanCastleQueenside;

    if (move.piece.type == PieceType.king) {
      if (move.piece.color.isWhite) {
        wck = false;
        wcq = false;
      } else {
        bck = false;
        bcq = false;
      }
    } else if (move.piece.type == PieceType.rook) {
      if (move.from == const Square(0, 0)) wcq = false;
      if (move.from == const Square(7, 0)) wck = false;
      if (move.from == const Square(0, 7)) bcq = false;
      if (move.from == const Square(7, 7)) bck = false;
    }

    if (move.to == const Square(0, 0)) wcq = false;
    if (move.to == const Square(7, 0)) wck = false;
    if (move.to == const Square(0, 7)) bcq = false;
    if (move.to == const Square(7, 7)) bck = false;

    Square? newEpTarget;
    if (move.piece.type == PieceType.pawn && (move.to.rank - move.from.rank).abs() == 2) {
      final midRank = (move.to.rank + move.from.rank) ~/ 2;
      newEpTarget = Square(move.from.file, midRank);
    }

    int newHalfmove = halfmoveClock + 1;
    if (move.piece.type == PieceType.pawn || move.isCapture) {
      newHalfmove = 0;
    }

    int newFullmove = fullmoveNumber;
    if (turn.isBlack) {
      newFullmove++;
    }

    return ChessPosition(
      board: nextBoard,
      turn: turn.opponent,
      whiteCanCastleKingside: wck,
      whiteCanCastleQueenside: wcq,
      blackCanCastleKingside: bck,
      blackCanCastleQueenside: bcq,
      enPassantTarget: newEpTarget,
      halfmoveClock: newHalfmove,
      fullmoveNumber: newFullmove,
    );
  }

  ChessMove? findLegalMoveByUci(String uci) {
    if (uci.length < 4) return null;
    if (_cachedUciMap == null) {
      generateLegalMoves();
    }
    return _cachedUciMap![uci.toLowerCase()];
  }

  ChessMove? findLegalMoveBySan(String san) {
    final cleanSan = san.replaceAll(RegExp(r'[x+#\s=!?]'), '');
    final legalMoves = generateLegalMoves();

    for (final m in legalMoves) {
      if (m.san == san) return m;
      final mClean = (m.san ?? '').replaceAll(RegExp(r'[x+#\s=!?]'), '');
      if (mClean == cleanSan) return m;
    }

    if (san == 'O-O' || san == '0-0') {
      return legalMoves.cast<ChessMove?>().firstWhere(
            (m) => m!.isCastling && m.to.file > m.from.file,
            orElse: () => null,
          );
    }
    if (san == 'O-O-O' || san == '0-0-0') {
      return legalMoves.cast<ChessMove?>().firstWhere(
            (m) => m!.isCastling && m.to.file < m.from.file,
            orElse: () => null,
          );
    }

    return null;
  }

  bool isCheckmate() => isCheck() && generateLegalMoves().isEmpty;
  bool isStalemate() => !isCheck() && generateLegalMoves().isEmpty;
  bool isGameOver() => isCheckmate() || isStalemate();
}
