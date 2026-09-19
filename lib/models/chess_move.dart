enum PieceColor {
  white,
  black;

  PieceColor get opponent => this == white ? black : white;
  bool get isWhite => this == white;
  bool get isBlack => this == black;
}

enum PieceType {
  pawn('p', 'P', 100),
  knight('n', 'N', 320),
  bishop('b', 'B', 330),
  rook('r', 'R', 500),
  queen('q', 'Q', 900),
  king('k', 'K', 20000);

  final String charLower;
  final String charUpper;
  final int value;

  const PieceType(this.charLower, this.charUpper, this.value);

  String get sanChar => this == pawn ? '' : charUpper;

  static PieceType? fromChar(String char) {
    switch (char.toLowerCase()) {
      case 'p':
        return PieceType.pawn;
      case 'n':
        return PieceType.knight;
      case 'b':
        return PieceType.bishop;
      case 'r':
        return PieceType.rook;
      case 'q':
        return PieceType.queen;
      case 'k':
        return PieceType.king;
      default:
        return null;
    }
  }
}

class ChessPiece {
  final PieceType type;
  final PieceColor color;

  const ChessPiece(this.type, this.color);

  String get fenChar => color.isWhite ? type.charUpper : type.charLower;

  static ChessPiece? fromFenChar(String char) {
    final type = PieceType.fromChar(char);
    if (type == null) return null;
    final color = char == char.toUpperCase() ? PieceColor.white : PieceColor.black;
    return ChessPiece(type, color);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessPiece &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          color == other.color;

  @override
  int get hashCode => Object.hash(type, color);

  @override
  String toString() => '${color.name} ${type.name}';
}

class Square {
  final int file; // 0..7 (a..h)
  final int rank; // 0..7 (1..8)

  const Square(this.file, this.rank)
      : assert(file >= 0 && file < 8),
        assert(rank >= 0 && rank < 8);

  const Square.fromCoords(this.file, this.rank);

  factory Square.fromIndex(int index) {
    assert(index >= 0 && index < 64);
    return Square(index % 8, index ~/ 8);
  }

  factory Square.fromAlgebraic(String alg) {
    if (alg.length != 2) throw ArgumentError('Invalid algebraic square: $alg');
    final file = alg.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = alg.codeUnitAt(1) - '1'.codeUnitAt(0);
    if (file < 0 || file > 7 || rank < 0 || rank > 7) {
      throw ArgumentError('Square out of bounds: $alg');
    }
    return Square(file, rank);
  }

  int get index => rank * 8 + file;
  String get algebraic => '${String.fromCharCode('a'.codeUnitAt(0) + file)}${rank + 1}';
  bool get isLight => (file + rank) % 2 != 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Square && runtimeType == other.runtimeType && file == other.file && rank == other.rank;

  @override
  int get hashCode => Object.hash(file, rank);

  @override
  String toString() => algebraic;
}

class ChessMove {
  final Square from;
  final Square to;
  final PieceType? promotion;
  final bool isCapture;
  final bool isCastling;
  final bool isEnPassant;
  final ChessPiece piece;
  final ChessPiece? capturedPiece;
  String? san;

  ChessMove({
    required this.from,
    required this.to,
    this.promotion,
    this.isCapture = false,
    this.isCastling = false,
    this.isEnPassant = false,
    required this.piece,
    this.capturedPiece,
    this.san,
  });

  String get uci {
    final promo = promotion != null ? promotion!.charLower : '';
    return '${from.algebraic}${to.algebraic}$promo';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessMove &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          promotion == other.promotion;

  @override
  int get hashCode => Object.hash(from, to, promotion);

  @override
  String toString() => san ?? uci;
}
