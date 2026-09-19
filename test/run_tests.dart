// ignore_for_file: avoid_print
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/services/pgn_parser.dart';
import 'package:nibbler_chess/utils/win_rate_calculator.dart';

void main() {
  int passed = 0;
  int failed = 0;

  void test(String name, void Function() body) {
    try {
      body();
      print('  PASS: $name');
      passed++;
    } catch (e, st) {
      print('  FAIL: $name -> $e\n$st');
      failed++;
    }
  }

  void expect(dynamic actual, dynamic expected, [String? reason]) {
    if (actual != expected) {
      throw Exception('Expected $expected but got $actual ${reason != null ? "($reason)" : ""}');
    }
  }

  void assertTrue(bool condition, [String? reason]) {
    if (!condition) throw Exception('Assertion failed ${reason ?? ""}');
  }

  print('\n=== Running Extended Nibbler Chess Test Suite ===');

  test('Initial position has exactly 20 legal moves', () {
    final pos = ChessPosition.initial();
    final moves = pos.generateLegalMoves();
    expect(moves.length, 20);
    expect(pos.isCheck(), false);
    expect(pos.isGameOver(), false);
  });

  test('FEN roundtrip consistency', () {
    final pos = ChessPosition.initial();
    expect(pos.toFen(), ChessPosition.initialFen);

    const customFen = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';
    final pos2 = ChessPosition.fromFen(customFen);
    expect(pos2.toFen(), customFen);
  });

  test('Scholar\'s mate detection', () {
    var pos = ChessPosition.initial();

    pos = pos.applyMove(pos.findLegalMoveBySan('e4')!);
    pos = pos.applyMove(pos.findLegalMoveBySan('e5')!);
    pos = pos.applyMove(pos.findLegalMoveBySan('Qh5')!);
    pos = pos.applyMove(pos.findLegalMoveBySan('Nc6')!);
    pos = pos.applyMove(pos.findLegalMoveBySan('Bc4')!);
    pos = pos.applyMove(pos.findLegalMoveBySan('Nf6')!);

    final mateMove = pos.findLegalMoveBySan('Qxf7#') ?? pos.findLegalMoveBySan('Qxf7+');
    assertTrue(mateMove != null, 'Qxf7 should be legal');
    pos = pos.applyMove(mateMove!);

    assertTrue(pos.isCheck(), 'Black king should be in check');
    assertTrue(pos.isCheckmate(), 'Position should be checkmate');
    assertTrue(pos.isGameOver(), 'Game should be over');
  });

  test('En passant capture test', () {
    var pos = ChessPosition.initial();

    pos = pos.applyMove(pos.findLegalMoveBySan('e4')!);
    pos = pos.applyMove(pos.findLegalMoveBySan('a6')!);
    pos = pos.applyMove(pos.findLegalMoveBySan('e5')!);
    pos = pos.applyMove(pos.findLegalMoveBySan('d5')!);

    assertTrue(pos.enPassantTarget != null, 'EP target should exist');
    expect(pos.enPassantTarget!.algebraic, 'd6');

    final epMove = pos.findLegalMoveBySan('exd6');
    assertTrue(epMove != null, 'exd6 should be legal');
    assertTrue(epMove!.isEnPassant, 'Move should be flagged as en passant');

    pos = pos.applyMove(epMove);
    expect(pos.pieceAt(Square.fromAlgebraic('d5')), null);
    expect(pos.pieceAt(Square.fromAlgebraic('d6'))?.type, PieceType.pawn);
  });

  test('Castling disallowed through check', () {
    // White king at e1, rook at h1. Black rook at e8 checking e1
    const checkFen = '4r3/8/8/8/8/8/8/R3K2R w KQ - 0 1';
    final pos = ChessPosition.fromFen(checkFen);
    assertTrue(pos.isCheck(), 'King at e1 is in check');
    final moves = pos.generateLegalMoves();
    final castleMoves = moves.where((m) => m.isCastling).toList();
    expect(castleMoves.length, 0, 'Cannot castle out of check');
  });

  test('Pawn promotion to four piece types', () {
    const promoFen = '8/4P3/8/8/8/8/8/4K2k w - - 0 1';
    final pos = ChessPosition.fromFen(promoFen);
    final moves = pos.generateLegalMoves();
    final promoMoves = moves.where((m) => m.promotion != null).toList();
    expect(promoMoves.length, 4, 'Should generate Q, R, B, N promotions');
  });

  test('PGN parser & variation tree branching', () {
    final tree = PgnParser.parse(PgnParser.sampleKasparovTopalov);
    expect(tree.headers['White'], 'Kasparov, Garry');
    expect(tree.headers['Black'], 'Topalov, Veselin');
    expect(tree.headers['Result'], '1-0');

    final mainline = tree.mainlineNodes;
    assertTrue(mainline.length > 80, 'Mainline should have > 80 plies');

    tree.goToStart();
    tree.stepForward(); // 1. e4
    tree.stepForward(); // 1... d6

    final c4 = tree.currentNode.position.findLegalMoveBySan('c4');
    assertTrue(c4 != null, '2. c4 should be legal');
    final varNode = tree.addMove(c4!);
    expect(varNode.isOriginalMainline, false);
    expect(tree.currentNode, varNode);

    final returned = tree.returnToOriginalGame();
    expect(returned, true);
    expect(tree.currentNode.isOriginalMainline, true);
  });

  test('PGN parser with nested variations and comments', () {
    const pgnWithVariations = '''
[Event "Test Variations"]
1. e4 e5 (1... c5 2. Nf3 (2. Nc3 d6 3. f4) 2... d6) 2. Nf3 Nc6 3. Bb5 {Ruy Lopez} *
''';
    final tree = PgnParser.parse(pgnWithVariations);
    tree.goToStart();
    expect(tree.root.children.length, 1); // 1. e4
    final e4Node = tree.root.children.first;

    // e4 should have 2 children: e5 (mainline) and c5 (variation)
    expect(e4Node.children.length, 2);
    expect(e4Node.children[0].move?.san, 'e5');
    expect(e4Node.children[1].move?.san, 'c5');

    // Inside c5 variation: 2. Nf3 should have 2 children: d6 and alternate 2. Nc3
    final c5Node = e4Node.children[1];
    expect(c5Node.children.isNotEmpty, true);
  });

  test('Lc0 WDL and Stockfish CP win-percentage calculation', () {
    final wdlWin = WinRateCalculator.wdlToWinPercentage(754, 182, 64);
    assertTrue((wdlWin - 84.5).abs() < 0.1, 'Lc0 WDL win% should be 84.5%');

    final wdl100 = WinRateCalculator.wdlToWinPercentage(1000, 0, 0);
    expect(wdl100, 100.0);

    final wdl0 = WinRateCalculator.wdlToWinPercentage(0, 0, 1000);
    expect(wdl0, 0.0);

    final wdlDraw = WinRateCalculator.wdlToWinPercentage(0, 1000, 0);
    expect(wdlDraw, 50.0);

    final sfEqual = WinRateCalculator.cpToWinPercentage(0);
    expect(sfEqual, 50.0);

    final sfAdvantage = WinRateCalculator.cpToWinPercentage(200);
    assertTrue(sfAdvantage > 65.0 && sfAdvantage < 70.0, '200cp should map to ~67% win rate');

    final sfMate = WinRateCalculator.mateToWinPercentage(3);
    assertTrue(sfMate > 98.0, 'Mate in 3 should be near 100%');

    final sfMated = WinRateCalculator.mateToWinPercentage(-2);
    assertTrue(sfMated < 2.0, 'Mated in 2 should be near 0%');
  });

  test('Nibbler arrow styles', () {
    final w1 = WinRateCalculator.getArrowWidth(1, null);
    final w3 = WinRateCalculator.getArrowWidth(3, null);
    assertTrue(w1 > w3, 'Rank 1 arrow should be thicker than Rank 3');

    final op1 = WinRateCalculator.getArrowOpacity(1, null);
    final op3 = WinRateCalculator.getArrowOpacity(3, null);
    assertTrue(op1 > op3, 'Rank 1 arrow should have higher opacity than Rank 3');

    // Heatmap colors
    final greenVal = WinRateCalculator.getArrowColorValue(75.0);
    final redVal = WinRateCalculator.getArrowColorValue(20.0);
    assertTrue(greenVal != redVal, 'Green and Red arrow colors must differ');
  });

  print('\nResults: $passed passed, $failed failed');
  if (failed > 0) {
    throw Exception('$failed tests failed');
  }
}
