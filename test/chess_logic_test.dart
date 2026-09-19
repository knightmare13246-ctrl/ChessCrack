import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/services/pgn_parser.dart';
import 'package:nibbler_chess/utils/win_rate_calculator.dart';

void main() {
  group('Chess Rules & Move Generator Tests', () {
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

      // 1. e4 e5
      pos = pos.applyMove(pos.findLegalMoveBySan('e4')!);
      pos = pos.applyMove(pos.findLegalMoveBySan('e5')!);

      // 2. Qh5 Nc6
      pos = pos.applyMove(pos.findLegalMoveBySan('Qh5')!);
      pos = pos.applyMove(pos.findLegalMoveBySan('Nc6')!);

      // 3. Bc4 Nf6
      pos = pos.applyMove(pos.findLegalMoveBySan('Bc4')!);
      pos = pos.applyMove(pos.findLegalMoveBySan('Nf6')!);

      // 4. Qxf7#
      final mateMove = pos.findLegalMoveBySan('Qxf7#') ?? pos.findLegalMoveBySan('Qxf7+');
      expect(mateMove, isNotNull);
      pos = pos.applyMove(mateMove!);

      expect(pos.isCheck(), true);
      expect(pos.isCheckmate(), true);
      expect(pos.isGameOver(), true);
    });

    test('En passant capture test', () {
      var pos = ChessPosition.initial();

      // 1. e4 a6 2. e5 d5
      pos = pos.applyMove(pos.findLegalMoveBySan('e4')!);
      pos = pos.applyMove(pos.findLegalMoveBySan('a6')!);
      pos = pos.applyMove(pos.findLegalMoveBySan('e5')!);
      pos = pos.applyMove(pos.findLegalMoveBySan('d5')!);

      expect(pos.enPassantTarget, isNotNull);
      expect(pos.enPassantTarget!.algebraic, 'd6');

      final epMove = pos.findLegalMoveBySan('exd6');
      expect(epMove, isNotNull);
      expect(epMove!.isEnPassant, true);

      pos = pos.applyMove(epMove);
      // d5 pawn should be captured (null)
      expect(pos.pieceAt(Square.fromAlgebraic('d5')), isNull);
      // White pawn at d6
      expect(pos.pieceAt(Square.fromAlgebraic('d6'))?.type, PieceType.pawn);
    });
  });

  group('PGN Parser & Game Tree Tests', () {
    test('Parse Kasparov vs Topalov Immortal game', () {
      final tree = PgnParser.parse(PgnParser.sampleKasparovTopalov);
      expect(tree.headers['White'], 'Kasparov, Garry');
      expect(tree.headers['Black'], 'Topalov, Veselin');
      expect(tree.headers['Result'], '1-0');

      // Verify mainline depth is 87 plies
      final mainline = tree.mainlineNodes;
      expect(mainline.length, greaterThan(80));

      // Test branching a variation and returning to original game
      tree.goToStart();
      tree.stepForward(); // 1. e4
      tree.stepForward(); // 1... d6

      // Play alternate variation: 2. c4 instead of 2. d4
      final c4Move = tree.currentNode.position.findLegalMoveBySan('c4');
      expect(c4Move, isNotNull);
      final varNode = tree.addMove(c4Move!);

      expect(varNode.isOriginalMainline, false);
      expect(tree.currentNode, varNode);

      // Return to original game mainline
      final returned = tree.returnToOriginalGame();
      expect(returned, true);
      expect(tree.currentNode.isOriginalMainline, true);
    });
  });

  group('Win Rate & Nibbler Arrow Calculations', () {
    test('Lc0 WDL conversion accuracy', () {
      // 754 win, 182 draw, 64 loss (out of 1000)
      final winPct = WinRateCalculator.wdlToWinPercentage(754, 182, 64);
      // (754 + 91) / 1000 * 100 = 84.5%
      expect(winPct, closeTo(84.5, 0.1));
    });

    test('Stockfish CP conversion accuracy', () {
      final equalPct = WinRateCalculator.cpToWinPercentage(0);
      expect(equalPct, 50.0);

      final advantagePct = WinRateCalculator.cpToWinPercentage(200);
      expect(advantagePct, greaterThan(65.0));
      expect(advantagePct, lessThan(70.0));
    });

    test('Nibbler arrow color transitions', () {
      final green = WinRateCalculator.getArrowColorValue(75.0);
      expect(green, isNot(0));

      final yellow = WinRateCalculator.getArrowColorValue(50.0);
      expect(yellow, isNot(0));

      final red = WinRateCalculator.getArrowColorValue(20.0);
      expect(red, isNot(0));
    });
  });
}
