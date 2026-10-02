import 'candidate_arrow.dart';
import 'chess_move.dart';
import '../utils/san_formatter.dart';
import '../utils/score_adapters.dart';
import '../services/engine_trace_logger.dart';

export '../services/engine_trace_logger.dart' show AnalysisDataState, EngineSearchState, EngineActivationState;
export 'candidate_arrow.dart';
export 'engine_download_model.dart' show EngineInstallationState;
export 'normalized_evaluation.dart' show NormalizedEvaluation, MateState;
export '../utils/san_formatter.dart' show PvMoveItem, SANFormatter;

enum EngineType {
  stockfish('Stockfish 19', 'Universal NNUE engine'),
  lc0('Lc0 (Leela)', 'Neural network engine');

  final String displayName;
  final String description;
  const EngineType(this.displayName, this.description);
}

enum EngineLifecycleState {
  uninitialized,
  initializing,
  ready,
  disposed,
  error,
}

class AnalysisGeneration {
  final int positionRevision;
  final int analysisRequestId;
  final int engineSessionId;

  const AnalysisGeneration({
    required this.positionRevision,
    required this.analysisRequestId,
    required this.engineSessionId,
  });

  bool matches({
    required int revision,
    required int requestId,
    required int sessionId,
  }) =>
      positionRevision == revision &&
      analysisRequestId == requestId &&
      engineSessionId == sessionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisGeneration &&
          runtimeType == other.runtimeType &&
          positionRevision == other.positionRevision &&
          analysisRequestId == other.analysisRequestId &&
          engineSessionId == other.engineSessionId;

  @override
  int get hashCode => Object.hash(positionRevision, analysisRequestId, engineSessionId);

  @override
  String toString() =>
      'AnalysisGeneration(rev: $positionRevision, req: $analysisRequestId, sess: $engineSessionId)';
}

class CandidateArrowDiagnostic {
  final int rank;
  final String uciMove;
  final String? sourceFen;
  final int arrowRevision;
  final int currentRevision;
  final int arrowRequestId;
  final int currentRequestId;
  final bool isFiltered;
  final bool isLegal;
  final bool isCoordsValid;
  final bool isRendered;
  final String? rejectionReason;

  const CandidateArrowDiagnostic({
    required this.rank,
    required this.uciMove,
    this.sourceFen,
    required this.arrowRevision,
    required this.currentRevision,
    required this.arrowRequestId,
    required this.currentRequestId,
    required this.isFiltered,
    required this.isLegal,
    required this.isCoordsValid,
    required this.isRendered,
    this.rejectionReason,
  });
}

class EngineDiagnostics {
  final String engineName;
  final String engineVersion;
  final String backend;
  final String device;
  final String network;
  final int threads;
  final int hashSizeMb;
  final int multiPv;
  final int requestedThreads;
  final int requestedHashMb;
  final int requestedMultiPv;
  final bool optionsApplied;
  final bool readyOkReceived;
  final int? totalNodes;
  final int? nps;
  final int? depth;
  final int? seldepth;
  final int? timeMs;
  final int hashfull;
  final int tbhits;
  final String? bestmove;
  final String? currmove;
  final int? currmovenumber;
  final String currentFen;
  final String cpuUtilization;
  final int? visits;
  final List<int>? wdl;
  final String? topPv;
  final int positionRevision;
  final int analysisRequestId;
  final DateTime lastUpdate;

  // Real-time Arrow Pipeline Diagnostics
  final int pvsReceived;
  final int candidateArrowsCreated;
  final int arrowsAfterFilter;
  final int painterReceived;
  final int passedRevisionCheck;
  final int passedLegalMoveCheck;
  final int painterRendered;
  final List<CandidateArrowDiagnostic> arrowDiagnostics;
  final int activeProcessCount;

