import 'engine_analysis.dart' show EngineType;

/// The mate status of the position
enum MateState {
  none,
  whiteMate, // White has forced mate in N moves (or White checkmated)
  blackMate, // Black has forced mate in N moves (or Black checkmated)
}

/// The authoritative, normalized evaluation state across engines (Stockfish alpha-beta
/// and Lc0 neural/MCTS).
///
/// Guarantees that the evaluation bar height, text labels, and analysis panel scores
/// are derived from the exact same mathematical state.
class NormalizedEvaluation {
  /// Bounded expected score from White's perspective: 0.0 (Black wins) to 100.0 (White wins), 50.0 is equal.
  final double whiteExpectedScore;

  /// Probabilities from White's perspective (0.0 to 100.0)
  final double? whiteWinProbability;
  final double? drawProbability;
  final double? blackWinProbability;

  /// Centipawns from White's perspective (+ for White advantage, - for Black advantage)
  final int? whiteCentipawns;

  /// Mate status from White's perspective
  final MateState mateState;

  /// Positive number of moves to mate (e.g. 2 for M2 or -M2)
  final int? mateInMoves;

  /// Raw engine telemetry (preserved completely untouched for diagnostics)
  final int? rawScoreCp;
  final int? rawScoreMate;
  final List<int>? rawWdl;
  final double? rawWinProbability;
  final double? rawExpectedScore;

  /// Tracing & position safety
  final EngineType engineType;
  final int positionRevision;
  final int analysisRequestId;
  final String fen;
  final bool isEngineEnabled;
  final DateTime? _timestamp;
  DateTime get timestamp => _timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);

  const NormalizedEvaluation({
    required this.whiteExpectedScore,
    this.whiteWinProbability,
    this.drawProbability,
    this.blackWinProbability,
    this.whiteCentipawns,
    this.mateState = MateState.none,
    this.mateInMoves,
    this.rawScoreCp,
    this.rawScoreMate,
    this.rawWdl,
    this.rawWinProbability,
    this.rawExpectedScore,
    required this.engineType,
    required this.positionRevision,
    required this.analysisRequestId,
    required this.fen,
    required this.isEngineEnabled,
    DateTime? timestamp,
  }) : _timestamp = timestamp;

  static const neutral = NormalizedEvaluation(
    whiteExpectedScore: 50.0,
    whiteWinProbability: 50.0,
    drawProbability: 0.0,
    blackWinProbability: 50.0,
    whiteCentipawns: 0,
    mateState: MateState.none,
    rawScoreCp: 0,
    engineType: EngineType.stockfish,
    positionRevision: 0,
    analysisRequestId: 0,
    fen: '',
    isEngineEnabled: false,
  );

  /// Height factor (0.0 to 1.0) representing White advantage from bottom
  double get displayFactor {
    if (mateState == MateState.whiteMate) return 1.0;
    if (mateState == MateState.blackMate) return 0.0;
    return (whiteExpectedScore / 100.0).clamp(0.0, 1.0);
  }

  /// Compact text label displayed on the evaluation bar (e.g. "+0.3", "-1.5", "M2", "-M4", "53.5%")
  String get barLabel {
    if (mateState == MateState.whiteMate) {
      return 'M${mateInMoves ?? 1}';
    } else if (mateState == MateState.blackMate) {
      return '-M${mateInMoves ?? 1}';
    }

    if (engineType == EngineType.lc0) {
      return '${whiteExpectedScore.toStringAsFixed(1)}%';
    }

    if (whiteCentipawns != null) {
      final cp = whiteCentipawns!;
      if (cp == 0) return '0.0';
      final sign = cp > 0 ? '+' : '-';
      return '$sign${(cp.abs() / 100.0).toStringAsFixed(1)}';
    }

    return '${whiteExpectedScore.toStringAsFixed(1)}%';
  }

  /// Detailed numeric formatted score (e.g. "+0.26", "-1.40", "M2", "53.5%")
  String get formattedNumericScore {
    if (mateState == MateState.whiteMate) {
      return 'M${mateInMoves ?? 1}';
    } else if (mateState == MateState.blackMate) {
      return '-M${mateInMoves ?? 1}';
    }

    if (engineType == EngineType.lc0) {
      return '${whiteExpectedScore.toStringAsFixed(1)}%';
    }

    if (whiteCentipawns != null) {
      final cp = whiteCentipawns!;
      if (cp == 0) return '0.00';
      final sign = cp > 0 ? '+' : '-';
      return '$sign${(cp.abs() / 100.0).toStringAsFixed(2)}';
    }

    return '${whiteExpectedScore.toStringAsFixed(1)}%';
  }

  NormalizedEvaluation copyWith({
    double? whiteExpectedScore,
    double? whiteWinProbability,
    double? drawProbability,
    double? blackWinProbability,
    int? whiteCentipawns,
    MateState? mateState,
    int? mateInMoves,
    int? rawScoreCp,
    int? rawScoreMate,
    List<int>? rawWdl,
    double? rawWinProbability,
    double? rawExpectedScore,
    EngineType? engineType,
    int? positionRevision,
    int? analysisRequestId,
    String? fen,
    bool? isEngineEnabled,
    DateTime? timestamp,
  }) {
    return NormalizedEvaluation(
      whiteExpectedScore: whiteExpectedScore ?? this.whiteExpectedScore,
      whiteWinProbability: whiteWinProbability ?? this.whiteWinProbability,
      drawProbability: drawProbability ?? this.drawProbability,
      blackWinProbability: blackWinProbability ?? this.blackWinProbability,
      whiteCentipawns: whiteCentipawns ?? this.whiteCentipawns,
      mateState: mateState ?? this.mateState,
      mateInMoves: mateInMoves ?? this.mateInMoves,
      rawScoreCp: rawScoreCp ?? this.rawScoreCp,
      rawScoreMate: rawScoreMate ?? this.rawScoreMate,
      rawWdl: rawWdl ?? this.rawWdl,
      rawWinProbability: rawWinProbability ?? this.rawWinProbability,
      rawExpectedScore: rawExpectedScore ?? this.rawExpectedScore,
      engineType: engineType ?? this.engineType,
      positionRevision: positionRevision ?? this.positionRevision,
      analysisRequestId: analysisRequestId ?? this.analysisRequestId,
      fen: fen ?? this.fen,
      isEngineEnabled: isEngineEnabled ?? this.isEngineEnabled,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

