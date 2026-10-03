import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/chess_move.dart';
import '../models/chess_position.dart';
import '../models/engine_analysis.dart';
import '../models/engine_settings.dart';
import '../models/uci_option.dart';
import '../utils/score_adapters.dart';
import '../utils/win_rate_calculator.dart';
import 'engine_coordinator.dart';
import 'engine_trace_logger.dart';
import 'native_engine_runner.dart';

class UciEngineService {
  Process? _engineProcess;
  bool _processExited = false;
  bool get isProcessAlive => _engineProcess != null && !_processExited;
  int get activeProcessCount => isProcessAlive ? 1 : 0;
  bool _isPausedForBackground = false;
  bool get isPausedForBackground => _isPausedForBackground;
  bool _isAnalysisPaused = false;
  bool get isAnalysisPaused => _isAnalysisPaused;

  EngineSettings _settings;
  EngineSettings get settings => _settings;
  int _pvsReceivedCount = 0;

  final ValueNotifier<NormalizedEvaluation> _evaluationNotifier =
      ValueNotifier<NormalizedEvaluation>(NormalizedEvaluation.neutral);
  ValueListenable<NormalizedEvaluation> get evaluationNotifier => _evaluationNotifier;

  final ValueNotifier<PositionAnalysis?> _analysisNotifier =
      ValueNotifier<PositionAnalysis?>(null);
  ValueListenable<PositionAnalysis?> get analysisNotifier => _analysisNotifier;

  // Engine Activation State (Separate from search state)
  EngineActivationState _activationState = EngineActivationState.enabled;
  EngineActivationState get activationState => _activationState;
  bool get isEngineEnabled =>
      _activationState == EngineActivationState.enabled ||
      _activationState == EngineActivationState.starting;

  // Search State Machine (Nibbler model)
  AnalysisDataState _searchState = AnalysisDataState.idle;
  AnalysisDataState get searchState => _searchState;

  // Lifecycle State for UI diagnostics
  EngineLifecycleState _lifecycleState = EngineLifecycleState.uninitialized;
  EngineLifecycleState get lifecycleState => _lifecycleState;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;
  bool get isEngineReady => _lifecycleState == EngineLifecycleState.ready;

  // Engine Session & Monotonic Revision/Request Tracking
  int _engineSessionId = 0;
  int get engineSessionId => _engineSessionId;

  int _positionRevision = 0;
  int _analysisRequestId = 0;
  int get positionRevision => _positionRevision;
  int get analysisRequestId => _analysisRequestId;

  AnalysisGeneration get currentGeneration => AnalysisGeneration(
        positionRevision: _positionRevision,
        analysisRequestId: _analysisRequestId,
        engineSessionId: _engineSessionId,
      );

  String get effectiveEngineDisplayName {
    if (_settings.isMaiaActive && _settings.selectedMaiaId != null) {
      final eloStr = _settings.selectedMaiaId!.replaceAll('maia_', '');
      return 'Maia $eloStr';
    }
    return _settings.activeEngine.displayName;
  }

  int? get currentMaiaElo {
    if (_settings.isMaiaActive && _settings.selectedMaiaId != null) {
      return int.tryParse(_settings.selectedMaiaId!.replaceAll('maia_', ''));
    }
    return null;
  }

  String? _activeSearchFen;
  String? _pendingSearchFen;
  int? _pendingRequestId;

  ChessPosition _currentPosition = ChessPosition.initial();
  String _currentFen = ChessPosition.initialFen;
  bool _currentTurnIsWhite = true;

  int? _currentNodes;
  int? _currentNps;
  int? _currentDepth;
  int? _currentSeldepth;
  int? _currentTimeMs;

  int? get currentNodes => _currentNodes;
  int? get currentNps => _currentNps;
  int? get currentDepth => _currentDepth;
  int? get currentSeldepth => _currentSeldepth;
  int? get currentTimeMs => _currentTimeMs;

  final Map<int, PvLine> _currentLines = {};

  // Candidate arrows map indexed by MultiPV rank
  final Map<int, CandidateArrow> _candidateArrowsMap = {};

  // Real Lc0 root move telemetry caches (per position)
  final Map<String, double> _positionPolicyCache = {};
  final Map<String, int> _positionVisitsCache = {};
  final Map<String, double> _positionMlhCache = {};
  final Map<String, List<PvMoveItem>> _pvParseCache = {};

  // Engine diagnostic detection
  String _detectedBackend = 'auto';
  String _detectedDevice = 'CPU';
  String _detectedNetwork = 'default';
  String _engineVersion = '';
  String get engineVersion => _engineVersion;

  final Map<String, UciOption> _supportedUciOptions = {};
  Map<String, UciOption> get supportedUciOptions => Map.unmodifiable(_supportedUciOptions);

  bool get supportsLimitStrength => _supportedUciOptions.containsKey('UCI_LimitStrength');
  int? get minElo => _supportedUciOptions['UCI_Elo']?.min;
  int? get maxElo => _supportedUciOptions['UCI_Elo']?.max;

  Completer<String?>? _gameMoveCompleter;
  Completer<CandidateArrow?>? _hintCompleter;

  int _currentHashfull = 0;
  int _currentTbhits = 0;
  String? _lastBestmove;
  String? _currentCurrmove;
  int? _currentCurrmovenumber;

  int _requestedThreads = 1;
  int _requestedHashMb = 128;
  int _requestedMultiPv = 3;
  bool _optionsApplied = false;
  bool _readyOkReceived = false;

  Completer<void>? _readyCompleter;
  Completer<void>? _stopCompleter;

  Timer? _throttleTimer;
  bool _hasPendingUpdate = false;
  Timer? _stoppingWatchdogTimer;

  void _armStoppingWatchdog() {
    _stoppingWatchdogTimer?.cancel();
    _stoppingWatchdogTimer = Timer(const Duration(milliseconds: 650), () {
      if (_searchState == AnalysisDataState.stopping) {
        if (kDebugMode) {
          developer.log('Stopping watchdog expired - forcing recovery', name: 'UciEngineService');
        }
        _handleBestMove('bestmove (none)');
      }
    });
  }

  void _cancelStoppingWatchdog() {
    _stoppingWatchdogTimer?.cancel();
    _stoppingWatchdogTimer = null;
  }

  final _analysisController = StreamController<PositionAnalysis>.broadcast();
  Stream<PositionAnalysis> get analysisStream => _analysisController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  UciEngineService(this._settings);

  int? get _effectiveNodeLimit {
    if (_settings.isMaiaActive) return 1;
    if (_settings.activeEngine == EngineType.stockfish) return null;
    return _settings.nodeLimit;
  }

  Completer<void>? _initCompleter;