  const EngineDiagnostics({
    this.engineName = '',
    this.engineVersion = '',
    this.backend = 'auto',
    this.device = 'CPU',
    this.network = 'default',
    this.threads = 1,
    this.hashSizeMb = 128,
    this.multiPv = 3,
    this.requestedThreads = 1,
    this.requestedHashMb = 128,
    this.requestedMultiPv = 3,
    this.optionsApplied = false,
    this.readyOkReceived = false,
    this.totalNodes,
    this.nps,
    this.depth,
    this.seldepth,
    this.timeMs,
    this.hashfull = 0,
    this.tbhits = 0,
    this.bestmove,
    this.currmove,
    this.currmovenumber,
    this.currentFen = '',
    this.cpuUtilization = '',
    this.visits,
    this.wdl,
    this.topPv,
    this.positionRevision = 0,
    this.analysisRequestId = 0,
    required this.lastUpdate,
    this.pvsReceived = 0,
    this.candidateArrowsCreated = 0,
    this.arrowsAfterFilter = 0,
    this.painterReceived = 0,
    this.passedRevisionCheck = 0,
    this.passedLegalMoveCheck = 0,
    this.painterRendered = 0,
    this.arrowDiagnostics = const [],
    this.activeProcessCount = 0,
  });

  EngineDiagnostics copyWith({
    String? engineName,
    String? engineVersion,
    String? backend,
    String? device,
    String? network,
    int? threads,
    int? hashSizeMb,
    int? multiPv,
    int? requestedThreads,
    int? requestedHashMb,
    int? requestedMultiPv,
    bool? optionsApplied,
    bool? readyOkReceived,
    int? totalNodes,
    int? nps,
    int? depth,
    int? seldepth,
    int? timeMs,
    int? hashfull,
    int? tbhits,
    String? bestmove,
    String? currmove,
    int? currmovenumber,
    String? currentFen,
    String? cpuUtilization,
    int? visits,
    List<int>? wdl,
    String? topPv,
    int? positionRevision,
    int? analysisRequestId,
    DateTime? lastUpdate,
    int? pvsReceived,
    int? candidateArrowsCreated,
    int? arrowsAfterFilter,
    int? painterReceived,
    int? passedRevisionCheck,
    int? passedLegalMoveCheck,
    int? painterRendered,
    List<CandidateArrowDiagnostic>? arrowDiagnostics,
    int? activeProcessCount,
  }) {
    return EngineDiagnostics(
      engineName: engineName ?? this.engineName,
      engineVersion: engineVersion ?? this.engineVersion,
      backend: backend ?? this.backend,
      device: device ?? this.device,
      network: network ?? this.network,
      threads: threads ?? this.threads,
      hashSizeMb: hashSizeMb ?? this.hashSizeMb,
      multiPv: multiPv ?? this.multiPv,
      requestedThreads: requestedThreads ?? this.requestedThreads,
      requestedHashMb: requestedHashMb ?? this.requestedHashMb,
      requestedMultiPv: requestedMultiPv ?? this.requestedMultiPv,
      optionsApplied: optionsApplied ?? this.optionsApplied,
      readyOkReceived: readyOkReceived ?? this.readyOkReceived,
      totalNodes: totalNodes ?? this.totalNodes,
      nps: nps ?? this.nps,
      depth: depth ?? this.depth,
      seldepth: seldepth ?? this.seldepth,
      timeMs: timeMs ?? this.timeMs,
      hashfull: hashfull ?? this.hashfull,
      tbhits: tbhits ?? this.tbhits,
      bestmove: bestmove ?? this.bestmove,
      currmove: currmove ?? this.currmove,
      currmovenumber: currmovenumber ?? this.currmovenumber,
      currentFen: currentFen ?? this.currentFen,
      cpuUtilization: cpuUtilization ?? this.cpuUtilization,
      visits: visits ?? this.visits,
      wdl: wdl ?? this.wdl,
      topPv: topPv ?? this.topPv,
      positionRevision: positionRevision ?? this.positionRevision,
      analysisRequestId: analysisRequestId ?? this.analysisRequestId,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      pvsReceived: pvsReceived ?? this.pvsReceived,
      candidateArrowsCreated: candidateArrowsCreated ?? this.candidateArrowsCreated,
      arrowsAfterFilter: arrowsAfterFilter ?? this.arrowsAfterFilter,
      painterReceived: painterReceived ?? this.painterReceived,
      passedRevisionCheck: passedRevisionCheck ?? this.passedRevisionCheck,
      passedLegalMoveCheck: passedLegalMoveCheck ?? this.passedLegalMoveCheck,
      painterRendered: painterRendered ?? this.painterRendered,
      arrowDiagnostics: arrowDiagnostics ?? this.arrowDiagnostics,
      activeProcessCount: activeProcessCount ?? this.activeProcessCount,
    );
  }
}

