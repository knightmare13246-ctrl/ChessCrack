import 'dart:math' as math;
import '../models/chess_move.dart';
import '../models/engine_analysis.dart';
export '../models/normalized_evaluation.dart' show NormalizedEvaluation, MateState;

/// Authoritative evaluation for a candidate move that preserves the true semantics
/// of the underlying engine (Stockfish alpha-beta vs Lc0 neural/MCTS).
class MoveEvaluation {
  final ChessMove move;
  final int positionRevision;
  final int analysisRequestId;
  final EngineType sourceEngine;
  final int multipv;
  final NormalizedEvaluation normalized;

  final double winProbability;        // 0.0 to 100.0, side-to-move perspective (raw win %)
  final double whiteWinProbability;   // 0.0 to 100.0, White's perspective
  final double expectedScore;         // 0.0 to 100.0, side-to-move perspective (Win + 0.5*Draw)
  final double whiteExpectedScore;    // 0.0 to 100.0, White's perspective
  final double? drawProbability;      // 0.0 to 100.0
  final double? lossProbability;      // 0.0 to 100.0
  final int? scoreCp;
  final int? scoreMate;
  final int? visits;
  final int? nodes;
  final int? nps;
  final int depth;
  final double? policyPercentage;
  final double? visitPercentage;
  final double? utility;
  final List<String> pvUci;
  final List<String> pvSan;
  final DateTime timestamp;

  MoveEvaluation({
    required this.move,
    required this.positionRevision,
    required this.analysisRequestId,
    required this.sourceEngine,
    required this.multipv,
    required this.normalized,
    required this.winProbability,
    required this.whiteWinProbability,
    double? expectedScore,
    double? whiteExpectedScore,
    this.drawProbability,
    this.lossProbability,
    this.scoreCp,
    this.scoreMate,
    this.visits,
    this.nodes,
    this.nps,
    this.depth = 0,
    this.policyPercentage,
    this.visitPercentage,
    this.utility,
    this.pvUci = const [],
    this.pvSan = const [],
    DateTime? timestamp,
  })  : expectedScore = expectedScore ?? winProbability,
        whiteExpectedScore = whiteExpectedScore ?? normalized.whiteExpectedScore,
        timestamp = timestamp ?? DateTime.now();

  /// Badge score formatted as integer percentage for the move arrow badge
  int get badgeScore => expectedScore.round().clamp(0, 100);

  /// Formatted score for display in analysis panels (comes from the exact normalized object)
  String get formattedScore => normalized.formattedNumericScore;
}

/// Abstract adapter for engine score semantics
abstract class EngineScoreAdapter {
  MoveEvaluation createEvaluation({
    required ChessMove move,
    required int positionRevision,
    required int analysisRequestId,
    required bool isWhiteTurn,
    required int multipv,
    int? scoreCp,
    int? scoreMate,
    List<int>? wdl,
    int? nodes,
    int? nps,
    int depth = 0,
    double? visitPct,
    double? policyPct,
    double? utility,
    List<String> pvUci = const [],
    List<String> pvSan = const [],
  });
}

/// Specialized adapter for Stockfish alpha-beta search
class StockfishScoreAdapter implements EngineScoreAdapter {
  const StockfishScoreAdapter();

  // Logistic win-rate model calibration constant for Stockfish
  static const double _stockfishK = 0.00368208;

