import 'candidate_arrow.dart';
import 'chess_move.dart';
import '../utils/san_formatter.dart';
import '../utils/score_adapters.dart';
export '../services/engine_trace_logger.dart' show EngineSearchState, EngineActivationState;
export 'candidate_arrow.dart';
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
  idle,
  starting,
  ready,
  analyzing,
  stopping,
  error,
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
  final int totalNodes;
  final int nps;
  final int depth;
  final int seldepth;
  final int timeMs;
  final int hashfull;
  final int tbhits;
  final String? bestmove;
  final String? currmove;
  final int? currmovenumber;
  final String currentFen;
  final String cpuUtilization;
  final int visits;
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
    this.totalNodes = 0,
    this.nps = 0,
    this.depth = 0,
    this.seldepth = 0,
    this.timeMs = 0,
    this.hashfull = 0,
    this.tbhits = 0,
    this.bestmove,
    this.currmove,
    this.currmovenumber,
    this.currentFen = '',
    this.cpuUtilization = '',
    this.visits = 0,
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
  final int depth;
  final int seldepth;
  final int nodes;
  final int nps;
  final double? visitPercentage;
  final double? policyPercentage;
  final double? utility;
  final double? movesLeft;
  final int positionRevision;
  final int analysisRequestId;
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
    this.depth = 0,
    this.seldepth = 0,
    this.nodes = 0,
    this.nps = 0,
    this.visitPercentage,
    this.policyPercentage,
    this.utility,
    this.movesLeft,
    this.positionRevision = 0,
    this.analysisRequestId = 0,
    this.evaluation,
    NormalizedEvaluation? normalizedEvaluation,
  })  : expectedScore = expectedScore ?? winPercentage,
        whiteExpectedScore = whiteExpectedScore ?? whiteWinPercentage,
        normalizedEvaluation = normalizedEvaluation ?? evaluation?.normalized;

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
      if (depth > 0) parts.add('d: $depth');
      if (nodes > 0) parts.add('nodes: $nodes');
      if (nps > 0) parts.add('${(nps / 1000).toStringAsFixed(0)}k nps');
    }
    return '(${parts.join(', ')})';
  }
}

class PositionAnalysis {
  final String fen;
  final int positionRevision;
  final int analysisRequestId;
  final int totalNodes;
  final int nodesPerSecond;
  final int depth;
  final List<PvLine> pvLines;
  final List<CandidateArrow> candidateArrows;
  final bool isAnalyzing;
  final String? engineName;
  final EngineDiagnostics? diagnostics;

  const PositionAnalysis({
    required this.fen,
    this.positionRevision = 0,
    this.analysisRequestId = 0,
    this.totalNodes = 0,
    this.nodesPerSecond = 0,
    this.depth = 0,
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

  String get formattedHeader =>
      'Nodes: $totalNodes, N/s: $nodesPerSecond${depth > 0 ? ', Depth: $depth' : ''}';
}