class PvLine {
  final int multipv;
  final int? scoreCp;
  final int? scoreMate;
  final double winPercentage;
  final double whiteWinPercentage;
  final double expectedScore;
  final double whiteExpectedScore;
  final List<int>? wdl;
  final List<String> movesUci;
  List<String> movesSan;
  final List<PvMoveItem> pvMoves;
  final String startFen;
  final int? depth;
  final int? seldepth;
  final int? nodes;
  final int? nps;
  final double? visitPercentage;
  final double? policyPercentage;
  final double? utility;
  final double? movesLeft;
  final int positionRevision;
  final int analysisRequestId;
  final int engineSessionId;
  final MoveEvaluation? evaluation;
  final NormalizedEvaluation? normalizedEvaluation;

  PvLine({
    required this.multipv,
    this.scoreCp,
    this.scoreMate,
    required this.winPercentage,
    required this.whiteWinPercentage,
    double? expectedScore,
    double? whiteExpectedScore,
    this.wdl,
    required this.movesUci,
    this.movesSan = const [],
    this.pvMoves = const [],
    this.startFen = '',
    this.depth,
    this.seldepth,
    this.nodes,
    this.nps,
    this.visitPercentage,
    this.policyPercentage,
    this.utility,
    this.movesLeft,
    this.positionRevision = 0,
    this.analysisRequestId = 0,
    this.engineSessionId = 0,
    this.evaluation,
    NormalizedEvaluation? normalizedEvaluation,
  })  : expectedScore = expectedScore ?? winPercentage,
        whiteExpectedScore = whiteExpectedScore ?? whiteWinPercentage,
        normalizedEvaluation = normalizedEvaluation ?? evaluation?.normalized;

  PvLine copyWith({
    int? multipv,
    int? scoreCp,
    int? scoreMate,
    double? winPercentage,
    double? whiteWinPercentage,
    double? expectedScore,
    double? whiteExpectedScore,
    List<int>? wdl,
    List<String>? movesUci,
    List<String>? movesSan,
    List<PvMoveItem>? pvMoves,
    String? startFen,
    int? depth,
    int? seldepth,
    int? nodes,
    int? nps,
    double? visitPercentage,
    double? policyPercentage,
    double? utility,
    double? movesLeft,
    int? positionRevision,
    int? analysisRequestId,
    int? engineSessionId,
    MoveEvaluation? evaluation,
    NormalizedEvaluation? normalizedEvaluation,
  }) {
    return PvLine(
      multipv: multipv ?? this.multipv,
      scoreCp: scoreCp ?? this.scoreCp,
      scoreMate: scoreMate ?? this.scoreMate,
      winPercentage: winPercentage ?? this.winPercentage,
      whiteWinPercentage: whiteWinPercentage ?? this.whiteWinPercentage,
      expectedScore: expectedScore ?? this.expectedScore,
      whiteExpectedScore: whiteExpectedScore ?? this.whiteExpectedScore,
      wdl: wdl ?? this.wdl,
      movesUci: movesUci ?? this.movesUci,
      movesSan: movesSan ?? this.movesSan,
      pvMoves: pvMoves ?? this.pvMoves,
      startFen: startFen ?? this.startFen,
      depth: depth ?? this.depth,
      seldepth: seldepth ?? this.seldepth,
      nodes: nodes ?? this.nodes,
      nps: nps ?? this.nps,
      visitPercentage: visitPercentage ?? this.visitPercentage,
      policyPercentage: policyPercentage ?? this.policyPercentage,
      utility: utility ?? this.utility,
      movesLeft: movesLeft ?? this.movesLeft,
      positionRevision: positionRevision ?? this.positionRevision,
      analysisRequestId: analysisRequestId ?? this.analysisRequestId,
      engineSessionId: engineSessionId ?? this.engineSessionId,
      evaluation: evaluation ?? this.evaluation,
      normalizedEvaluation: normalizedEvaluation ?? this.normalizedEvaluation,
    );
  }