  @override
  MoveEvaluation createEvaluation({
    required ChessMove move,
    required int positionRevision,
    required int analysisRequestId,
    required bool isWhiteTurn,
    required int multipv,
    int? scoreCp,
    int? scoreMate,
    List<int>? wdl,
    int? nodes,
    int? nps,
    int depth = 0,
    double? visitPct,
    double? policyPct,
    double? utility,
    List<String> pvUci = const [],
    List<String> pvSan = const [],
  }) {
    double winPct = 50.0;
    double expectedScore = 50.0;
    double? drawProb;
    double? lossProb;

    MateState mateState = MateState.none;
    int? mateInMoves;
    int? whiteCp = scoreCp != null ? (isWhiteTurn ? scoreCp : -scoreCp) : null;
    double whiteExpectedScore = 50.0;
    double whiteWinPct = 50.0;
    double blackWinPct = 50.0;

    if (scoreMate != null) {
      mateInMoves = scoreMate.abs();
      if (isWhiteTurn) {
        mateState = scoreMate > 0 ? MateState.whiteMate : MateState.blackMate;
      } else {
        mateState = scoreMate > 0 ? MateState.blackMate : MateState.whiteMate;
      }

      whiteExpectedScore = mateState == MateState.whiteMate ? 100.0 : 0.0;
      whiteWinPct = whiteExpectedScore;
      blackWinPct = 100.0 - whiteExpectedScore;
      drawProb = 0.0;
      expectedScore = scoreMate > 0 ? 100.0 : 0.0;
      winPct = expectedScore;
      lossProb = 100.0 - expectedScore;
    } else if (scoreCp != null) {
      // Stockfish logistic win-chance curve
      final double winProb = 2.0 / (1.0 + math.exp(-_stockfishK * scoreCp)) - 1.0;
      winPct = (50.0 + (50.0 * winProb)).clamp(0.0, 100.0);
      expectedScore = winPct;
      lossProb = (100.0 - winPct).clamp(0.0, 100.0);
      drawProb = 0.0;

      // Authoritative White perspective calculation using whiteCp
      final double whiteWinProb = 2.0 / (1.0 + math.exp(-_stockfishK * whiteCp!)) - 1.0;
      whiteExpectedScore = (50.0 + (50.0 * whiteWinProb)).clamp(0.0, 100.0);
      whiteWinPct = whiteExpectedScore;
      blackWinPct = 100.0 - whiteExpectedScore;
    }

    // Preserve real WDL if emitted by engine (e.g. UCI_ShowWDL)
    if (wdl != null && wdl.length >= 3) {
      final total = wdl[0] + wdl[1] + wdl[2];
      if (total > 0) {
        final rawW = (wdl[0] / total * 100.0).clamp(0.0, 100.0);
        final rawD = (wdl[1] / total * 100.0).clamp(0.0, 100.0);
        final rawL = (wdl[2] / total * 100.0).clamp(0.0, 100.0);
        drawProb = rawD;
        if (isWhiteTurn) {
          whiteWinPct = rawW;
          blackWinPct = rawL;
        } else {
          whiteWinPct = rawL;
          blackWinPct = rawW;
        }
      }
    }

    final normalized = NormalizedEvaluation(
      whiteExpectedScore: whiteExpectedScore,
      whiteWinProbability: whiteWinPct,
      drawProbability: drawProb,
      blackWinProbability: blackWinPct,
      whiteCentipawns: whiteCp,
      mateState: mateState,
      mateInMoves: mateInMoves,
      rawScoreCp: scoreCp,
      rawScoreMate: scoreMate,
      rawWdl: wdl,
      rawWinProbability: (wdl != null && wdl.length >= 3)
          ? (wdl[0] / (wdl[0] + wdl[1] + wdl[2]) * 100.0)
          : winPct,
      rawExpectedScore: expectedScore,
      engineType: EngineType.stockfish,
      positionRevision: positionRevision,
      analysisRequestId: analysisRequestId,
      fen: '',
      isEngineEnabled: true,
    );

    return MoveEvaluation(
      move: move,
      positionRevision: positionRevision,
      analysisRequestId: analysisRequestId,
      sourceEngine: EngineType.stockfish,
      multipv: multipv,
      normalized: normalized,
      winProbability: winPct,
      whiteWinProbability: whiteWinPct,
      expectedScore: expectedScore,
      whiteExpectedScore: whiteExpectedScore,
      drawProbability: drawProb,
      lossProbability: lossProb,
      scoreCp: scoreCp,
      scoreMate: scoreMate,
      nodes: nodes,
      nps: nps,
      depth: depth,
      pvUci: pvUci,
      pvSan: pvSan,
    );
  }
}

/// Specialized adapter for Lc0 neural-network MCTS search
class Lc0ScoreAdapter implements EngineScoreAdapter {
  const Lc0ScoreAdapter();

