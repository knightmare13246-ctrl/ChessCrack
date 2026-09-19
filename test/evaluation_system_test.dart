import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/controllers/evaluation_controller.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/utils/score_adapters.dart';

void main() {
  final pos = ChessPosition.initial();
  final dummyMove = pos.findLegalMoveByUci('e2e4')!;

  group('1. Stockfish Centipawn Conversion & Lichess Formula Verification', () {
    const adapter = StockfishScoreAdapter();

    test('0 cp results in exactly 50.0% neutral score', () {
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        scoreCp: 0,
      );

      expect(eval.normalized.whiteExpectedScore, closeTo(50.0, 0.01));
      expect(eval.normalized.whiteCentipawns, 0);
      expect(eval.normalized.barLabel, '0.0');
      expect(eval.normalized.displayFactor, closeTo(0.50, 0.001));
      expect(eval.formattedScore, '0.00');
    });

    test('+100 cp results in 59.1% White expected score (Lichess sigmoid)', () {
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        scoreCp: 100,
      );

      // 50 + 50 * (2 / (1 + exp(-0.00368208 * 100)) - 1) = 59.10%
      expect(eval.normalized.whiteExpectedScore, closeTo(59.10, 0.05));
      expect(eval.normalized.whiteCentipawns, 100);
      expect(eval.normalized.barLabel, '+1.0');
      expect(eval.normalized.displayFactor, closeTo(0.591, 0.005));
      expect(eval.formattedScore, '+1.00');
    });

    test('-100 cp results in 40.9% White expected score (symmetrical)', () {
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        scoreCp: -100,
      );

      expect(eval.normalized.whiteExpectedScore, closeTo(40.90, 0.05));
      expect(eval.normalized.whiteCentipawns, -100);
      expect(eval.normalized.barLabel, '-1.0');
      expect(eval.normalized.displayFactor, closeTo(0.409, 0.005));
      expect(eval.formattedScore, '-1.00');
    });

    test('+300 cp results in 75.1% White expected score', () {
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        scoreCp: 300,
      );

      expect(eval.normalized.whiteExpectedScore, closeTo(75.11, 0.05));
      expect(eval.normalized.whiteCentipawns, 300);
      expect(eval.normalized.barLabel, '+3.0');
      expect(eval.normalized.displayFactor, closeTo(0.751, 0.005));
      expect(eval.formattedScore, '+3.00');
    });

    test('+1000 cp results in 97.5% White expected score', () {
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        scoreCp: 1000,
      );

      expect(eval.normalized.whiteExpectedScore, closeTo(97.54, 0.1));
      expect(eval.normalized.whiteCentipawns, 1000);
      expect(eval.normalized.barLabel, '+10.0');
      expect(eval.normalized.displayFactor, closeTo(0.975, 0.01));
    });

    test('Perspective inversion: Black to move with +100 cp translates to -1.00 White', () {
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: false, // Black's turn
        multipv: 1,
        scoreCp: 100, // Black engine evaluates +100 cp for Black
      );

      // From White's perspective: White is down 100 cp (-1.00)
      expect(eval.normalized.whiteCentipawns, -100);
      expect(eval.normalized.whiteExpectedScore, closeTo(40.90, 0.05));
      expect(eval.normalized.barLabel, '-1.0');
      expect(eval.formattedScore, '-1.00');
    });
  });

  group('2. Lc0 WDL Expected Score & The Screenshot Bug Reproduction', () {
    const adapter = Lc0ScoreAdapter();

    test('Bug Reproduction: Raw WDL [251, 569, 180] produces 53.55% expected score, NOT 25%', () {
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        scoreCp: 26,
        wdl: [251, 569, 180],
      );

      // Raw metrics preserved untouched for diagnostics
      expect(eval.normalized.rawWdl, [251, 569, 180]);
      expect(eval.normalized.rawWinProbability, closeTo(25.1, 0.01));
      expect(eval.normalized.drawProbability, closeTo(56.9, 0.01));
      expect(eval.normalized.blackWinProbability, closeTo(18.0, 0.01));

      // The authoritative White expected score: (251 + 0.5 * 569) / 10 = 53.55%
      expect(eval.normalized.whiteExpectedScore, closeTo(53.55, 0.01));
      expect(eval.normalized.displayFactor, closeTo(0.5355, 0.001));

      // The old bug was returning 25% because it read rawWinProbability
      // Verify that whiteExpectedScore is NOT 25.1%
      expect(eval.normalized.whiteExpectedScore, isNot(closeTo(25.1, 1.0)));

      // Displayed label and formatted scores agree
      expect(eval.normalized.barLabel, '53.5%');
      expect(eval.formattedScore, '53.5%');
    });

    test('Black to move with WDL [600, 300, 100] translates to 25.0% White expected score', () {
      final eval = adapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: false, // Black's turn
        multipv: 1,
        wdl: [600, 300, 100], // Black evaluates 60% win, 30% draw, 10% loss
      );

      // Black expected score is 60 + 15 = 75%
      // White expected score is 10 + 15 = 25%
      expect(eval.normalized.whiteExpectedScore, closeTo(25.0, 0.01));
      expect(eval.normalized.whiteWinProbability, closeTo(10.0, 0.01));
      expect(eval.normalized.drawProbability, closeTo(30.0, 0.01));
      expect(eval.normalized.blackWinProbability, closeTo(60.0, 0.01));
      expect(eval.normalized.barLabel, '25.0%');
      expect(eval.normalized.displayFactor, closeTo(0.25, 0.001));
    });
  });

  group('3. Mate State Modeling and Presentation', () {
    const sfAdapter = StockfishScoreAdapter();

    test('White to move, White mates in 2: M2 at 100% factor', () {
      final eval = sfAdapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        scoreMate: 2,
      );

      expect(eval.normalized.mateState, MateState.whiteMate);
      expect(eval.normalized.mateInMoves, 2);
      expect(eval.normalized.whiteExpectedScore, 100.0);
      expect(eval.normalized.displayFactor, 1.0);
      expect(eval.normalized.barLabel, 'M2');
      expect(eval.formattedScore, 'M2');
    });

    test('White to move, Black mates in 3: -M3 at 0% factor', () {
      final eval = sfAdapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: true,
        multipv: 1,
        scoreMate: -3,
      );

      expect(eval.normalized.mateState, MateState.blackMate);
      expect(eval.normalized.mateInMoves, 3);
      expect(eval.normalized.whiteExpectedScore, 0.0);
      expect(eval.normalized.displayFactor, 0.0);
      expect(eval.normalized.barLabel, '-M3');
      expect(eval.formattedScore, '-M3');
    });

    test('Black to move, Black mates in 1: -M1 at 0% factor', () {
      final eval = sfAdapter.createEvaluation(
        move: dummyMove,
        positionRevision: 1,
        analysisRequestId: 1,
        isWhiteTurn: false,
        multipv: 1,
        scoreMate: 1, // Positive from Black perspective
      );

      expect(eval.normalized.mateState, MateState.blackMate);
      expect(eval.normalized.mateInMoves, 1);
      expect(eval.normalized.whiteExpectedScore, 0.0);
      expect(eval.normalized.displayFactor, 0.0);
      expect(eval.normalized.barLabel, '-M1');
      expect(eval.formattedScore, '-M1');
    });
  });

  group('4. EvaluationController Temporal Stabilization & Safety', () {
    test('Headless EvaluationController updates displayedPercentage accurately', () {
      final controller = EvaluationController();

      controller.updateEvaluation(const NormalizedEvaluation(
        whiteExpectedScore: 53.55,
        engineType: EngineType.lc0,
        positionRevision: 1,
        analysisRequestId: 1,
        fen: 'startpos',
        isEngineEnabled: true,
      ));

      expect(controller.displayedPercentage, closeTo(53.55, 0.01));
      expect(controller.displayFactor, closeTo(0.5355, 0.001));
      expect(controller.barLabel, '53.5%');
    });

    test('Deadband filter suppresses micro-jitter below 0.20%', () {
      final controller = EvaluationController();

      controller.updateEvaluation(const NormalizedEvaluation(
        whiteExpectedScore: 53.50,
        engineType: EngineType.lc0,
        positionRevision: 1,
        analysisRequestId: 1,
        fen: 'startpos',
        isEngineEnabled: true,
      ));

      expect(controller.displayedPercentage, closeTo(53.50, 0.01));

      // Micro-jitter of 0.12% (within 0.20% deadband)
      controller.updateEvaluation(const NormalizedEvaluation(
        whiteExpectedScore: 53.62,
        engineType: EngineType.lc0,
        positionRevision: 1,
        analysisRequestId: 1,
        fen: 'startpos',
        isEngineEnabled: true,
      ));

      // Target is recorded for diagnostics, but displayed value does not jitter
      expect(controller.rawEvaluation.whiteExpectedScore, closeTo(53.62, 0.01));
      expect(controller.displayedPercentage, closeTo(53.50, 0.01));
    });

    test('Stale position revision or requestId is rejected', () {
      final controller = EvaluationController();

      controller.updateEvaluation(const NormalizedEvaluation(
        whiteExpectedScore: 55.0,
        engineType: EngineType.lc0,
        positionRevision: 2,
        analysisRequestId: 2,
        fen: 'pos2',
        isEngineEnabled: true,
      ));

      // Stale update from revision 1 arrives late
      controller.updateEvaluation(const NormalizedEvaluation(
        whiteExpectedScore: 30.0,
        engineType: EngineType.lc0,
        positionRevision: 1,
        analysisRequestId: 1,
        fen: 'pos1',
        isEngineEnabled: true,
      ));

      // Stale update discarded
      expect(controller.displayedPercentage, closeTo(55.0, 0.01));
      expect(controller.positionRevision, 2);
    });

    test('Engine OFF triggers immediate hard reset to 50.0%', () {
      final controller = EvaluationController();

      controller.updateEvaluation(const NormalizedEvaluation(
        whiteExpectedScore: 85.0,
        engineType: EngineType.stockfish,
        positionRevision: 1,
        analysisRequestId: 1,
        fen: 'winning_pos',
        isEngineEnabled: true,
      ));

      expect(controller.displayedPercentage, closeTo(85.0, 0.01));

      // Engine disabled
      controller.updateEvaluation(const NormalizedEvaluation(
        whiteExpectedScore: 85.0,
        engineType: EngineType.stockfish,
        positionRevision: 1,
        analysisRequestId: 1,
        fen: 'winning_pos',
        isEngineEnabled: false,
      ));

      expect(controller.displayedPercentage, 50.0);
      expect(controller.displayFactor, 0.50);
      expect(controller.barLabel, '0.0');
    });
  });
}