  String? get primaryMoveUci => movesUci.isNotEmpty ? movesUci.first : null;
  String? get primaryMoveSan => movesSan.isNotEmpty ? movesSan.first : (pvMoves.isNotEmpty ? pvMoves.first.san : null);
  PvMoveItem? moveAt(int index) => (index >= 0 && index < pvMoves.length) ? pvMoves[index] : null;

  Square? get fromSquare {
    final m = primaryMoveUci;
    if (m == null || m.length < 4) return null;
    try {
      return Square.fromAlgebraic(m.substring(0, 2));
    } catch (_) {
      return null;
    }
  }

  Square? get toSquare {
    final m = primaryMoveUci;
    if (m == null || m.length < 4) return null;
    try {
      return Square.fromAlgebraic(m.substring(2, 4));
    } catch (_) {
      return null;
    }
  }

  int get badgeScore => (evaluation?.badgeScore ?? expectedScore.round()).clamp(0, 100);

  String get formattedScore {
    if (evaluation != null) {
      return evaluation!.formattedScore;
    }
    if (scoreMate != null) {
      return scoreMate! > 0 ? '+M${scoreMate!}' : '-M${scoreMate!.abs()}';
    }
    return '${expectedScore.toStringAsFixed(1)}%';
  }

  String get formattedMetrics {
    final parts = <String>[];
    if (visitPercentage != null) {
      parts.add('N: ${visitPercentage!.toStringAsFixed(2)}%');
    }
    if (policyPercentage != null) {
      parts.add('P: ${policyPercentage!.toStringAsFixed(2)}%');
    }
    if (utility != null) {
      parts.add('U: ${utility!.toStringAsFixed(3)}');
    }
    if (parts.isEmpty) {
      if (depth != null && depth! > 0) parts.add('d: $depth');
      if (nodes != null && nodes! > 0) parts.add('nodes: $nodes');
      if (nps != null && nps! > 0) parts.add('${(nps! / 1000).toStringAsFixed(0)}k nps');
    }
    return '(${parts.join(', ')})';
  }
}

class PositionAnalysis {
  final String fen;
  final int positionRevision;
  final int analysisRequestId;
  final int engineSessionId;
  final int? totalNodes;
  final int? nodesPerSecond;
  final int? depth;
  final int? seldepth;
  final int? timeMs;
  final AnalysisDataState searchState;
  final bool isMaia;
  final int? maiaElo;
  final List<PvLine> pvLines;
  final List<CandidateArrow> candidateArrows;
  final bool isAnalyzing;
  final String? engineName;
  final EngineDiagnostics? diagnostics;

  const PositionAnalysis({
    required this.fen,
    this.positionRevision = 0,
    this.analysisRequestId = 0,
    this.engineSessionId = 0,
    this.totalNodes,
    this.nodesPerSecond,
    this.depth,
    this.seldepth,
    this.timeMs,
    this.searchState = AnalysisDataState.idle,
    this.isMaia = false,
    this.maiaElo,
    this.pvLines = const [],
    this.candidateArrows = const [],
    this.isAnalyzing = false,
    this.engineName,
    this.diagnostics,
    this.explicitEvaluation,
  });

  final NormalizedEvaluation? explicitEvaluation;

  PvLine? get bestLine => pvLines.isNotEmpty ? pvLines.first : null;

