import 'dart:ui';
import 'chess_move.dart';
import 'engine_analysis.dart';
import 'engine_settings.dart';

/// Available presentation modes for arrowhead badges on the chessboard.
enum ArrowheadType {
  winrate('Winrate', 'Pure win percentage without draw score (W / total * 100%)'),
  nodePct('Node %', 'Percentage of search visits allocated to this candidate move'),
  policy('Policy', 'Neural network prior probability (P) before MCTS search'),
  multipvRank('MultiPV rank', 'Engine search preference rank (1, 2, 3...)'),
  movesLeft('Moves Left Ahead', 'Estimated plies or moves remaining in game (MLH)');

  final String label;
  final String description;
  const ArrowheadType(this.label, this.description);
}

/// Arrow filters tailored to Leela Chess Zero (neural MCTS telemetry).
enum ArrowFilterLc0 {
  all('All Candidates', 'Show all configured MultiPV candidate arrows'),
  top1('Top 1 only', 'Show only the primary candidate arrow'),
  top2('Top 2 only', 'Show the top 2 candidate arrows'),
  top3('Top 3 only', 'Show the top 3 candidate arrows'),
  minNodes1('Min 1% Nodes', 'Hide candidates receiving < 1% of search visits'),
  minNodes5('Min 5% Nodes', 'Hide candidates receiving < 5% of search visits'),
  within2PctScore('Within 2% of Best', 'Hide candidates > 2% worse than top move'),
  within5PctScore('Within 5% of Best', 'Hide candidates > 5% worse than top move');

  final String label;
  final String description;
  const ArrowFilterLc0(this.label, this.description);
}

/// Arrow filters tailored to alpha-beta engines (Stockfish / Built-in).
enum ArrowFilterOthers {
  all('All Candidates', 'Show all configured MultiPV candidate arrows'),
  top1('Top 1 only', 'Show only the primary candidate arrow'),
  top2('Top 2 only', 'Show the top 2 candidate arrows'),
  top3('Top 3 only', 'Show the top 3 candidate arrows'),
  within50Cp('Within 50 cp', 'Hide moves > 50 centipawns worse than top move'),
  within100Cp('Within 100 cp', 'Hide moves > 100 centipawns worse than top move');

  final String label;
  final String description;
  const ArrowFilterOthers(this.label, this.description);
}

/// Visual styling parameters for a candidate arrow.
class ArrowVisualStyle {
  final Color shaftColor;
  final Color badgeColor;
  final Color textColor;
  final Color borderColor;
  final double opacity;
  final double strokeWidthScale;
  final double arrowHeadScale;
  final double badgeScale;
  final double curvature; // lateral offset in square units for overlapping paths

  const ArrowVisualStyle({
    required this.shaftColor,
    required this.badgeColor,
    required this.textColor,
    required this.borderColor,
    this.opacity = 1.0,
    this.strokeWidthScale = 1.0,
    this.arrowHeadScale = 1.0,
    this.badgeScale = 1.0,
    this.curvature = 0.0,
  });

  ArrowVisualStyle copyWith({
    Color? shaftColor,
    Color? badgeColor,
    Color? textColor,
    Color? borderColor,
    double? opacity,
    double? strokeWidthScale,
    double? arrowHeadScale,
    double? badgeScale,
    double? curvature,
  }) {
    return ArrowVisualStyle(
      shaftColor: shaftColor ?? this.shaftColor,
      badgeColor: badgeColor ?? this.badgeColor,
      textColor: textColor ?? this.textColor,
      borderColor: borderColor ?? this.borderColor,
      opacity: opacity ?? this.opacity,
      strokeWidthScale: strokeWidthScale ?? this.strokeWidthScale,
      arrowHeadScale: arrowHeadScale ?? this.arrowHeadScale,
      badgeScale: badgeScale ?? this.badgeScale,
      curvature: curvature ?? this.curvature,
    );
  }
}

/// First-class immutable model representing a single engine candidate arrow.
/// Every arrow retains its own move, PV, rank, score, WDL, telemetry, revision, and style.
class CandidateArrow {
  final int rank; // 1-based (MultiPV rank: 1, 2, 3...)
  final String uciMove; // e.g. "e2e4"
  final Square from;
  final Square to;
  final List<String> pvUci;
  final List<String> pvSan;