  Future<void> initializeEngine(String? binaryPath, {bool forceRestart = false, EngineSettings? settings}) async {
    final bool engineChanged = settings != null && settings.activeEngine != _settings.activeEngine;
    if (settings != null) {
      _settings = settings;
    }
    // 1. Idempotent session reuse: If engine process is already alive and ready/idle,
    // and no forced restart is requested and engine has not changed, reuse the session immediately.
    if (!forceRestart &&
        !engineChanged &&
        isProcessAlive &&
        _lifecycleState == EngineLifecycleState.ready) {
      _setLifecycle(_lifecycleState, '${_settings.activeEngine.displayName} active (reused session)');
      return;
    }

    _setLifecycle(EngineLifecycleState.initializing, 'Awaiting engine initialization...');

    if (binaryPath == null || !File(binaryPath).existsSync()) {
      _setLifecycle(EngineLifecycleState.error, '${_settings.activeEngine.displayName} failed to start: binary not found');
      return;
    }

    try {
      final List<String> args = [];
      if (_settings.activeEngine == EngineType.lc0) {
        String? weights = _settings.weightsPath;
        if (weights == null || weights.isEmpty || weights == '<built in>' || !File(weights).existsSync()) {
          // Check standard device fallback paths
          final fallbackCandidates = [
            '/sdcard/Android/data/org.chesscrack.app/files/maia-1100.pb.gz',
            '/sdcard/maia-1100.pb.gz',
            '/data/local/tmp/maia-1100.pb.gz',
          ];
          for (final candidate in fallbackCandidates) {
            if (File(candidate).existsSync()) {
              weights = candidate;
              _settings = _settings.copyWith(weightsPath: candidate);
              break;
            }
          }
        }
        if (weights != null &&
            weights.isNotEmpty &&
            weights != '<built in>' &&
            File(weights).existsSync()) {
          args.add('--weights=$weights');
        }
      }

      await _disposeProcess();
      _initCompleter = Completer<void>();
      _processExited = false;
      _engineVersion = '';
      _requestedThreads = _settings.threads;
      _requestedHashMb = _settings.hashSizeMb;
      _requestedMultiPv = _settings.multiPv;
      _optionsApplied = false;
      _readyOkReceived = false;
      _currentSeldepth = null;
      _currentTimeMs = null;
      _currentHashfull = 0;
      _currentTbhits = 0;
      _lastBestmove = null;
      _currentCurrmove = null;
      _currentCurrmovenumber = null;
      _currentLines.clear();
      _candidateArrowsMap.clear();
      _positionPolicyCache.clear();
      _positionVisitsCache.clear();
      _positionMlhCache.clear();
      _currentNodes = null;
      _currentNps = null;
      _currentDepth = null;
      _detectedBackend = 'auto';
      _detectedDevice = 'CPU';
      _detectedNetwork = 'default';
      _evaluationNotifier.value = NormalizedEvaluation.neutral;

      _engineSessionId++;
      final localSessionId = _engineSessionId;
      _engineProcess = await Process.start(binaryPath, args);
      _engineProcess!.exitCode.then((_) => _processExited = true);

      _engineProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _handleEngineOutput(line, sessionId: localSessionId));

      _engineProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((err) {
            _detectEngineMetadata(err);
            _statusController.add('Engine log: $err');
          });

      _sendCommand('uci');
      await _initCompleter?.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          // Timeout fallback
        },
      );
    } catch (e) {
      _setLifecycle(EngineLifecycleState.error, 'Failed to start ${_settings.activeEngine.displayName}: $e');
    }
  }

  /// Explicit user control: Enable engine analysis
  Future<void> enableEngine({String? binaryPath}) async {
    if (_activationState == EngineActivationState.enabled) return;

    _activationState = EngineActivationState.starting;
    _statusController.add('Enabling engine analysis...');

    if (_engineProcess == null) {
      final path = binaryPath ?? await NativeEngineRunner.getEngineExecutablePath(_settings.activeEngine);
      await initializeEngine(path);
    }

    if (_lifecycleState != EngineLifecycleState.error) {
      _activationState = EngineActivationState.enabled;
      _setLifecycle(EngineLifecycleState.ready, '${_settings.activeEngine.displayName} enabled');
    } else {
      _activationState = EngineActivationState.disabled;
      return;
    }
    EngineTraceLogger.instance.log(
      requestId: _analysisRequestId,
      activeFen: _currentFen,
      engineState: _searchState,
      activationState: _activationState,
      rawUciLine: 'ENGINE_ENABLED',
      action: 'ENABLE_ENGINE',
    );

    startAnalysis(_currentPosition);
  }

  /// Explicit user control: Completely disable engine analysis and clear state
  Future<void> disableEngine() async {
    if (_activationState == EngineActivationState.disabled) return;

    _activationState = EngineActivationState.stopping;
    _statusController.add('Stopping and disabling engine...');

    stopAnalysis();

    await _disposeProcess();

    _activationState = EngineActivationState.disabled;
    _setLifecycle(EngineLifecycleState.disposed, 'Engine disabled');

    // Completely clear candidate lines and evaluation
    _currentLines.clear();
    _candidateArrowsMap.clear();
    _positionPolicyCache.clear();
    _positionVisitsCache.clear();
    _positionMlhCache.clear();
    _currentNodes = null;
    _currentNps = null;
    _currentDepth = null;
    _currentSeldepth = null;
    _currentTimeMs = null;
    _activeSearchFen = null;
    _pendingSearchFen = null;

    EngineTraceLogger.instance.log(
      requestId: _analysisRequestId,
      activeFen: _currentFen,
      engineState: _searchState,
      activationState: _activationState,
      rawUciLine: 'ENGINE_DISABLED',
      action: 'DISABLE_ENGINE',
    );

    _evaluationNotifier.value = NormalizedEvaluation.neutral;

    // Force an empty analysis update so UI immediately removes all arrows and evaluation
    _emitThrottledAnalysis(force: true);
  }

  void _setLifecycle(EngineLifecycleState state, String statusMessage) {
    _lifecycleState = state;
    _statusController.add(statusMessage);
  }

  void _detectEngineMetadata(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('backend:') || lower.contains('using backend:')) {
      final parts = line.split(RegExp(r'[:=]'));
      if (parts.length > 1) {
        _detectedBackend = parts[1].trim().split(' ').first;
      }
    }
    if (lower.contains('openblas') || lower.contains('blas vendor')) {
      _detectedDevice = 'CPU (BLAS)';
    } else if (lower.contains('eigen')) {
      _detectedDevice = 'CPU (Eigen)';
    } else if (lower.contains('vulkan') || lower.contains('gpu') || lower.contains('opencl')) {
      _detectedDevice = 'GPU Accelerated';
    }
    if (lower.contains('weights') || lower.contains('loading weights')) {
      final parts = line.split(RegExp(r'[:=]'));
      if (parts.length > 1) {
        _detectedNetwork = parts.last.trim().split(Platform.pathSeparator).last;
      }
    }
  }

  bool _validateStreamLine({
    required int? sessionId,
    required String rawLine,
    bool isBestMove = false,
  }) {
    if (sessionId != null && sessionId != _engineSessionId) return false;
    if (_activationState != EngineActivationState.enabled) return false;
    if (_searchState == AnalysisDataState.stopping) {
      if (!isBestMove) {
        EngineTraceLogger.instance.log(
          requestId: _analysisRequestId,
          activeFen: _activeSearchFen ?? _currentFen,
          pendingFen: _pendingSearchFen,
          engineState: _searchState,
          activationState: _activationState,
          rawUciLine: rawLine,
          action: 'DISCARDED_STOPPING',
        );
        return false;
      }
      return true;
    }
    if (!isBestMove && _activeSearchFen != _currentFen) {
      EngineTraceLogger.instance.log(
        requestId: _analysisRequestId,
        activeFen: _activeSearchFen ?? _currentFen,
        pendingFen: _pendingSearchFen,
        engineState: _searchState,
        activationState: _activationState,
        rawUciLine: rawLine,
        action: 'DISCARDED_FEN_MISMATCH',
      );
      return false;
    }
    return true;
  }

  void _handleEngineOutput(String line, {int? sessionId}) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    if (sessionId != null && sessionId != _engineSessionId) return;

    _detectEngineMetadata(trimmed);

    if (trimmed.startsWith('id name ')) {
      _engineVersion = trimmed.substring(8).trim();
    } else if (trimmed.startsWith('option name ')) {
      final opt = UciOption.parse(trimmed);
      if (opt != null) {
        _supportedUciOptions[opt.name] = opt;
      }
    } else if (trimmed == 'uciok') {
      _configureEngineOptions();
      _sendCommand('isready');
    } else if (trimmed == 'readyok') {
      _readyOkReceived = true;
      _setLifecycle(EngineLifecycleState.ready, '${_settings.activeEngine.displayName} ready');
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
      if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
        _readyCompleter!.complete();
      }
      if (_isAnalyzing && _activationState == EngineActivationState.enabled && _searchState != AnalysisDataState.searching) {
        _startSearchOnEngine();
      }
    } else if (trimmed.startsWith('info string ')) {
      _parseInfoStringLine(trimmed, sessionId: sessionId);
    } else if (trimmed.startsWith('info ')) {
      _parseInfoLine(trimmed, sessionId: sessionId);
    } else if (trimmed == 'bestmove' || trimmed.startsWith('bestmove ')) {
      _handleBestMove(trimmed, sessionId: sessionId);
    }
  }

  void _handleBestMove(String line, {int? sessionId}) {
    _cancelStoppingWatchdog();
    if (!_validateStreamLine(sessionId: sessionId ?? _engineSessionId, rawLine: line, isBestMove: true)) {
      return;
    }

    final bmTokens = line.trim().split(RegExp(r'\s+'));
    if (bmTokens.length > 1 && bmTokens[1] != '(none)') {
      _lastBestmove = bmTokens[1];
    }
    final bool wasGameOrHint = _gameMoveCompleter != null || _hintCompleter != null;
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      _stopCompleter!.complete();
    }
    if (_gameMoveCompleter != null && !_gameMoveCompleter!.isCompleted) {
      _gameMoveCompleter!.complete(_lastBestmove);
      _gameMoveCompleter = null;
    }
    if (_hintCompleter != null && !_hintCompleter!.isCompleted) {
      var topArrow = _candidateArrowsMap[1] ?? (_candidateArrowsMap.isNotEmpty ? _candidateArrowsMap.values.first : null);
      if (topArrow == null && _lastBestmove != null && _lastBestmove != '(none)') {
        final candMove = _currentPosition.findLegalMoveByUci(_lastBestmove!);
        if (candMove != null) {
          topArrow = CandidateArrow(
            rank: 1,
            uciMove: _lastBestmove!,
            from: candMove.from,
            to: candMove.to,
            pvUci: [_lastBestmove!],
            pvSan: [candMove.san ?? _lastBestmove!],
            winProbability: 55.0,
            expectedScore: 55.0,
            depth: _currentDepth ?? 12,
            positionRevision: _positionRevision,
            requestId: _analysisRequestId,
            engineSessionId: _engineSessionId,
            sourceFen: _currentFen,
            style: _buildArrowStyle(rank: 1, expectedScore: 55.0),
          );
        }
      }
      _hintCompleter!.complete(topArrow);
      _hintCompleter = null;
    }

    if (wasGameOrHint || EngineCoordinator().activeLeaseType == EngineLeaseType.play) {
      _searchState = AnalysisDataState.idle;
      _isAnalyzing = false;
      _activeSearchFen = null;
      _setLifecycle(EngineLifecycleState.ready, 'Engine idle');
      return;
    }

    EngineTraceLogger.instance.log(
      requestId: _analysisRequestId,
      activeFen: _activeSearchFen ?? _currentFen,
      pendingFen: _pendingSearchFen,
      engineState: _searchState,
      activationState: _activationState,
      rawUciLine: line,
      action: _searchState == AnalysisDataState.stopping ? 'BESTMOVE_STOP_COMPLETION' : 'BESTMOVE_NATURAL_STOP',
    );

    if (_searchState == AnalysisDataState.stopping) {
      // Bestmove from previous aborted search: treat strictly as STOP COMPLETION
      _searchState = AnalysisDataState.idle;

      if (_pendingSearchFen != null && _activationState == EngineActivationState.enabled) {
        // Launch pending search cleanly
        final fenToSearch = _pendingSearchFen!;
        final reqId = _pendingRequestId ?? _analysisRequestId;
        _pendingSearchFen = null;
        _pendingRequestId = null;

        _activeSearchFen = fenToSearch;
        _searchState = AnalysisDataState.searching;
        _isAnalyzing = true;
        _currentNodes = null;
        _currentNps = null;
        _currentDepth = null;
        _currentSeldepth = null;
        _currentTimeMs = null;
        _currentHashfull = 0;
        _currentTbhits = 0;
        _currentLines.clear();
        _candidateArrowsMap.clear();

        _setLifecycle(EngineLifecycleState.ready, 'Analyzing with ${_settings.activeEngine.displayName} (Req #$reqId)');
        _sendCommand('position fen $fenToSearch');
        final effectiveNodeLimit = _effectiveNodeLimit;
        if (effectiveNodeLimit != null) {
          _sendCommand('go nodes $effectiveNodeLimit');
        } else {
          _sendCommand('go infinite');
        }

        EngineTraceLogger.instance.log(
          requestId: reqId,
          activeFen: fenToSearch,
          engineState: _searchState,
          activationState: _activationState,
          rawUciLine: 'position fen $fenToSearch / go nodes $effectiveNodeLimit',
          action: 'LAUNCHED_PENDING_SEARCH',
        );
      } else {
        _isAnalyzing = false;
        _activeSearchFen = null;
        _searchState = _isAnalysisPaused
            ? AnalysisDataState.paused
            : AnalysisDataState.idle;
        _setLifecycle(
          EngineLifecycleState.ready,
          _isAnalysisPaused ? 'Analysis paused' : 'Engine stopped',
        );
        _emitThrottledAnalysis(force: true);
      }
    } else if (_searchState == AnalysisDataState.searching) {
      final effectiveNodeLimit = _effectiveNodeLimit;
      if (effectiveNodeLimit != null) {
        // Natural stop because an explicit node limit was set and reached
        _searchState = AnalysisDataState.completed;
        _isAnalyzing = false;
        _setLifecycle(EngineLifecycleState.ready, 'Analysis complete ($effectiveNodeLimit nodes reached)');
        _emitThrottledAnalysis(force: true);
      } else if (_currentPosition.legalMoves.isEmpty || _lastBestmove == '(none)') {
        // Natural stop because position has no legal moves (checkmate/stalemate)
        _searchState = AnalysisDataState.completed;
        _isAnalyzing = false;
        _setLifecycle(EngineLifecycleState.ready, 'Analysis complete (game end)');
        _emitThrottledAnalysis(force: true);
      } else {
        // In continuous analysis mode (go infinite), an unexpected bestmove while in searching state
        // is typically a delayed bestmove from an old search or transient stop.
        // We MUST re-ensure the engine is searching the active FEN rather than prematurely dying!
        EngineTraceLogger.instance.log(
          requestId: _analysisRequestId,
          activeFen: _currentFen,
          engineState: _searchState,
          activationState: _activationState,
          rawUciLine: line,
          action: 'BESTMOVE_RESTART_INFINITE',
        );
        _sendCommand('position fen $_currentFen');
        _sendCommand('go infinite');
      }
    }
  }

  Future<void> waitForStopCompletion({Duration timeout = const Duration(milliseconds: 600)}) async {
    if (_searchState != AnalysisDataState.stopping) return;
    _stopCompleter = Completer<void>();
    try {
      await _stopCompleter!.future.timeout(timeout);
    } catch (_) {
      _searchState = AnalysisDataState.idle;
    } finally {
      _stopCompleter = null;
    }
  }

  Future<void> _waitForReadyOk({Duration timeout = const Duration(milliseconds: 1500)}) async {
    if (_engineProcess == null || !isProcessAlive) return;
    _readyCompleter = Completer<void>();
    _readyOkReceived = false;
    _sendCommand('isready');
    try {
      await _readyCompleter!.future.timeout(timeout);
    } catch (_) {
      // Timeout fallback
    } finally {
      _readyCompleter = null;
    }
  }

  void _configureEngineOptions() {
    _requestedThreads = _settings.threads;
    _requestedHashMb = _settings.hashSizeMb;
    _requestedMultiPv = _settings.multiPv;

    _sendCommand('setoption name Threads value ${_settings.threads}');

    if (_settings.activeEngine == EngineType.lc0) {
      // 1. Mandatory native WDL for Lc0
      _sendCommand('setoption name UCI_ShowWDL value true');

      // 2. Mandatory Moves Left Head for Lc0
      _sendCommand('setoption name UCI_ShowMovesLeft value true');

      // 3. Verbose move stats (Policy P, visits N, MLH M)
      _sendCommand('setoption name VerboseMoveStats value true');

      // 4. Per PV counters (nodes per multipv line)
      _sendCommand('setoption name PerPVCounters value true');

      // 5. MultiPV configured up to 5 candidates
      final liveMultiPv = _settings.multiPv.clamp(1, 5);
      _sendCommand('setoption name MultiPV value $liveMultiPv');

      // 6. Backend (CPU BLAS / Eigen / Auto)
      if (_settings.lc0Backend != 'auto') {
        _sendCommand('setoption name Backend value ${_settings.lc0Backend}');
      }

      // 7. Weights
      if (_settings.weightsPath != null && _settings.weightsPath!.isNotEmpty) {
        _sendCommand('setoption name WeightsFile value ${_settings.weightsPath}');
      }

      // 8. Smart Pruning: Only send if explicitly configured by user; otherwise leave engine default (1.33)
      if (_settings.smartPruningFactor != null) {
        _sendCommand('setoption name SmartPruningFactor value ${_settings.smartPruningFactor}');
      }

      // 9. NNCacheSize (Lc0 does not use Stockfish Hash)
      final cacheSize = _settings.hashSizeMb * 10000;
      _sendCommand('setoption name NNCacheSize value $cacheSize');
    } else if (_settings.activeEngine == EngineType.stockfish) {
      // Stockfish options
      _sendCommand('setoption name Hash value ${_settings.hashSizeMb}');
      _sendCommand('setoption name MultiPV value ${_settings.multiPv}');
      _sendCommand('setoption name UCI_ShowWDL value true');
      if (supportsLimitStrength) {
        if (_settings.limitStrength) {
          _sendCommand('setoption name UCI_LimitStrength value true');
          final targetElo = (_settings.uciElo ?? 1600).clamp(minElo ?? 1320, maxElo ?? 3190);
          _sendCommand('setoption name UCI_Elo value $targetElo');
        } else {
          _sendCommand('setoption name UCI_LimitStrength value false');
        }
      }
      if (_supportedUciOptions.containsKey('Move Overhead')) {
        _sendCommand('setoption name Move Overhead value ${_settings.moveOverheadMs}');
      }
    }

    if (_settings.syzygyPath != null && _settings.syzygyPath!.isNotEmpty) {
      _sendCommand('setoption name SyzygyPath value ${_settings.syzygyPath}');
    }

    _settings.customUciOptions.forEach((key, val) {
      _sendCommand('setoption name $key value $val');
    });

    _optionsApplied = true;
  }

  /// Parses verbose move telemetry from Lc0 VerboseMoveStats:
  /// e.g. "info string e2e4  (322 ) N:       7 (+ 0) (P: 22.22%) (WL:  0.10589) (D: 0.480) (M: 167.4)..."
  void _parseInfoStringLine(String line, {int? sessionId}) {
    if (!_validateStreamLine(sessionId: sessionId ?? _engineSessionId, rawLine: line, isBestMove: false)) {
      return;
    }
    final afterPrefix = line.substring(12).trim();
    final tokens = afterPrefix.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return;

    final moveToken = tokens[0];
    if (moveToken == 'node' || moveToken.length < 4) return;

    final pMatch = RegExp(r'\(P:\s*([\d\.]+)%\)').firstMatch(line);
    if (pMatch != null) {
      final pVal = double.tryParse(pMatch.group(1)!);
      if (pVal != null) {
        _positionPolicyCache[moveToken] = pVal;
      }
    }

    final nMatch = RegExp(r'N:\s*(\d+)').firstMatch(line);
    if (nMatch != null) {
      final nVal = int.tryParse(nMatch.group(1)!);
      if (nVal != null) {
        _positionVisitsCache[moveToken] = nVal;
      }
    }

    final mMatch = RegExp(r'\(M:\s*([\d\.]+)\)').firstMatch(line);
    if (mMatch != null) {
      final mVal = double.tryParse(mMatch.group(1)!);
      if (mVal != null) {
        // Convert plies to moves if > 40, otherwise keep
        _positionMlhCache[moveToken] = mVal > 40 ? (mVal / 2.0) : mVal;
      }
    }

    // Update existing candidate arrow for this move if already present and matching current generation
    bool updated = false;
    for (final entry in _candidateArrowsMap.entries) {
      if (entry.value.uciMove == moveToken &&
          entry.value.positionRevision == _positionRevision &&
          entry.value.requestId == _analysisRequestId &&
          entry.value.engineSessionId == _engineSessionId) {
        _candidateArrowsMap[entry.key] = entry.value.copyWith(
          policyPercentage: _positionPolicyCache[moveToken],
          visits: _positionVisitsCache[moveToken] ?? entry.value.visits,
          movesLeft: _positionMlhCache[moveToken] ?? entry.value.movesLeft,
        );
        updated = true;
      }
    }

    if (updated) {
      _scheduleThrottledUpdate();
    }
  }

  void _parseInfoLine(String line, {int? sessionId}) {
    if (!_validateStreamLine(sessionId: sessionId ?? _engineSessionId, rawLine: line, isBestMove: false)) {
      return;
    }

    final capturedRev = _positionRevision;
    final capturedReqId = _analysisRequestId;
    final capturedSessId = _engineSessionId;

    final tokens = line.split(RegExp(r'\s+'));
    int multipv = 1;
    int? scoreCp;
    int? scoreMate;
    int? depth = _currentDepth;
    int? seldepth = _currentSeldepth;
    int? nodes = _currentNodes;
    int? nps = _currentNps;
    List<int>? wdl;
    double? visitPct;
    double? policyPct;
    double? utility;
    double? movesLeft;
    final movesUci = <String>[];

    for (int i = 1; i < tokens.length; i++) {
      final t = tokens[i];
      if (t == 'multipv' && i + 1 < tokens.length) {
        multipv = int.tryParse(tokens[++i]) ?? 1;
      } else if (t == 'depth' && i + 1 < tokens.length) {
        final dVal = int.tryParse(tokens[++i]);
        if (dVal != null) {
          depth = depth != null ? math.max(depth, dVal) : dVal;
          _currentDepth = _currentDepth != null ? math.max(_currentDepth!, dVal) : dVal;
        }
      } else if (t == 'seldepth' && i + 1 < tokens.length) {
        final sdVal = int.tryParse(tokens[++i]);
        if (sdVal != null) {
          seldepth = seldepth != null ? math.max(seldepth, sdVal) : sdVal;
          _currentSeldepth = _currentSeldepth != null ? math.max(_currentSeldepth!, sdVal) : sdVal;
        }
      } else if (t == 'time' && i + 1 < tokens.length) {
        final tVal = int.tryParse(tokens[++i]);
        if (tVal != null) {
          _currentTimeMs = _currentTimeMs != null ? math.max(_currentTimeMs!, tVal) : tVal;
        }
      } else if (t == 'nodes' && i + 1 < tokens.length) {
        final nVal = int.tryParse(tokens[++i]);
        if (nVal != null) {
          nodes = nodes != null ? math.max(nodes, nVal) : nVal;
          _currentNodes = _currentNodes != null ? math.max(_currentNodes!, nVal) : nVal;
        }
      } else if (t == 'nps' && i + 1 < tokens.length) {
        final npsVal = int.tryParse(tokens[++i]);
        if (npsVal != null && npsVal > 0) {
          if (multipv == 1 || _currentNps == null || _currentNps == 0) {
            nps = npsVal;
            _currentNps = npsVal;
          } else {
            nps = nps != null ? math.max(nps, npsVal) : npsVal;
            _currentNps = _currentNps != null ? math.max(_currentNps!, npsVal) : npsVal;
          }
        }
      } else if (t == 'hashfull' && i + 1 < tokens.length) {
        _currentHashfull = int.tryParse(tokens[++i]) ?? _currentHashfull;
      } else if (t == 'tbhits' && i + 1 < tokens.length) {
        _currentTbhits = int.tryParse(tokens[++i]) ?? _currentTbhits;
      } else if (t == 'currmove' && i + 1 < tokens.length) {
        _currentCurrmove = tokens[++i];
      } else if (t == 'currmovenumber' && i + 1 < tokens.length) {
        _currentCurrmovenumber = int.tryParse(tokens[++i]) ?? _currentCurrmovenumber;
      } else if (t == 'movesleft' && i + 1 < tokens.length) {
        movesLeft = double.tryParse(tokens[++i]);
      } else if (t == 'score' && i + 2 < tokens.length) {
        final scoreType = tokens[++i];
        final scoreVal = int.tryParse(tokens[++i]);
        if (scoreType == 'cp') {
          scoreCp = scoreVal;
        } else if (scoreType == 'mate') {
          scoreMate = scoreVal;
        }
      } else if (t == 'wdl' && i + 3 < tokens.length) {
        final w = int.tryParse(tokens[++i]) ?? 0;
        final d = int.tryParse(tokens[++i]) ?? 0;
        final l = int.tryParse(tokens[++i]) ?? 0;
        wdl = [w, d, l];
      } else if (t == 'n' && i + 1 < tokens.length) {
        visitPct = double.tryParse(tokens[++i]);
      } else if (t == 'p' && i + 1 < tokens.length) {
        policyPct = double.tryParse(tokens[++i]);
      } else if (t == 'u' && i + 1 < tokens.length) {
        utility = double.tryParse(tokens[++i]);
      } else if (t == 'pv') {
        for (int j = i + 1; j < tokens.length; j++) {
          movesUci.add(tokens[j]);
        }
        break;
      }
    }

    if (movesUci.isEmpty) return;

    // Strict revision, request, and session protection
    if (capturedRev != _positionRevision ||
        capturedReqId != _analysisRequestId ||
        capturedSessId != _engineSessionId) {
      return;
    }

    _pvsReceivedCount++;

    // Strict move legality validation via O(1) cached map lookup
    final firstMoveUci = movesUci.first;
    final candidateMove = _currentPosition.findLegalMoveByUci(firstMoveUci);
    if (candidateMove == null) {
      return;
    }

    // Engine-specific score adapter
    final EngineScoreAdapter adapter = _settings.activeEngine == EngineType.lc0
        ? const Lc0ScoreAdapter()
        : const StockfishScoreAdapter();

    final moveEvaluation = adapter.createEvaluation(
      move: candidateMove,
      positionRevision: capturedRev,
      analysisRequestId: capturedReqId,
      isWhiteTurn: _currentTurnIsWhite,
      multipv: multipv,
      scoreCp: scoreCp,
      scoreMate: scoreMate,
      wdl: wdl,
      nodes: nodes ?? 0,
      nps: nps ?? 0,
      depth: depth ?? 0,
      visitPct: visitPct,
      policyPct: policyPct ?? _positionPolicyCache[firstMoveUci],
      utility: utility,
      pvUci: movesUci,
    );

    final firstSan = candidateMove.san ?? firstMoveUci;

    final pvLine = PvLine(
      multipv: multipv,
      scoreCp: scoreCp,
      scoreMate: scoreMate,
      winPercentage: moveEvaluation.winProbability,
      whiteWinPercentage: moveEvaluation.whiteWinProbability,
      expectedScore: moveEvaluation.expectedScore,
      whiteExpectedScore: moveEvaluation.whiteExpectedScore,
      wdl: wdl,
      movesUci: movesUci,
      movesSan: [firstSan],
      pvMoves: const [],
      startFen: _currentFen,
      depth: depth,
      seldepth: seldepth,
      nodes: nodes,
      nps: nps,
      visitPercentage: visitPct,
      policyPercentage: policyPct ?? _positionPolicyCache[firstMoveUci],
      utility: utility,
      movesLeft: movesLeft ?? _positionMlhCache[firstMoveUci],
      positionRevision: capturedRev,
      analysisRequestId: capturedReqId,
      engineSessionId: capturedSessId,
      evaluation: moveEvaluation,
    );

    // Calculate real telemetry fields
    final double expScore = (wdl != null && wdl.length >= 3)
        ? (((wdl[0] + 0.5 * wdl[1]) / (wdl[0] + wdl[1] + wdl[2])) * 100.0)
        : moveEvaluation.expectedScore;
    final double winProb = expScore;

    final candidateVisits = nodes;
    final effectiveTotalNodes = math.max(_currentNodes ?? 0, candidateVisits ?? 0);
    final double? nodePct = (effectiveTotalNodes > 0 && candidateVisits != null)
        ? ((candidateVisits / effectiveTotalNodes) * 100.0)
        : visitPct;

    final arrowStyle = _buildArrowStyle(
      rank: multipv,
      expectedScore: expScore,
    );

    final candidateArrow = CandidateArrow(
      rank: multipv,
      uciMove: firstMoveUci,
      from: candidateMove.from,
      to: candidateMove.to,
      pvUci: movesUci,
      pvSan: [firstSan],
      winProbability: winProb,
      drawProbability: (wdl != null && wdl.length >= 3) ? (wdl[1] / 10.0) : null,
      lossProbability: (wdl != null && wdl.length >= 3) ? (wdl[2] / 10.0) : null,
      expectedScore: expScore,
      scoreCp: scoreCp,
      scoreMate: scoreMate,
      visits: candidateVisits,
      totalNodes: effectiveTotalNodes,
      nodePercentage: nodePct,
      policyPercentage: policyPct ?? _positionPolicyCache[firstMoveUci],
      movesLeft: movesLeft ?? _positionMlhCache[firstMoveUci],
      depth: depth,
      positionRevision: capturedRev,
      requestId: capturedReqId,
      engineSessionId: capturedSessId,
      sourceFen: _currentFen,
      style: arrowStyle,
    );

    _candidateArrowsMap[multipv] = candidateArrow;
    _currentLines[multipv] = pvLine;
    _scheduleThrottledUpdate();
  }

  ArrowVisualStyle _buildArrowStyle({
    required int rank,
    required double expectedScore,
  }) {
    final bool isMaia = _settings.isMaiaActive;

    final Color baseColor;
    if (isMaia) {
      // Blue palette for Maia human move predictions
      baseColor = rank == 1
          ? const Color(0xFF29B6F6) // Bright Cyan/Blue for top human move
          : (rank == 2
              ? const Color(0xFF0288D1) // Deep Blue
              : (rank == 3
                  ? const Color(0xFF01579B) // Navy Blue
                  : (rank == 4
                      ? const Color(0xFF5C6BC0) // Indigo
                      : const Color(0xFF7E57C2)))); // Deep Purple
    } else {
      // Green / WinRate palette for Stockfish / Alpha-Beta engines
      baseColor = rank == 1
          ? Color(WinRateCalculator.getArrowColorValue(expectedScore))
          : (rank == 2
              ? const Color(0xFF4CAF50) // Emerald Green
              : (rank == 3
                  ? const Color(0xFF81C784) // Light Green
                  : (rank == 4
                      ? const Color(0xFFA5D6A7) // Pale Green
                      : const Color(0xFFC8E6C9)))); // Mint
    }

    final opacity = rank == 1 ? 0.95 : (rank == 2 ? 0.85 : (rank == 3 ? 0.75 : 0.65));
    final strokeScale = rank == 1 ? 1.15 : (rank == 2 ? 0.95 : (rank == 3 ? 0.80 : 0.70));
    final headScale = rank == 1 ? 1.15 : (rank == 2 ? 0.95 : (rank == 3 ? 0.80 : 0.70));
    final badgeScale = rank == 1 ? 1.05 : (rank == 2 ? 0.95 : (rank == 3 ? 0.90 : 0.85));

    return ArrowVisualStyle(
      shaftColor: baseColor,
      badgeColor: baseColor,
      textColor: isMaia ? const Color(0xFFFFFFFF) : const Color(0xFF111111),
      borderColor: rank == 1 ? const Color(0xFFFFFFFF) : const Color(0x66000000),
      opacity: opacity,
      strokeWidthScale: strokeScale,
      arrowHeadScale: headScale,
      badgeScale: badgeScale,
      curvature: 0.0,
    );
  }

  void _scheduleThrottledUpdate() {
    _hasPendingUpdate = true;
    if (_throttleTimer == null || !_throttleTimer!.isActive) {
      _throttleTimer = Timer(const Duration(milliseconds: 100), () {
        if (_hasPendingUpdate) {
          _emitThrottledAnalysis();
          _hasPendingUpdate = false;
        }
      });
    }
  }

  void _emitThrottledAnalysis({bool force = false}) {
    if (!isEngineEnabled && !force) return;

    final rawLines = _currentLines.values
        .where((l) =>
            l.positionRevision == _positionRevision &&
            l.analysisRequestId == _analysisRequestId &&
            l.engineSessionId == _engineSessionId)
        .toList()
      ..sort((a, b) => a.multipv.compareTo(b.multipv));

    // Lazily resolve SAN and PvMoves for throttled update (capped to 14 plies, cached)
    final sortedLines = <PvLine>[];
    for (final line in rawLines) {
      if (line.movesUci.isEmpty) {
        sortedLines.add(line);
        continue;
      }
      final key = '${_currentFen}_${line.movesUci.take(14).join(' ')}';
      var cachedMoves = _pvParseCache[key];
      if (cachedMoves == null) {
        cachedMoves = SANFormatter.parsePvLine(
          _currentPosition,
          line.movesUci.take(14).toList(),
        );
        if (_pvParseCache.length > 500) {
          _pvParseCache.clear();
        }
        _pvParseCache[key] = cachedMoves;
      }
      final sanList = cachedMoves.map((m) => m.san).toList();
      final resolvedLine = line.copyWith(
        pvMoves: cachedMoves,
        movesSan: sanList.isNotEmpty ? sanList : line.movesSan,
      );
      _currentLines[line.multipv] = resolvedLine;
      sortedLines.add(resolvedLine);
    }

    final rawArrows = _candidateArrowsMap.values
        .where((a) =>
            a.positionRevision == _positionRevision &&
            a.requestId == _analysisRequestId &&
            a.engineSessionId == _engineSessionId)
        .toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    final totalCandidateVisits = rawArrows.fold<int>(0, (sum, a) => sum + (a.visits ?? 0));
    final effectiveTotalNodes = math.max(_currentNodes ?? 0, totalCandidateVisits);

    final resolvedArrows = <CandidateArrow>[];
    final Map<Square, List<CandidateArrow>> byFrom = {};
    for (final a in rawArrows) {
      byFrom.putIfAbsent(a.from, () => []).add(a);
    }

    final Map<int, List<String>> sanByRank = {
      for (final l in sortedLines) l.multipv: l.movesSan,
    };

    for (final a in rawArrows) {
      final siblings = byFrom[a.from] ?? [];
      double curvature = 0.0;
      if (siblings.length > 1) {
        final idx = siblings.indexOf(a);
        if (idx == 0) {
          curvature = 0.0;
        } else if (idx % 2 == 1) {
          curvature = -0.16 * ((idx + 1) ~/ 2);
        } else {
          curvature = 0.16 * (idx ~/ 2);
        }
      }

      final nodePct = (effectiveTotalNodes > 0 && a.visits != null)
          ? ((a.visits! / effectiveTotalNodes) * 100.0)
          : a.nodePercentage;

      resolvedArrows.add(a.copyWith(
        pvSan: sanByRank[a.rank] ?? a.pvSan,
        nodePercentage: nodePct,
        totalNodes: effectiveTotalNodes,
        style: a.style.copyWith(curvature: curvature),
      ));
    }

    final filteredArrows = filterCandidateArrows(
      arrows: resolvedArrows,
      settings: _settings,
    );

    int passedRevisionCount = 0;
    int passedLegalCount = 0;
    int renderedCount = 0;
    final arrowDiagnostics = <CandidateArrowDiagnostic>[];

    for (final a in resolvedArrows) {
      final bool isFiltered = !filteredArrows.any((f) => f.rank == a.rank);
      final bool coordsValid = a.from.file >= 0 && a.from.file <= 7 &&
                               a.from.rank >= 0 && a.from.rank <= 7 &&
                               a.to.file >= 0 && a.to.file <= 7 &&
                               a.to.rank >= 0 && a.to.rank <= 7 &&
                               (a.from != a.to);
      final bool isLegal = _currentPosition.findLegalMoveByUci(a.uciMove) != null;
      final bool missingReq = a.requestId <= 0;
      final bool staleReq = a.requestId != _analysisRequestId;
      final bool missingRev = a.positionRevision <= 0;
      final bool staleRev = a.positionRevision != _positionRevision;
      final bool staleSession = a.engineSessionId != _engineSessionId;

      final bool revPassed = !missingReq && !staleReq && !missingRev && !staleRev && !staleSession;
      if (!isFiltered && revPassed) {
        passedRevisionCount++;
        if (isLegal) {
          passedLegalCount++;
        }
      }

      String? reason;
      if (isFiltered) {
        reason = 'filteredByThreshold';
      } else if (missingReq) {
        reason = 'missingRequestId';
      } else if (staleReq) {
        reason = 'staleRequestId';
      } else if (missingRev) {
        reason = 'missingRevision';
      } else if (staleRev) {
        reason = 'staleRevision';
      } else if (staleSession) {
        reason = 'staleSessionId';
      } else if (!coordsValid) {
        reason = 'invalidCoordinates';
      } else if (!isLegal) {
        reason = 'illegalMove';
      }

      final bool isRendered = !isFiltered && revPassed && coordsValid && isLegal;
      if (isRendered) {
        renderedCount++;
      }

      arrowDiagnostics.add(CandidateArrowDiagnostic(
        rank: a.rank,
        uciMove: a.uciMove,
        sourceFen: a.sourceFen ?? _currentFen,
        arrowRevision: a.positionRevision,
        currentRevision: _positionRevision,
        arrowRequestId: a.requestId,
        currentRequestId: _analysisRequestId,
        isFiltered: isFiltered,
        isLegal: isLegal,
        isCoordsValid: coordsValid,
        isRendered: isRendered,
        rejectionReason: reason,
      ));
    }

    final diag = EngineDiagnostics(
      engineName: _settings.activeEngine.displayName,
      engineVersion: _engineVersion,
      backend: _detectedBackend != 'auto' ? _detectedBackend : _settings.lc0Backend,
      device: _detectedDevice,
      network: _detectedNetwork != 'default' ? _detectedNetwork : (_settings.weightsPath ?? 'embedded'),
      threads: _settings.threads,
      hashSizeMb: _settings.hashSizeMb,
      multiPv: _settings.multiPv,
      requestedThreads: _requestedThreads,
      requestedHashMb: _requestedHashMb,
      requestedMultiPv: _requestedMultiPv,
      optionsApplied: _optionsApplied,
      readyOkReceived: _readyOkReceived,
      totalNodes: _currentNodes,
      nps: _currentNps,
      depth: _currentDepth,
      seldepth: _currentSeldepth,
      timeMs: _currentTimeMs,
      hashfull: _currentHashfull,
      tbhits: _currentTbhits,
      bestmove: _lastBestmove,
      currmove: _currentCurrmove,
      currmovenumber: _currentCurrmovenumber,
      currentFen: _currentFen,
      cpuUtilization: '${_requestedThreads}t',
      visits: _currentNodes ?? 0,
      wdl: sortedLines.isNotEmpty ? sortedLines.first.wdl : null,
      topPv: sortedLines.isNotEmpty ? sortedLines.first.movesUci.take(6).join(' ') : null,
      positionRevision: _positionRevision,
      analysisRequestId: _analysisRequestId,
      lastUpdate: DateTime.now(),
      pvsReceived: _pvsReceivedCount,
      candidateArrowsCreated: rawArrows.length,
      arrowsAfterFilter: filteredArrows.length,
      painterReceived: filteredArrows.length,
      passedRevisionCheck: passedRevisionCount,
      passedLegalMoveCheck: passedLegalCount,
      painterRendered: renderedCount,
      arrowDiagnostics: arrowDiagnostics,
      activeProcessCount: activeProcessCount,
    );

    final posAnalysis = PositionAnalysis(
      fen: _currentFen,
      positionRevision: _positionRevision,
      analysisRequestId: _analysisRequestId,
      engineSessionId: _engineSessionId,
      totalNodes: _currentNodes,
      nodesPerSecond: _currentNps,
      depth: _currentDepth,
      seldepth: _currentSeldepth,
      timeMs: _currentTimeMs,
      pvLines: sortedLines,
      candidateArrows: filteredArrows,
      isAnalyzing: _isAnalyzing && isEngineEnabled,
      engineName: effectiveEngineDisplayName,
      searchState: _searchState,
      isMaia: _settings.isMaiaActive,
      maiaElo: currentMaiaElo,
      diagnostics: diag,
    );

    if (sortedLines.isNotEmpty && sortedLines.first.normalizedEvaluation != null) {
      _evaluationNotifier.value = sortedLines.first.normalizedEvaluation!.copyWith(
        positionRevision: _positionRevision,
        analysisRequestId: _analysisRequestId,
        fen: _currentFen,
        isEngineEnabled: isEngineEnabled,
      );
    } else if (!isEngineEnabled) {
      _evaluationNotifier.value = NormalizedEvaluation.neutral;
    }

    _analysisController.add(posAnalysis);
    _analysisNotifier.value = posAnalysis;
  }

  /// Starts or updates analysis for the given position using Nibbler continuous-analysis rules.
  /// Never thrashes the engine if analyzing the same FEN, unless [forceRestart] is requested (e.g. MultiPV change).
  void startAnalysis(ChessPosition position, {bool forceRestart = false}) {
    if (!isEngineEnabled) return;

    final newFen = position.toFen();

    // 1. Continuous analysis check: If already searching this exact position without forced restart, DO NOT restart!
    if (!forceRestart && _activeSearchFen == newFen && _isAnalyzing && _searchState == EngineSearchState.searching) {
      return;
    }

    _positionRevision++;
    _analysisRequestId++;

    _currentPosition = position;
    _currentFen = newFen;
    _currentTurnIsWhite = position.turn.isWhite;

    // Anchor evaluationNotifier to new position context to cancel old animation
    _evaluationNotifier.value = NormalizedEvaluation.neutral.copyWith(
      positionRevision: _positionRevision,
      analysisRequestId: _analysisRequestId,
      fen: newFen,
      isEngineEnabled: isEngineEnabled,
    );
    _analysisNotifier.value = null;

    _isAnalysisPaused = false;
    // Clear caches for new position
    _pvsReceivedCount = 0;
    _currentLines.clear();
    _candidateArrowsMap.clear();
    _pvParseCache.clear();
    _positionPolicyCache.clear();
    _positionVisitsCache.clear();
    _positionMlhCache.clear();
    _currentNodes = null;
    _currentNps = null;
    _currentDepth = null;
    _currentSeldepth = null;
    _currentTimeMs = null;
    _currentHashfull = 0;
    _currentTbhits = 0;
    _lastBestmove = null;
    _currentCurrmove = null;
    _currentCurrmovenumber = null;

    EngineTraceLogger.instance.log(
      requestId: _analysisRequestId,
      activeFen: newFen,
      engineState: _searchState,
      activationState: _activationState,
      rawUciLine: 'startAnalysis(Rev: #$_positionRevision, Req: #$_analysisRequestId)',
      action: 'START_OR_UPDATE_ANALYSIS',
    );

    if (_engineProcess == null) {
      _setLifecycle(EngineLifecycleState.error, '${_settings.activeEngine.displayName} process not running');
      return;
    }

    if (_searchState == EngineSearchState.searching) {
      // Nibbler dual protection: Queue new FEN and issue single atomic stop
      _pendingSearchFen = newFen;
      _pendingRequestId = _analysisRequestId;
      _searchState = EngineSearchState.stopping;
      _sendCommand('stop');
      _armStoppingWatchdog();

      EngineTraceLogger.instance.log(
        requestId: _analysisRequestId,
        activeFen: _activeSearchFen ?? newFen,
        pendingFen: newFen,
        engineState: _searchState,
        activationState: _activationState,
        rawUciLine: 'stop',
        action: 'ISSUED_STOP_FOR_PENDING_SEARCH',
      );
    } else if (_searchState == EngineSearchState.stopping) {
      // Already stopping: simply update the pending FEN and refresh watchdog
      _pendingSearchFen = newFen;
      _pendingRequestId = _analysisRequestId;
      _armStoppingWatchdog();

      EngineTraceLogger.instance.log(
        requestId: _analysisRequestId,
        activeFen: _activeSearchFen ?? newFen,
        pendingFen: newFen,
        engineState: _searchState,
        activationState: _activationState,
        rawUciLine: 'PENDING_UPDATE',
        action: 'UPDATED_PENDING_SEARCH',
      );
    } else {
      // Engine is idle or ready: start immediately
      _startSearchOnEngine();
    }
  }

  void _startSearchOnEngine() {
    if (_engineProcess == null || !isEngineEnabled) return;

    _activeSearchFen = _currentFen;
    _pendingSearchFen = null;
    _pendingRequestId = null;
    _searchState = EngineSearchState.searching;
    _isAnalyzing = true;

    _setLifecycle(EngineLifecycleState.ready, 'Analyzing with ${_settings.activeEngine.displayName} (Req #$_analysisRequestId)');
    _sendCommand('position fen $_currentFen');

    final effectiveNodeLimit = _effectiveNodeLimit;
    if (effectiveNodeLimit != null) {
      _sendCommand('go nodes $effectiveNodeLimit');
    } else {
      _sendCommand('go infinite');
    }

    EngineTraceLogger.instance.log(
      requestId: _analysisRequestId,
      activeFen: _currentFen,
      engineState: _searchState,
      activationState: _activationState,
      rawUciLine: 'position fen $_currentFen / go infinite',
      action: 'SEARCH_STARTED',
    );
  }

  /// Decoupled pause for user search control (e.g. from UI play/pause button).
  /// Halts UCI computation, sets searchState to AnalysisDataState.paused,
  /// but keeps candidate arrows, lines, and eval strictly intact.
  void pauseAnalysis() {
    if (!isEngineEnabled) return;
    _isAnalysisPaused = true;
    _isAnalyzing = false;
    _pendingSearchFen = null;
    _pendingRequestId = null;

    if (_engineProcess != null && _searchState == AnalysisDataState.searching) {
      _searchState = AnalysisDataState.stopping;
      _sendCommand('stop');
      _armStoppingWatchdog();
      EngineTraceLogger.instance.log(
        requestId: _analysisRequestId,
        activeFen: _activeSearchFen ?? _currentFen,
        engineState: _searchState,
        activationState: _activationState,
        rawUciLine: 'stop',
        action: 'PAUSE_ANALYSIS',
      );
    } else {
      _searchState = AnalysisDataState.paused;
    }

    _setLifecycle(EngineLifecycleState.ready, 'Analysis paused');
    _emitThrottledAnalysis(force: true);
  }

  /// Resumes search on the active position without clearing candidate arrows,
  /// PV lines, or evaluation state.
  void resumeAnalysis() {
    if (!isEngineEnabled) return;
    _isAnalysisPaused = false;
    _isAnalyzing = true;
    _analysisRequestId++;

    if (_engineProcess == null || !isProcessAlive) {
      _setLifecycle(EngineLifecycleState.error, '${_settings.activeEngine.displayName} process not running');
      return;
    }

    // Map existing lines and candidate arrows to new analysisRequestId so they stay intact
    for (final entry in _currentLines.entries.toList()) {
      _currentLines[entry.key] = entry.value.copyWith(analysisRequestId: _analysisRequestId);
    }
    for (final entry in _candidateArrowsMap.entries.toList()) {
      _candidateArrowsMap[entry.key] = entry.value.copyWith(requestId: _analysisRequestId);
    }

    _evaluationNotifier.value = _evaluationNotifier.value.copyWith(
      positionRevision: _positionRevision,
      analysisRequestId: _analysisRequestId,
      fen: _currentFen,
      isEngineEnabled: isEngineEnabled,
    );

    _startSearchOnEngine();
  }

  void stopAnalysis() {
    _isAnalysisPaused = false;
    _isAnalyzing = false;
    _pendingSearchFen = null;
    _pendingRequestId = null;
    _activeSearchFen = null;
    _pvsReceivedCount = 0;

    if (_engineProcess != null) {
      if (_searchState == EngineSearchState.searching) {
        _searchState = EngineSearchState.stopping;
        _sendCommand('stop');
        _armStoppingWatchdog();
      }
    } else {
      _searchState = EngineSearchState.idle;
    }

    _setLifecycle(EngineLifecycleState.ready, 'Analysis stopped');
    _currentLines.clear();
    _candidateArrowsMap.clear();
    _positionPolicyCache.clear();
    _positionVisitsCache.clear();
    _positionMlhCache.clear();
    _currentNodes = null;
    _currentNps = null;
    _currentDepth = null;
    _currentSeldepth = null;
    _currentTimeMs = null;
    _currentHashfull = 0;
    _currentTbhits = 0;
    _lastBestmove = null;
    _currentCurrmove = null;
    _currentCurrmovenumber = null;
    _evaluationNotifier.value = NormalizedEvaluation.neutral.copyWith(
      positionRevision: _positionRevision,
      analysisRequestId: _analysisRequestId,
      fen: _currentFen,
      isEngineEnabled: false,
    );
    _emitThrottledAnalysis(force: true);
  }

  /// Safely pauses active search when the app goes into the background.
  /// Stops computation on the native UCI engine to preserve battery and CPU,
  /// but strictly DOES NOT terminate or destroy the native engine process.
  /// Preserves all session state (FEN, revision, request ID, candidate arrows, evaluation).
  void pauseForBackground() {
    _isPausedForBackground = true;
    if (_engineProcess == null || !isProcessAlive) return;

    if (_searchState == EngineSearchState.searching) {
      _searchState = EngineSearchState.stopping;
      _sendCommand('stop');
      _armStoppingWatchdog();
      EngineTraceLogger.instance.log(
        requestId: _analysisRequestId,
        activeFen: _activeSearchFen ?? _currentFen,
        engineState: _searchState,
        activationState: _activationState,
        rawUciLine: 'stop',
        action: 'PAUSE_FOR_BACKGROUND',
      );
    }

    _setLifecycle(EngineLifecycleState.ready, 'Analysis paused (backgrounded)');
  }

  /// Resumes search when the app returns to the foreground.
  /// Generates a NEW monotonic analysisRequestId to strictly isolate this search session
  /// from any pre-background output, while preserving positionRevision and the current FEN.
  void resumeFromBackground() {
    _isPausedForBackground = false;
    _isAnalysisPaused = false;
    _analysisRequestId++;

    if (_engineProcess == null || !isProcessAlive || _activationState != EngineActivationState.enabled) return;

    EngineTraceLogger.instance.log(
      requestId: _analysisRequestId,
      activeFen: _currentFen,
      engineState: _searchState,
      activationState: _activationState,
      rawUciLine: 'resumeFromBackground (New Req: #$_analysisRequestId, Rev: #$_positionRevision)',
      action: 'RESUME_FROM_BACKGROUND',
    );

    _evaluationNotifier.value = _evaluationNotifier.value.copyWith(
      positionRevision: _positionRevision,
      analysisRequestId: _analysisRequestId,
      fen: _currentFen,
      isEngineEnabled: isEngineEnabled,
    );

    _currentLines.clear();
    _candidateArrowsMap.clear();

    _startSearchOnEngine();
  }

  /// Live update of presentation settings (Arrowhead type, Arrow filter, Infobox stats).
  /// Never restarts the engine or disturbs continuous search.
  void updatePresentationSettings(EngineSettings newSettings) {
    _settings = newSettings;
    _emitThrottledAnalysis(force: true);
  }

  Future<void> updateSettings(EngineSettings newSettings, {String? binaryPath}) async {
    final wasAnalyzing = _isAnalyzing;
    final engineChanged = _settings.activeEngine != newSettings.activeEngine;
    final backendChanged = _settings.activeEngine == EngineType.lc0 &&
        _settings.lc0Backend != newSettings.lc0Backend;
    final weightsChanged = _settings.activeEngine == EngineType.lc0 &&
        _settings.weightsPath != newSettings.weightsPath;
    _settings = newSettings;

    if (engineChanged || backendChanged || weightsChanged || !isProcessAlive) {
      stopAnalysis();
      await initializeEngine(binaryPath, forceRestart: true, settings: newSettings);
      if (isEngineEnabled && EngineCoordinator().activeLeaseType == EngineLeaseType.analysis) {
        startAnalysis(_currentPosition);
      }
      return;
    }

    if (_engineProcess == null || !isProcessAlive) return;

    // Synchronous 9-step UCI options handshake:
    // 1. Await stop completion if currently searching
    if (_searchState == EngineSearchState.searching) {
      _searchState = EngineSearchState.stopping;
      _sendCommand('stop');
      _armStoppingWatchdog();
      await waitForStopCompletion();
    }

    // 2. Dispatch engine-specific options
    _configureEngineOptions();

    // 3. Await readyok confirmation from engine
    await _waitForReadyOk();

    // 4. Resume search only if engine was active AND we hold the analysis lease
    if (isEngineEnabled && wasAnalyzing && EngineCoordinator().activeLeaseType == EngineLeaseType.analysis) {
      startAnalysis(_currentPosition, forceRestart: true);
    } else {
      _emitThrottledAnalysis(force: true);
    }
  }

  void _sendCommand(String cmd) {
    if (_engineProcess != null) {
      debugPrint('[UCI_TX] $cmd');
      _engineProcess!.stdin.writeln(cmd);
    }
  }

  Future<void> _disposeProcess() async {
    _cancelStoppingWatchdog();
    _processExited = true;
    _readyOkReceived = false;
    _optionsApplied = false;
    _isAnalyzing = false;
    _searchState = EngineSearchState.idle;
    _activeSearchFen = null;
    _pendingSearchFen = null;
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      _initCompleter!.complete();
    }
    if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
      _readyCompleter!.complete();
    }
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      _stopCompleter!.complete();
    }
    if (_gameMoveCompleter != null && !_gameMoveCompleter!.isCompleted) {
      _gameMoveCompleter!.complete(null);
      _gameMoveCompleter = null;
    }
    if (_hintCompleter != null && !_hintCompleter!.isCompleted) {
      _hintCompleter!.complete(null);
      _hintCompleter = null;
    }
    if (_engineProcess != null) {
      try {
        _engineProcess!.stdin.writeln('quit');
        await _engineProcess!.exitCode.timeout(const Duration(milliseconds: 400));
      } catch (_) {
        _engineProcess?.kill();
      }
      _engineProcess = null;
    }
  }

  /// Dispatches an explicit move request for Play mode with Single-PV to save CPU/battery.
  Future<String?> requestGameMove({
    required ChessPosition position,
    required int whiteTimeMs,
    required int blackTimeMs,
    int whiteIncMs = 0,
    int blackIncMs = 0,
    int? movetimeMs,
    int? nodeLimit,
  }) async {
    if (_engineProcess == null || _processExited) {
      throw StateError('Engine process is not running');
    }

    // Ensure engine is completely idle before issuing new position/go
    if (_searchState == EngineSearchState.searching) {
      _searchState = EngineSearchState.stopping;
      _sendCommand('stop');
      _armStoppingWatchdog();
      await waitForStopCompletion();
    }

    if (_gameMoveCompleter != null && !_gameMoveCompleter!.isCompleted) {
      _gameMoveCompleter!.complete(null);
    }
    _gameMoveCompleter = Completer<String?>();

    // Single-PV for gameplay
    _sendCommand('setoption name MultiPV value 1');

    final fen = position.toFen();
    _currentPosition = position;
    _currentFen = fen;
    _activeSearchFen = fen;
    _searchState = EngineSearchState.searching;
    _isAnalyzing = true;

    _sendCommand('position fen $fen');

    if (nodeLimit != null && nodeLimit > 0) {
      _sendCommand('go nodes $nodeLimit');
    } else if (_settings.isMaiaActive) {
      _sendCommand('go nodes 1');
    } else if (movetimeMs != null && movetimeMs > 0) {
      _sendCommand('go movetime $movetimeMs');
    } else if (whiteTimeMs <= 0 || blackTimeMs <= 0) {
      _sendCommand('go movetime 1500');
    } else {
      _sendCommand(
        'go wtime $whiteTimeMs btime $blackTimeMs winc $whiteIncMs binc $blackIncMs',
      );
    }

    return _gameMoveCompleter!.future;
  }

  /// Ephemeral hint search that computes the top candidate arrow for the current position.
  Future<CandidateArrow?> requestAdaptiveHint({
    required ChessPosition position,
    Duration searchTime = const Duration(milliseconds: 1500),
  }) async {
    if (_engineProcess == null || _processExited) return null;

    // Ensure engine is completely idle before issuing new position/go
    if (_searchState == EngineSearchState.searching) {
      _searchState = EngineSearchState.stopping;
      _sendCommand('stop');
      _armStoppingWatchdog();
      await waitForStopCompletion();
    }

    if (_hintCompleter != null && !_hintCompleter!.isCompleted) {
      _hintCompleter!.complete(null);
    }
    _hintCompleter = Completer<CandidateArrow?>();

    _sendCommand('setoption name MultiPV value 1');
    final fen = position.toFen();
    _currentPosition = position;
    _currentFen = fen;
    _activeSearchFen = fen;
    _searchState = EngineSearchState.searching;
    _isAnalyzing = true;

    _sendCommand('position fen $fen');
    _sendCommand('go movetime ${searchTime.inMilliseconds}');

    return _hintCompleter!.future;
  }

  /// Restores standard analysis options (like MultiPV configured in settings).
  void restoreAnalysisOptions() {
    if (_engineProcess == null || _processExited) return;
    _configureEngineOptions();
  }

  void dispose() {
    _cancelStoppingWatchdog();
    stopAnalysis();
    _throttleTimer?.cancel();
    _disposeProcess();
    _analysisController.close();
    _statusController.close();
    _evaluationNotifier.dispose();
    _analysisNotifier.dispose();
  }
}