  NormalizedEvaluation get normalizedEvaluation {
    if (explicitEvaluation != null) return explicitEvaluation!;
    if (bestLine?.normalizedEvaluation != null) return bestLine!.normalizedEvaluation!;
    return NormalizedEvaluation.neutral.copyWith(
      positionRevision: positionRevision,
      analysisRequestId: analysisRequestId,
      fen: fen,
      isEngineEnabled: isAnalyzing,
    );
  }

  double get whiteWinPercentage => normalizedEvaluation.whiteExpectedScore;

  String get formattedHeader {
    final bool effectiveIsMaia = isMaia || (engineName?.toLowerCase().contains('maia') == true);
    if (effectiveIsMaia) {
      if (searchState == AnalysisDataState.paused) {
        return 'Paused · $engineName · Evaluation Paused';
      }
      final status = (isAnalyzing || searchState == AnalysisDataState.searching)
          ? 'Evaluating Human Moves...'
          : 'Evaluation Complete (1-ply Policy)';
      return '$engineName · $status';
    }

    final formattedNodes = totalNodes != null ? _formatNumber(totalNodes!) : '—';
    final String npsText;
    if (isAnalyzing || searchState == AnalysisDataState.searching) {
      if (nodesPerSecond != null && nodesPerSecond! > 0) {
        npsText = 'N/s: ${_formatNumber(nodesPerSecond!)}';
      } else {
        npsText = (engineName?.toLowerCase().contains('leela') == true ||
                engineName?.toLowerCase().contains('lc0') == true)
            ? 'N/s: N/A'
            : 'N/s: —';
      }
    } else {
      npsText = 'N/s: —';
    }

    final depthText = (depth != null && depth! > 0)
        ? (seldepth != null && seldepth! > depth! ? ', Depth: $depth/$seldepth' : ', Depth: $depth')
        : '';
    final statusPrefix = (!isAnalyzing && searchState != AnalysisDataState.completed) || searchState == AnalysisDataState.paused
        ? 'Paused · '
        : '';
    return '${statusPrefix}Nodes: $formattedNodes, $npsText$depthText';
  }

  String get compactNodes {
    if (totalNodes == null) return '—';
    if (totalNodes! < 1000) return '$totalNodes';
    if (totalNodes! < 1000000) {
      final k = totalNodes! / 1000.0;
      return k >= 100 ? '${k.toStringAsFixed(0)}k' : '${k.toStringAsFixed(1)}k';
    }
    final m = totalNodes! / 1000000.0;
    return '${m.toStringAsFixed(2)}M';
  }

  String get compactNps {
    final bool isLc0 = (engineName?.toLowerCase().contains('leela') == true ||
        engineName?.toLowerCase().contains('lc0') == true);
    if (nodesPerSecond != null && nodesPerSecond! > 0) {
      if (nodesPerSecond! < 1000) return '$nodesPerSecond';
      if (nodesPerSecond! < 1000000) {
        final k = nodesPerSecond! / 1000.0;
        return k >= 100 ? '${k.toStringAsFixed(0)}k' : '${k.toStringAsFixed(1)}k';
      }
      final m = nodesPerSecond! / 1000000.0;
      return '${m.toStringAsFixed(2)}M';
    }
    if (isLc0 || isMaia) return 'N/A';
    return '—';
  }

  String get formattedDepth {
    if (depth == null || depth! <= 0) return '—';
    if (seldepth != null && seldepth! > depth!) return '$depth/$seldepth';
    return '$depth';
  }

  String get formattedTime {
    if (timeMs == null || timeMs! <= 0) return '—';
    if (timeMs! < 1000) return '${timeMs}ms';
    return '${(timeMs! / 1000).toStringAsFixed(1)}s';
  }

  static String _formatNumber(int n) {
    if (n < 1000) return '$n';
    final str = n.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}

extension NullableIntOperators on int? {
  bool operator >(num other) => this != null && this! > other;
  bool operator <(num other) => this != null && this! < other;
  bool operator >=(num other) => this != null && this! >= other;
  bool operator <=(num other) => this != null && this! <= other;
  num operator /(num other) => (this != null) ? this! / other : 0;
}