  @override
  MoveEvaluation createEvaluation({
    required ChessMove move,
    required int positionRevision,
    required int analysisRequestId,
    required bool isWhiteTurn,
    required int multipv,
    int? scoreCp,
    int? scoreMate,
    List<int>? wdl,
    int? nodes,
    int? nps,
    int depth = 0,
    double? visitPct,
    double? policyPct,
    double? utility,
    List<String> pvUci = const [],
    List<String> pvSan = const [],
  }) {
    double winPct = 50.0;
    double expectedScore = 50.0;
    double? drawProb;
    double? lossProb;

    MateState mateState = MateState.none;
    int? mateInMoves;
    int? whiteCp = scoreCp != null ? (isWhiteTurn ? scoreCp : -scoreCp) : null;
    double whiteExpectedScore = 50.0;
    double whiteWinPct = 50.0;
    double blackWinPct = 50.0;

    if (scoreMate != null) {
      mateInMoves = scoreMate.abs();
      if (isWhiteTurn) {
        mateState = scoreMate > 0 ? MateState.whiteMate : MateState.blackMate;
      } else {
        mateState = scoreMate > 0 ? MateState.blackMate : MateState.whiteMate;
      }
      whiteExpectedScore = mateState == MateState.whiteMate ? 100.0 : 0.0;
      whiteWinPct = whiteExpectedScore;
      blackWinPct = 100.0 - whiteExpectedScore;
      drawProb = 0.0;
      expectedScore = scoreMate > 0 ? 100.0 : 0.0;
      winPct = expectedScore;
      lossProb = 100.0 - expectedScore;
    } else if (wdl != null && wdl.length >= 3) {
      // Lc0 native WDL is per-mille: [w, d, l] relative to side-to-move
      final total = wdl[0] + wdl[1] + wdl[2];
      if (total > 0) {
        winPct = (wdl[0] / total * 100.0).clamp(0.0, 100.0);
        drawProb = (wdl[1] / total * 100.0).clamp(0.0, 100.0);
        lossProb = (wdl[2] / total * 100.0).clamp(0.0, 100.0);
        // Expected score: Win is 1.0, Draw is 0.5, Loss is 0.0
        expectedScore = ((wdl[0] + (wdl[1] * 0.5)) / total * 100.0).clamp(0.0, 100.0);

        if (isWhiteTurn) {
          whiteExpectedScore = expectedScore;
          whiteWinPct = winPct;
          blackWinPct = lossProb;
        } else {
          whiteExpectedScore = (100.0 - expectedScore).clamp(0.0, 100.0);
          whiteWinPct = lossProb;
          blackWinPct = winPct;
        }
      }
    } else if (utility != null) {
      // Lc0 Q / utility is in [-1.0, 1.0]
      expectedScore = ((utility + 1.0) / 2.0 * 100.0).clamp(0.0, 100.0);
      winPct = expectedScore;
      lossProb = 100.0 - expectedScore;
      drawProb = 0.0;
      whiteExpectedScore = isWhiteTurn ? expectedScore : (100.0 - expectedScore);
      whiteWinPct = isWhiteTurn ? winPct : lossProb;
      blackWinPct = 100.0 - whiteWinPct;
    } else if (scoreCp != null) {
      // Centipawn fallback only if WDL was suppressed
      final double winProb = 2.0 / (1.0 + math.exp(-0.00368208 * scoreCp)) - 1.0;
      expectedScore = (50.0 + (50.0 * winProb)).clamp(0.0, 100.0);
      winPct = expectedScore;
      lossProb = 100.0 - expectedScore;
      drawProb = 0.0;

      final double whiteWinProb = 2.0 / (1.0 + math.exp(-0.00368208 * whiteCp!)) - 1.0;
      whiteExpectedScore = (50.0 + (50.0 * whiteWinProb)).clamp(0.0, 100.0);
      whiteWinPct = whiteExpectedScore;
      blackWinPct = 100.0 - whiteExpectedScore;
    }

    final normalized = NormalizedEvaluation(
      whiteExpectedScore: whiteExpectedScore,
      whiteWinProbability: whiteWinPct,
      drawProbability: drawProb,
      blackWinProbability: blackWinPct,
      whiteCentipawns: whiteCp,
      mateState: mateState,
      mateInMoves: mateInMoves,
      rawScoreCp: scoreCp,
      rawScoreMate: scoreMate,
      rawWdl: wdl,
      rawWinProbability: winPct,
      rawExpectedScore: expectedScore,
      engineType: EngineType.lc0,
      positionRevision: positionRevision,
      analysisRequestId: analysisRequestId,
      fen: '',
      isEngineEnabled: true,
    );

    return MoveEvaluation(
      move: move,
      positionRevision: positionRevision,
      analysisRequestId: analysisRequestId,
      sourceEngine: EngineType.lc0,
      multipv: multipv,
      normalized: normalized,
      winProbability: winPct,
      whiteWinProbability: whiteWinPct,
      expectedScore: expectedScore,
      whiteExpectedScore: whiteExpectedScore,
      drawProbability: drawProb,
      lossProbability: lossProb,
      scoreCp: scoreCp,
      scoreMate: scoreMate,
      visits: nodes,
      nodes: nodes,
      nps: nps,
      depth: depth,
      policyPercentage: policyPct,
      visitPercentage: visitPct,
      utility: utility,
      pvUci: pvUci,
      pvSan: pvSan,
    );
  }
}