  final double? winProbability; // Pure win percentage: W / (W + D + L) * 100%
  final double? drawProbability;
  final double? lossProbability;
  final double? expectedScore; // Expected score: (W + 0.5D) / (W + D + L) * 100%

  final int? scoreCp;
  final int? scoreMate;

  final int? visits; // Number of visits / nodes exploring this candidate
  final int? totalNodes; // Total search nodes across all candidates
  final double? nodePercentage; // (visits / totalNodes) * 100%

  final double? policyPercentage; // Neural network prior probability P from Lc0
  final double? movesLeft; // Moves left ahead (MLH) from Lc0

  final int depth;
  final int positionRevision;
  final int requestId;
  final String? sourceFen;

  final ArrowVisualStyle style;

  const CandidateArrow({
    required this.rank,
    required this.uciMove,
    required this.from,
    required this.to,
    this.pvUci = const [],
    this.pvSan = const [],
    this.winProbability,
    this.drawProbability,
    this.lossProbability,
    this.expectedScore,
    this.scoreCp,
    this.scoreMate,
    this.visits,
    this.totalNodes,
    this.nodePercentage,
    this.policyPercentage,
    this.movesLeft,
    this.depth = 0,
    required this.positionRevision,
    required this.requestId,
    this.sourceFen,
    required this.style,
  });

  /// Formats the text to display in the circular arrowhead badge.
  /// Strictly returns real engine telemetry or "N/A" if unavailable.
  String getBadgeText(ArrowheadType type, EngineType engine) {
    switch (type) {
      case ArrowheadType.winrate:
        final score = winProbability ?? expectedScore;
        if (score != null) {
          return '${score.round()}';
        }
        return 'N/A';

      case ArrowheadType.nodePct:
        if (nodePercentage != null) {
          return '${nodePercentage!.round()}';
        }
        return 'N/A';

      case ArrowheadType.policy:
        if (engine == EngineType.lc0) {
          if (policyPercentage != null) {
            return '${policyPercentage!.round()}';
          }
          return 'N/A';
        }
        // Stockfish does not have MCTS policy priors
        return 'N/A';

      case ArrowheadType.multipvRank:
        return '$rank';

      case ArrowheadType.movesLeft:
        if (engine == EngineType.lc0) {
          if (movesLeft != null) {
            return '${movesLeft!.round()}';
          }
          return 'N/A';
        }
        // Stockfish displays mate distance if available, otherwise N/A
        if (scoreMate != null) {
          return 'M${scoreMate!.abs()}';
        }
        return 'N/A';
    }
  }

  /// Checks if the requested telemetry metric is supported by the engine.
  bool isMetricAvailable(ArrowheadType type, EngineType engine) {
    switch (type) {
      case ArrowheadType.winrate:
      case ArrowheadType.nodePct:
      case ArrowheadType.multipvRank:
        return true;
      case ArrowheadType.policy:
        return engine == EngineType.lc0 && policyPercentage != null;
      case ArrowheadType.movesLeft:
        return (engine == EngineType.lc0 && movesLeft != null) ||
            (engine == EngineType.stockfish && scoreMate != null);
    }
  }

