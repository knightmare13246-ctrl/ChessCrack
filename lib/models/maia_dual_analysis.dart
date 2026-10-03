import 'package:flutter/material.dart';
import 'chess_move.dart';

/// Represents a single human candidate move evaluated by Maia.
class MaiaCandidate {
  final int rank;
  final String uciMove;
  final String sanMove;
  final Square from;
  final Square to;
  final double probability; // 0.0 to 100.0%
  final String modelName;
  final int rating;
  final int positionRevision;

  const MaiaCandidate({
    required this.rank,
    required this.uciMove,
    required this.sanMove,
    required this.from,
    required this.to,
    required this.probability,
    required this.modelName,
    required this.rating,
    required this.positionRevision,
  });
}

/// Represents an engine candidate move evaluated by Stockfish.
class StockfishCandidate {
  final int multipv;
  final String uciMove;
  final String sanMove;
  final Square from;
  final Square to;
  final int? scoreCp;
  final int? scoreMate;
  final double? winPercentage;
  final int depth;
  final int nodes;
  final List<String> pvSan;
  final int positionRevision;

  const StockfishCandidate({
    required this.multipv,
    required this.uciMove,
    required this.sanMove,
    required this.from,
    required this.to,
    this.scoreCp,
    this.scoreMate,
    this.winPercentage,
    required this.depth,
    required this.nodes,
    this.pvSan = const [],
    required this.positionRevision,
  });

  String get formattedScore {
    if (scoreMate != null) {
      return scoreMate! > 0 ? '+M${scoreMate!}' : '-M${scoreMate!.abs()}';
    }
    if (scoreCp != null) {
      final cpVal = scoreCp! / 100.0;
      return '${cpVal >= 0 ? '+' : ''}${cpVal.toStringAsFixed(2)}';
    }
    return '0.00';
  }
}

/// A data point representing move probability at a specific player rating.
class MoveRatingPoint {
  final int rating;
  final double probability; // 0.0 to 100.0%

  const MoveRatingPoint({
    required this.rating,
    required this.probability,
  });
}

/// Represents the probability trajectory for a candidate move across player ratings.
class MoveRatingCurve {
  final String uciMove;
  final String sanMove;
  final Color curveColor;
  final List<MoveRatingPoint> points;

  const MoveRatingCurve({
    required this.uciMove,
    required this.sanMove,
    required this.curveColor,
    required this.points,
  });

  double? probabilityAtRating(int targetRating) {
    if (points.isEmpty) return null;
    final exact = points.where((p) => p.rating == targetRating);
    if (exact.isNotEmpty) return exact.first.probability;

    // Linear interpolation between closest ratings
    final sorted = List<MoveRatingPoint>.from(points)
      ..sort((a, b) => a.rating.compareTo(b.rating));
    if (targetRating <= sorted.first.rating) return sorted.first.probability;
    if (targetRating >= sorted.last.rating) return sorted.last.probability;

    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i].rating <= targetRating && sorted[i + 1].rating >= targetRating) {
        final t = (targetRating - sorted[i].rating) / (sorted[i + 1].rating - sorted[i].rating);
        return sorted[i].probability + t * (sorted[i + 1].probability - sorted[i].probability);
      }
    }
    return sorted.first.probability;
  }
}

/// Represents a single rating evaluation point with full move probability distribution.
class MaiaRatingPoint {
  final int rating;
  final Map<String, double> probabilitiesByMove; // UCI move -> 0.0 to 1.0

  const MaiaRatingPoint({
    required this.rating,
    required this.probabilitiesByMove,
  });

  double probabilityForMove(String uci) => probabilitiesByMove[uci] ?? 0.0;
}

/// Immutable atomic snapshot produced by the rating-conditioned Maia neural network sweep.
class MaiaRatingSweepSnapshot {
  final String fen;
  final String modelId;
  final String modelVersion;
  final List<int> ratings;
  final List<String> candidateMoves;
  final List<MoveRatingCurve> series;
  final int positionRevision;
  final int analysisRequestId;
  final DateTime createdAt;

  const MaiaRatingSweepSnapshot({
    required this.fen,
    required this.modelId,
    required this.modelVersion,
    required this.ratings,
    required this.candidateMoves,
    required this.series,
    required this.positionRevision,
    required this.analysisRequestId,
    required this.createdAt,
  });

  MovesByRatingDataset toDataset({int activeRating = 1500}) {
    return MovesByRatingDataset(
      fen: fen,
      positionRevision: positionRevision,
      supportedRatings: ratings,
      curves: series,
      activeRating: activeRating,
      isComputing: false,
      isModelInstalled: true,
      analysisRequestId: analysisRequestId,
      snapshot: this,
    );
  }
}

/// Aggregated dataset for the interactive "Moves by Rating" chart.
class MovesByRatingDataset {
  final String fen;
  final int positionRevision;
  final List<int> supportedRatings; // e.g. [600, 700, ..., 2600]
  final List<MoveRatingCurve> curves;
  final int activeRating;
  final bool isComputing;
  final bool isModelInstalled;
  final int analysisRequestId;
  final MaiaRatingSweepSnapshot? snapshot;
  final String? errorMessage;

  const MovesByRatingDataset({
    required this.fen,
    required this.positionRevision,
    required this.supportedRatings,
    required this.curves,
    required this.activeRating,
    this.isComputing = false,
    this.isModelInstalled = true,
    this.analysisRequestId = 0,
    this.snapshot,
    this.errorMessage,
  });

  static const List<int> defaultRatings = [
    600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500,
    1600, 1700, 1800, 1900, 2000, 2100, 2200, 2300, 2400, 2500, 2600
  ];

  static const List<Color> palette = [
    Color(0xFF4CAF50), // Green (e.g. e4)
    Color(0xFFFFA726), // Amber / Warm Orange (e.g. d4)
    Color(0xFF42A5F5), // Sky Blue (e.g. Nf3)
    Color(0xFFAB47BC), // Purple (e.g. c4)
    Color(0xFFFF7043), // Coral / Deep Orange (e.g. e3)
    Color(0xFF26C6DA), // Cyan / Teal (e.g. c3)
  ];
}

/// High-level synchronized dual analysis state for Maia + Stockfish.
class DualEngineAnalysisState {
  final int positionRevision;
  final String fen;

  // Maia (Human Move Prediction)
  final String maiaModelName;
  final int maiaActiveRating;
  final List<MaiaCandidate> maiaCandidates;
  final bool isMaiaAnalyzing;

  // Stockfish (Objective Engine Evaluation)
  final String stockfishName;
  final List<StockfishCandidate> stockfishCandidates;
  final int? stockfishDepth;
  final int? stockfishNodes;
  final int? stockfishNps;
  final bool isStockfishAnalyzing;

  // Moves by Rating Sweep Data
  final MovesByRatingDataset? movesByRatingData;

  const DualEngineAnalysisState({
    required this.positionRevision,
    required this.fen,
    this.maiaModelName = 'Maia 1500',
    this.maiaActiveRating = 1500,
    this.maiaCandidates = const [],
    this.isMaiaAnalyzing = false,
    this.stockfishName = 'Stockfish 19',
    this.stockfishCandidates = const [],
    this.stockfishDepth,
    this.stockfishNodes,
    this.stockfishNps,
    this.isStockfishAnalyzing = false,
    this.movesByRatingData,
  });
}
