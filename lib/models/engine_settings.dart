import 'engine_analysis.dart';

enum MaiaThinkingProfile {
  instant,
  natural,
  humanLike,
}

class EngineSettings {
  EngineType activeEngine;
  int threads;
  int hashSizeMb;
  int multiPv;
  String lc0Backend;
  String? weightsPath;
  String? syzygyPath;
  int? nodeLimit;
  double? smartPruningFactor;
  Map<String, String> customUciOptions;

  String? selectedMaiaId;

  // Play Mode specific settings
  bool limitStrength;
  int? uciElo;
  int moveOverheadMs;
  MaiaThinkingProfile maiaThinkingProfile;

  // Arrowhead and presentation settings
  ArrowheadType arrowheadType;
  ArrowFilterLc0 arrowFilterLc0;
  ArrowFilterOthers arrowFilterOthers;
  Set<String> infoboxStats;

  bool get isMaiaActive => activeEngine == EngineType.lc0 && selectedMaiaId != null;

  EngineSettings({
    this.activeEngine = EngineType.stockfish,
    this.threads = 1,
    this.hashSizeMb = 16,
    this.multiPv = 3,
    this.lc0Backend = 'auto',
    this.weightsPath,
    this.syzygyPath,
    this.nodeLimit,
    this.smartPruningFactor,
    Map<String, String>? customUciOptions,
    this.selectedMaiaId,
    this.limitStrength = false,
    this.uciElo,
    this.moveOverheadMs = 10,
    this.maiaThinkingProfile = MaiaThinkingProfile.humanLike,
    this.arrowheadType = ArrowheadType.winrate,
    this.arrowFilterLc0 = ArrowFilterLc0.all,
    this.arrowFilterOthers = ArrowFilterOthers.all,
    Set<String>? infoboxStats,
  })  : customUciOptions = customUciOptions ?? {},
        infoboxStats = infoboxStats ??
            {
              'winrate',
              'nodePct',
              'policy',
              'multipv',
              'movesLeft',
              'depth',
              'nodes',
              'nps',
              'wdl',
            };

  static const Object _sentinel = Object();

  EngineSettings copyWith({
    EngineType? activeEngine,
    int? threads,
    int? hashSizeMb,
    int? multiPv,
    String? lc0Backend,
    Object? weightsPath = _sentinel,
    Object? syzygyPath = _sentinel,
    Object? nodeLimit = _sentinel,
    double? smartPruningFactor,
    Map<String, String>? customUciOptions,
    Object? selectedMaiaId = _sentinel,
    bool? limitStrength,
    Object? uciElo = _sentinel,
    int? moveOverheadMs,
    MaiaThinkingProfile? maiaThinkingProfile,
    ArrowheadType? arrowheadType,
    ArrowFilterLc0? arrowFilterLc0,
    ArrowFilterOthers? arrowFilterOthers,
    Set<String>? infoboxStats,
  }) {
    return EngineSettings(
      activeEngine: activeEngine ?? this.activeEngine,
      threads: threads ?? this.threads,
      hashSizeMb: hashSizeMb ?? this.hashSizeMb,
      multiPv: multiPv ?? this.multiPv,
      lc0Backend: lc0Backend ?? this.lc0Backend,
      weightsPath: identical(weightsPath, _sentinel) ? this.weightsPath : (weightsPath as String?),
      syzygyPath: identical(syzygyPath, _sentinel) ? this.syzygyPath : (syzygyPath as String?),
      nodeLimit: identical(nodeLimit, _sentinel) ? this.nodeLimit : (nodeLimit as int?),
      smartPruningFactor: smartPruningFactor ?? this.smartPruningFactor,
      customUciOptions: customUciOptions ?? Map.from(this.customUciOptions),
      selectedMaiaId: identical(selectedMaiaId, _sentinel) ? this.selectedMaiaId : (selectedMaiaId as String?),
      limitStrength: limitStrength ?? this.limitStrength,
      uciElo: identical(uciElo, _sentinel) ? this.uciElo : (uciElo as int?),
      moveOverheadMs: moveOverheadMs ?? this.moveOverheadMs,
      maiaThinkingProfile: maiaThinkingProfile ?? this.maiaThinkingProfile,
      arrowheadType: arrowheadType ?? this.arrowheadType,
      arrowFilterLc0: arrowFilterLc0 ?? this.arrowFilterLc0,
      arrowFilterOthers: arrowFilterOthers ?? this.arrowFilterOthers,
      infoboxStats: infoboxStats ?? Set.from(this.infoboxStats),
    );
  }

  Map<String, dynamic> toJson() => {
        'activeEngine': activeEngine.name,
        'threads': threads,
        'hashSizeMb': hashSizeMb,
        'multiPv': multiPv,
        'lc0Backend': lc0Backend,
        'weightsPath': weightsPath,
        'syzygyPath': syzygyPath,
        'nodeLimit': nodeLimit,
        'smartPruningFactor': smartPruningFactor,
        'customUciOptions': customUciOptions,
        'selectedMaiaId': selectedMaiaId,
        'arrowheadType': arrowheadType.name,
        'arrowFilterLc0': arrowFilterLc0.name,
        'arrowFilterOthers': arrowFilterOthers.name,
        'infoboxStats': infoboxStats.toList(),
      };

  factory EngineSettings.fromJson(Map<String, dynamic> json) {
    EngineType engine = EngineType.stockfish;
    if (json['activeEngine'] != null) {
      engine = EngineType.values.firstWhere(
        (e) => e.name == json['activeEngine'],
        orElse: () => EngineType.stockfish,
      );
    }

    ArrowheadType arrowType = ArrowheadType.winrate;
    if (json['arrowheadType'] != null) {
      arrowType = ArrowheadType.values.firstWhere(
        (e) => e.name == json['arrowheadType'],
        orElse: () => ArrowheadType.winrate,
      );
    }

    ArrowFilterLc0 filterLc0 = ArrowFilterLc0.all;
    if (json['arrowFilterLc0'] != null) {
      filterLc0 = ArrowFilterLc0.values.firstWhere(
        (e) => e.name == json['arrowFilterLc0'],
        orElse: () => ArrowFilterLc0.all,
      );
    }

    ArrowFilterOthers filterOthers = ArrowFilterOthers.all;
    if (json['arrowFilterOthers'] != null) {
      filterOthers = ArrowFilterOthers.values.firstWhere(
        (e) => e.name == json['arrowFilterOthers'],
        orElse: () => ArrowFilterOthers.all,
      );
    }

    Set<String>? infoStats;
    if (json['infoboxStats'] != null && json['infoboxStats'] is List) {
      infoStats = Set<String>.from(json['infoboxStats'] as List);
    }

    return EngineSettings(
      activeEngine: engine,
      threads: json['threads'] as int? ?? 1,
      hashSizeMb: json['hashSizeMb'] as int? ?? 16,
      multiPv: json['multiPv'] as int? ?? 3,
      lc0Backend: json['lc0Backend'] as String? ?? 'auto',
      weightsPath: json['weightsPath'] as String?,
      syzygyPath: json['syzygyPath'] as String?,
      nodeLimit: json['nodeLimit'] as int?,
      smartPruningFactor: (json['smartPruningFactor'] as num?)?.toDouble(),
      customUciOptions: json['customUciOptions'] != null
          ? Map<String, String>.from(json['customUciOptions'] as Map)
          : {},
      selectedMaiaId: json['selectedMaiaId'] as String?,
      arrowheadType: arrowType,
      arrowFilterLc0: filterLc0,
      arrowFilterOthers: filterOthers,
      infoboxStats: infoStats,
    );
  }
}