  CandidateArrow copyWith({
    int? rank,
    String? uciMove,
    Square? from,
    Square? to,
    List<String>? pvUci,
    List<String>? pvSan,
    double? winProbability,
    double? drawProbability,
    double? lossProbability,
    double? expectedScore,
    int? scoreCp,
    int? scoreMate,
    int? visits,
    int? totalNodes,
    double? nodePercentage,
    double? policyPercentage,
    double? movesLeft,
    int? depth,
    int? positionRevision,
    int? requestId,
    String? sourceFen,
    ArrowVisualStyle? style,
  }) {
    return CandidateArrow(
      rank: rank ?? this.rank,
      uciMove: uciMove ?? this.uciMove,
      from: from ?? this.from,
      to: to ?? this.to,
      pvUci: pvUci ?? this.pvUci,
      pvSan: pvSan ?? this.pvSan,
      winProbability: winProbability ?? this.winProbability,
      drawProbability: drawProbability ?? this.drawProbability,
      lossProbability: lossProbability ?? this.lossProbability,
      expectedScore: expectedScore ?? this.expectedScore,
      scoreCp: scoreCp ?? this.scoreCp,
      scoreMate: scoreMate ?? this.scoreMate,
      visits: visits ?? this.visits,
      totalNodes: totalNodes ?? this.totalNodes,
      nodePercentage: nodePercentage ?? this.nodePercentage,
      policyPercentage: policyPercentage ?? this.policyPercentage,
      movesLeft: movesLeft ?? this.movesLeft,
      depth: depth ?? this.depth,
      positionRevision: positionRevision ?? this.positionRevision,
      requestId: requestId ?? this.requestId,
      sourceFen: sourceFen ?? this.sourceFen,
      style: style ?? this.style,
    );
  }
}

/// Pure filtering function to select visible candidate arrows based on settings.
/// Protects Rank 1 candidate from threshold drops.
/// Never restarts engine analysis; updates presentation immediately.
List<CandidateArrow> filterCandidateArrows({
  required List<CandidateArrow> arrows,
  required EngineSettings settings,
}) {
  if (arrows.isEmpty) return const [];

  final isLc0 = settings.activeEngine == EngineType.lc0;
  List<CandidateArrow> filtered;

  if (isLc0) {
    switch (settings.arrowFilterLc0) {
      case ArrowFilterLc0.all:
        filtered = arrows;
        break;
      case ArrowFilterLc0.top1:
        filtered = arrows.where((a) => a.rank <= 1).toList();
        break;
      case ArrowFilterLc0.top2:
        filtered = arrows.where((a) => a.rank <= 2).toList();
        break;
      case ArrowFilterLc0.top3:
        filtered = arrows.where((a) => a.rank <= 3).toList();
        break;
      case ArrowFilterLc0.minNodes1:
        filtered = arrows.where((a) => a.rank == 1 || (a.nodePercentage ?? 0.0) >= 1.0).toList();
        break;
      case ArrowFilterLc0.minNodes5:
        filtered = arrows.where((a) => a.rank == 1 || (a.nodePercentage ?? 0.0) >= 5.0).toList();
        break;
      case ArrowFilterLc0.within2PctScore:
        final bestScore = arrows.first.expectedScore ?? 50.0;
        filtered = arrows.where((a) => a.rank == 1 || (bestScore - (a.expectedScore ?? 0.0)) <= 2.0).toList();
        break;
      case ArrowFilterLc0.within5PctScore:
        final bestScore = arrows.first.expectedScore ?? 50.0;
        filtered = arrows.where((a) => a.rank == 1 || (bestScore - (a.expectedScore ?? 0.0)) <= 5.0).toList();
        break;
    }
  } else {
    // Other engines (Stockfish)
    switch (settings.arrowFilterOthers) {
      case ArrowFilterOthers.all:
        filtered = arrows;
        break;
      case ArrowFilterOthers.top1:
        filtered = arrows.where((a) => a.rank <= 1).toList();
        break;
      case ArrowFilterOthers.top2:
        filtered = arrows.where((a) => a.rank <= 2).toList();
        break;
      case ArrowFilterOthers.top3:
        filtered = arrows.where((a) => a.rank <= 3).toList();
        break;
      case ArrowFilterOthers.within50Cp:
        final bestCp = arrows.first.scoreCp ?? 0;
        filtered = arrows.where((a) => a.rank == 1 || (a.scoreCp != null && (bestCp - a.scoreCp!) <= 50)).toList();
        break;
      case ArrowFilterOthers.within100Cp:
        final bestCp = arrows.first.scoreCp ?? 0;
        filtered = arrows.where((a) => a.rank == 1 || (a.scoreCp != null && (bestCp - a.scoreCp!) <= 100)).toList();
        break;
    }
  }

  // Safety fallback: if thresholds pruned all candidates, preserve at least Rank 1
  if (filtered.isEmpty && arrows.isNotEmpty) {
    return [arrows.first];
  }
  return filtered;
}
