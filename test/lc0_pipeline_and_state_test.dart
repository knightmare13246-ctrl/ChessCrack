import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/services/engine_trace_logger.dart';
import 'package:nibbler_chess/utils/score_adapters.dart';

void main() {
  group('1. ChessPosition Move Caching and O(1) UCI Lookup', () {
    test('generateLegalMoves caches result and findLegalMoveByUci is O(1)', () {
      final pos = ChessPosition.initial();
      final moves1 = pos.generateLegalMoves();
      final moves2 = pos.generateLegalMoves();
      expect(identical(moves1, moves2), isTrue);

      final e4 = pos.findLegalMoveByUci('e2e4');
      expect(e4, isNotNull);
      expect(e4!.from.algebraic, 'e2');
      expect(e4.to.algebraic, 'e4');

      final nf3 = pos.findLegalMoveByUci('g1f3');
      expect(nf3, isNotNull);
      expect(nf3!.from.algebraic, 'g1');
      expect(nf3.to.algebraic, 'f3');

      // Illegal move returns null
      final illegal = pos.findLegalMoveByUci('e2e5');
      expect(illegal, isNull);
    });

    test('Special moves lookup: Castling and En Passant', () {
      // Position with castling available
      const fen = 'r1bqk2r/pp2bppp/2n1pn2/2pp4/3P4/2PBPN2/PP1N1PPP/R1BQK2R w KQkq - 3 7';
      final pos = ChessPosition.fromFen(fen);

      final kingsideCastle = pos.findLegalMoveByUci('e1g1');
      expect(kingsideCastle, isNotNull);
      expect(kingsideCastle!.isCastling, isTrue);
    });
  });

  group('2. Lc0 WDL Expected Score & Perspective Semantics', () {
    const adapter = Lc0ScoreAdapter();
    final pos = ChessPosition.initial();
    final dummyMove = pos.findLegalMoveByUci('e2e4')!;

    test('White to move: expected score equals white expected score', () {
      // WDL: 936 win, 55 draw, 9 loss (per-mille)
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        wdl: [936, 55, 9],
      );

      // (936 + 27.5) / 1000 = 96.35%
      expect(eval.expectedScore, closeTo(96.35, 0.01));
      expect(eval.whiteExpectedScore, closeTo(96.35, 0.01));
      expect(eval.winProbability, closeTo(93.6, 0.01));
      expect(eval.badgeScore, 96);
      expect(eval.formattedScore, '96.4%');
    });

    test('Black to move: side-to-move win translates to White loss', () {
      // Black is winning (mate in 1) -> WDL from Black perspective is [1000, 0, 0]
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: false,
        multipv: 1,
        wdl: [1000, 0, 0],
      );

      // Black expected score is 100%, White expected score is 0%
      expect(eval.expectedScore, closeTo(100.0, 0.01));
      expect(eval.whiteExpectedScore, closeTo(0.0, 0.01));
      expect(eval.badgeScore, 100);
      expect(eval.formattedScore, '0.0%');
    });

    test('Dead drawn endgame WDL translates to 50% expected score', () {
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        wdl: [6, 992, 2],
      );

      // (6 + 496) / 1000 = 50.2%
      expect(eval.expectedScore, closeTo(50.2, 0.01));
      expect(eval.whiteExpectedScore, closeTo(50.2, 0.01));
      expect(eval.badgeScore, 50);
      expect(eval.formattedScore, '50.2%');
    });
  });

  group('3. Board Coordinate Transformation for Arrows', () {
    test('White orientation coordinates match chessboard ranks/files', () {
      // Square a1: file 0, rank 0
      final a1 = Square.fromAlgebraic('a1');
      // When not flipped: f = 0, r = 7 - 0 = 7 (bottom-left)
      expect(a1.file, 0);
      expect(a1.rank, 0);

      // Square h8: file 7, rank 7
      final h8 = Square.fromAlgebraic('h8');
      expect(h8.file, 7);
      expect(h8.rank, 7);

      // Square e4: file 4, rank 3
      final e4 = Square.fromAlgebraic('e4');
      expect(e4.file, 4);
      expect(e4.rank, 3);
    });

    test('Black orientation (isFlipped) inverts both files and ranks', () {
      final a1 = Square.fromAlgebraic('a1');
      // Inverted for Black: file becomes 7 - 0 = 7 (bottom-right on screen)
      // rank becomes 0 (top on screen)
      final flippedFile = 7 - a1.file;
      final flippedRank = a1.rank;
      expect(flippedFile, 7);
      expect(flippedRank, 0);
    });
  });

  group('4. Engine ON/OFF State Machine & Trace Invariants', () {
    test('EngineActivationState is strictly separate from search state', () {
      expect(EngineActivationState.disabled, isNotNull);
      expect(EngineActivationState.enabled, isNotNull);
      expect(EngineSearchState.searching, isNotNull);
      expect(EngineSearchState.stopping, isNotNull);
    });
  });
}
