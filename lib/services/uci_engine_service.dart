import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/chess_move.dart';
import '../models/chess_position.dart';
import '../models/engine_analysis.dart';
import '../models/engine_settings.dart';
import '../utils/score_adapters.dart';
import '../utils/win_rate_calculator.dart';
import 'engine_trace_logger.dart';
import 'native_engine_runner.dart';

class UciEngineService {
  Process? _engineProcess;
  bool _processExited = false;
  bool get isProcessAlive => _engineProcess != null && !_processExited;
  int get activeProcessCount => isProcessAlive ? 1 : 0;
  bool _isPausedForBackground = false;
  bool get isPausedForBackground => _isPausedForBackground;

  EngineSettings _settings;
  EngineSettings get settings => _settings;
  int _pvsReceivedCount = 0;

  final ValueNotifier<NormalizedEvaluation> _evaluationNotifier =
      ValueNotifier<NormalizedEvaluation>(NormalizedEvaluation.neutral);
  ValueListenable<NormalizedEvaluation> get evaluationNotifier => _evaluationNotifier;

  // Engine Activation State (Separate from search state)
  EngineActivationState _activationState = EngineActivationState.enabled;
  EngineActivationState get activationState => _activationState;
  bool get isEngineEnabled =>
      _activationState == EngineActivationState.enabled ||
      _activationState == EngineActivationState.starting;

  // Search State Machine (Nibbler model)
  EngineSearchState _searchState = EngineSearchState.idle;
  EngineSearchState get searchState => _searchState;

  // Lifecycle State for UI diagnostics
  EngineLifecycleState _lifecycleState = EngineLifecycleState.idle;
  EngineLifecycleState get lifecycleState => _lifecycleState;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;
  bool get isEngineReady =>
      _lifecycleState == EngineLifecycleState.ready ||
      _lifecycleState == EngineLifecycleState.analyzing;

  // Monotonic Revision & Request Tracking
  int _positionRevision = 0;
  int _analysisRequestId = 0;
  int get positionRevision => _positionRevision;
  int get analysisRequestId => _analysisRequestId;

  String? _activeSearchFen;
  String? _pendingSearchFen;
  int? _pendingRequestId;

  ChessPosition _currentPosition = ChessPosition.initial();
  String _currentFen = ChessPosition.initialFen;
  bool _currentTurnIsWhite = true;

  int _currentNodes = 0;
  int _currentNps = 0;
  int _currentDepth = 0;
  final Map<int, PvLine> _currentLines = {};

  // Candidate arrows map indexed by MultiPV rank
  final Map<int, CandidateArrow> _candidateArrowsMap = {};

  // Real Lc0 root move telemetry caches (per position)
  final Map<String, double> _positionPolicyCache = {};
  final Map<String, int> _positionVisitsCache = {};
  final Map<String, double> _positionMlhCache = {};

  // Engine diagnostic detection
  String _detectedBackend = 'auto';
  String _detectedDevice = 'CPU';
  String _detectedNetwork = 'default';
  String _engineVersion = '';
  String get engineVersion => _engineVersion;

  int _currentSeldepth = 0;
  int _currentTimeMs = 0;
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

  final _analysisController = StreamController<PositionAnalysis>.broadcast();
  Stream<PositionAnalysis> get analysisStream => _analysisController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  UciEngineService(this._settings);

  Completer<void>? _initCompleter;

  Future<void> initializeEngine(String? binaryPath, {bool forceRestart = false, EngineSettings? settings}) async {
    final bool engineChanged = settings != null && settings.activeEngine != _settings.activeEngine;
    if (settings != null) {
      _settings = settings;
    }
    // 1. Idempotent session reuse: If engine process is already alive and ready/analyzing/idle,
    // and no forced restart is requested and engine has not changed, reuse the session immediately.
    if (!forceRestart &&
        !engineChanged &&
        isProcessAlive &&
        (_lifecycleState == EngineLifecycleState.ready ||
            _lifecycleState == EngineLifecycleState.analyzing ||
            _lifecycleState == EngineLifecycleState.idle)) {
      _setLifecycle(_lifecycleState, '${_settings.activeEngine.displayName} active (reused session)');
      return;
    }

    _setLifecycle(EngineLifecycleState.starting, 'Awaiting engine initialization...');

    if (binaryPath == null || !File(binaryPath).existsSync()) {
      _setLifecycle(EngineLifecycleState.error, '${_settings.activeEngine.displayName} failed to start: binary not found');
      return;
    }

    try {
      final List<String> args = [];
      if (_settings.activeEngine == EngineType.lc0) {
        if (_settings.weightsPath == null || _settings.weightsPath!.isEmpty) {
          _settings.weightsPath = await NativeEngineRunner.getBundledWeightsPath();
        }
        if (_settings.weightsPath != null &&
            _settings.weightsPath!.isNotEmpty &&
            _settings.weightsPath != '<built in>') {
          args.add('--weights=${_settings.weightsPath}');
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
      _currentSeldepth = 0;
      _currentTimeMs = 0;
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
      _currentNodes = 0;
      _currentNps = 0;
      _currentDepth = 0;
      _detectedBackend = 'auto';
      _detectedDevice = 'CPU';
      _detectedNetwork = 'default';
      _evaluationNotifier.value = NormalizedEvaluation.neutral;
      _engineProcess = await Process.start(binaryPath, args);
      _engineProcess!.exitCode.then((_) => _processExited = true);

      _engineProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleEngineOutput);

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

    _activationState = EngineActivationState.disabled;
    _setLifecycle(EngineLifecycleState.idle, 'Engine disabled');

    // Completely clear candidate lines and evaluation
    _currentLines.clear();
    _candidateArrowsMap.clear();
    _positionPolicyCache.clear();
    _positionVisitsCache.clear();
    _positionMlhCache.clear();
    _currentNodes = 0;
    _currentNps = 0;
    _currentDepth = 0;
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

  void _handleEngineOutput(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    _detectEngineMetadata(trimmed);

    if (trimmed.startsWith('id name ')) {
      _engineVersion = trimmed.substring(8).trim();
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
      if (_isAnalyzing && _activationState == EngineActivationState.enabled && _searchState != EngineSearchState.searching) {
        _startSearchOnEngine();
      }
    } else if (trimmed.startsWith('info string ')) {
      _parseInfoStringLine(trimmed);
    } else if (trimmed.startsWith('info ')) {
      _parseInfoLine(trimmed);
    } else if (trimmed == 'bestmove' || trimmed.startsWith('bestmove ')) {
      _handleBestMove(trimmed);
    }
  }

  void _handleBestMove(String line) {
    final bmTokens = line.trim().split(RegExp(r'\s+'));
    if (bmTokens.length > 1 && bmTokens[1] != '(none)') {
      _lastBestmove = bmTokens[1];
    }
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      _stopCompleter!.complete();
    }

    EngineTraceLogger.instance.log(
      requestId: _analysisRequestId,
      activeFen: _activeSearchFen ?? _currentFen,
      pendingFen: _pendingSearchFen,
      engineState: _searchState,
      activationState: _activationState,
      rawUciLine: line,
      action: _searchState == EngineSearchState.stopping ? 'BESTMOVE_STOP_COMPLETION' : 'BESTMOVE_NATURAL_STOP',
    );

    if (_searchState == EngineSearchState.stopping) {
      // Bestmove from previous aborted search: treat strictly as STOP COMPLETION
      _searchState = EngineSearchState.ready;

      if (_pendingSearchFen != null && _activationState == EngineActivationState.enabled) {
        // Launch pending search cleanly
        final fenToSearch = _pendingSearchFen!;
        final reqId = _pendingRequestId ?? _analysisRequestId;
        _pendingSearchFen = null;
        _pendingRequestId = null;

        _activeSearchFen = fenToSearch;
        _searchState = EngineSearchState.searching;
        _isAnalyzing = true;
        _currentNodes = 0;
        _currentNps = 0;
        _currentDepth = 0;
        _currentSeldepth = 0;
        _currentTimeMs = 0;
        _currentHashfull = 0;
        _currentTbhits = 0;
        _currentLines.clear();
        _candidateArrowsMap.clear();

        _setLifecycle(EngineLifecycleState.analyzing, 'Analyzing with ${_settings.activeEngine.displayName} (Req #$reqId)');
        _sendCommand('position fen $fenToSearch');
        if (_settings.nodeLimit != null) {
          _sendCommand('go nodes ${_settings.nodeLimit}');
        } else {
          _sendCommand('go infinite');
        }

        EngineTraceLogger.instance.log(
          requestId: reqId,
          activeFen: fenToSearch,
          engineState: _searchState,
          activationState: _activationState,
          rawUciLine: 'position fen $fenToSearch / go infinite',
          action: 'LAUNCHED_PENDING_SEARCH',
        );
      } else {
        _isAnalyzing = false;
        _activeSearchFen = null;
        _setLifecycle(EngineLifecycleState.ready, 'Engine stopped');
        _emitThrottledAnalysis(force: true);
      }
    } else if (_searchState == EngineSearchState.searching) {
      if (_settings.nodeLimit != null) {
        // Natural stop because an explicit node limit was set and reached
        _searchState = EngineSearchState.ready;
        _isAnalyzing = false;
        _setLifecycle(EngineLifecycleState.ready, 'Analysis complete (${_settings.nodeLimit} nodes reached)');
        _emitThrottledAnalysis(force: true);
      } else if (_currentPosition.legalMoves.isEmpty || _lastBestmove == '(none)') {
        // Natural stop because position has no legal moves (checkmate/stalemate)
        _searchState = EngineSearchState.ready;
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

  Future<void> _waitForStopCompletion({Duration timeout = const Duration(milliseconds: 600)}) async {
    if (_searchState != EngineSearchState.stopping) return;
    _stopCompleter = Completer<void>();
    try {
      await _stopCompleter!.future.timeout(timeout);
    } catch (_) {
      _searchState = EngineSearchState.ready;
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
    } else {
      // Stockfish options
      _sendCommand('setoption name Hash value ${_settings.hashSizeMb}');
      _sendCommand('setoption name MultiPV value ${_settings.multiPv}');
      _sendCommand('setoption name UCI_ShowWDL value true');
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
  void _parseInfoStringLine(String line) {
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

    // Update existing candidate arrow for this move if already present
    bool updated = false;
    for (final entry in _candidateArrowsMap.entries) {
      if (entry.value.uciMove == moveToken) {
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

  void _parseInfoLine(String line) {
    // 1. State Machine Guard: If engine is currently stopping an old search, drop immediately
    if (_searchState == EngineSearchState.stopping) {
      EngineTraceLogger.instance.log(
        requestId: _analysisRequestId,
        activeFen: _activeSearchFen ?? _currentFen,
        pendingFen: _pendingSearchFen,
        engineState: _searchState,
        activationState: _activationState,
        rawUciLine: line,
        action: 'DISCARDED_STOPPING',
      );
      return;
    }

    // 2. Engine Activation Guard: Drop if engine analysis is disabled
    if (_activationState != EngineActivationState.enabled) {
      return;
    }

    // 3. FEN Guard: Drop if line does not match current board FEN
    if (_activeSearchFen != _currentFen) {
      EngineTraceLogger.instance.log(
        requestId: _analysisRequestId,
        activeFen: _activeSearchFen ?? _currentFen,
        engineState: _searchState,
        activationState: _activationState,
        rawUciLine: line,
        action: 'DISCARDED_FEN_MISMATCH',
      );
      return;
    }

    final capturedRev = _positionRevision;
    final capturedReqId = _analysisRequestId;

    final tokens = line.split(RegExp(r'\s+'));
    int multipv = 1;
    int? scoreCp;
    int? scoreMate;
    int depth = _currentDepth;
    int seldepth = 0;
    int nodes = _currentNodes;
    int nps = _currentNps;
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
          depth = math.max(depth, dVal);
          _currentDepth = math.max(_currentDepth, dVal);
        }
      } else if (t == 'seldepth' && i + 1 < tokens.length) {
        final sdVal = int.tryParse(tokens[++i]);
        if (sdVal != null) {
          seldepth = math.max(seldepth, sdVal);
          _currentSeldepth = math.max(_currentSeldepth, sdVal);
        }
      } else if (t == 'time' && i + 1 < tokens.length) {
        final tVal = int.tryParse(tokens[++i]);
        if (tVal != null) {
          _currentTimeMs = math.max(_currentTimeMs, tVal);
        }
      } else if (t == 'nodes' && i + 1 < tokens.length) {
        final nVal = int.tryParse(tokens[++i]);
        if (nVal != null) {
          nodes = math.max(nodes, nVal);
          _currentNodes = math.max(_currentNodes, nVal);
        }
      } else if (t == 'nps' && i + 1 < tokens.length) {
        final npsVal = int.tryParse(tokens[++i]);
        if (npsVal != null && npsVal > 0) {
          if (multipv == 1 || _currentNps == 0) {
            nps = npsVal;
            _currentNps = npsVal;
          } else {
            nps = math.max(nps, npsVal);
            _currentNps = math.max(_currentNps, npsVal);
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

    // Strict revision and request protection
    if (capturedRev != _positionRevision || capturedReqId != _analysisRequestId) {
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
      nodes: nodes,
      nps: nps,
      depth: depth,
      visitPct: visitPct,
      policyPct: policyPct ?? _positionPolicyCache[firstMoveUci],
      utility: utility,
      pvUci: movesUci,
    );

    final pvMoves = SANFormatter.parsePvLine(_currentPosition, movesUci);
    final pvSan = pvMoves.map((m) => m.san).toList();

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
      movesSan: pvSan,
      pvMoves: pvMoves,
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
      evaluation: moveEvaluation,
    );

    // Calculate real telemetry fields
    final double winProb = (wdl != null && wdl.length >= 3)
        ? ((wdl[0] / (wdl[0] + wdl[1] + wdl[2])) * 100.0)
        : moveEvaluation.winProbability;
    final double expScore = (wdl != null && wdl.length >= 3)
        ? (((wdl[0] + 0.5 * wdl[1]) / (wdl[0] + wdl[1] + wdl[2])) * 100.0)
        : moveEvaluation.expectedScore;

    final candidateVisits = nodes;
    final effectiveTotalNodes = math.max(_currentNodes, candidateVisits);
    final double? nodePct = effectiveTotalNodes > 0
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
      pvSan: pvSan,
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
    final baseColor = rank == 1
        ? Color(WinRateCalculator.getArrowColorValue(expectedScore))
        : (rank == 2
            ? const Color(0xFF4CAF50) // Green
            : (rank == 3
                ? const Color(0xFF29B6F6) // Cyan / Blue
                : (rank == 4
                    ? const Color(0xFFAB47BC) // Purple
                    : const Color(0xFFFFA726)))); // Orange

    final opacity = rank == 1 ? 0.95 : (rank == 2 ? 0.85 : (rank == 3 ? 0.75 : 0.65));
    final strokeScale = rank == 1 ? 1.15 : (rank == 2 ? 0.95 : (rank == 3 ? 0.80 : 0.70));
    final headScale = rank == 1 ? 1.15 : (rank == 2 ? 0.95 : (rank == 3 ? 0.80 : 0.70));
    final badgeScale = rank == 1 ? 1.05 : (rank == 2 ? 0.95 : (rank == 3 ? 0.90 : 0.85));

    return ArrowVisualStyle(
      shaftColor: baseColor,
      badgeColor: baseColor,
      textColor: const Color(0xFF111111),
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
      _throttleTimer = Timer(const Duration(milliseconds: 80), () {
        if (_hasPendingUpdate) {
          _emitThrottledAnalysis();
          _hasPendingUpdate = false;
        }
      });
    }
  }

  void _emitThrottledAnalysis({bool force = false}) {
    if (!isEngineEnabled && !force) return;

    final sortedLines = _currentLines.values.toList()
      ..sort((a, b) => a.multipv.compareTo(b.multipv));

    final rawArrows = _candidateArrowsMap.values.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    final totalCandidateVisits = rawArrows.fold<int>(0, (sum, a) => sum + (a.visits ?? 0));
    final effectiveTotalNodes = math.max(_currentNodes, totalCandidateVisits);

    final resolvedArrows = <CandidateArrow>[];
    final Map<Square, List<CandidateArrow>> byFrom = {};
    for (final a in rawArrows) {
      byFrom.putIfAbsent(a.from, () => []).add(a);
    }

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

      final bool revPassed = !missingReq && !staleReq && !missingRev && !staleRev;
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
      visits: _currentNodes,
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
      totalNodes: _currentNodes,
      nodesPerSecond: _currentNps,
      depth: _currentDepth,
      pvLines: sortedLines,
      candidateArrows: filteredArrows,
      isAnalyzing: _isAnalyzing && isEngineEnabled,
      engineName: _settings.activeEngine.displayName,
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
  }

  /// Starts or updates analysis for the given position using Nibbler continuous-analysis rules.
  /// Never thrashes the engine if analyzing the same FEN.
  void startAnalysis(ChessPosition position) {
    if (!isEngineEnabled) return;

    final newFen = position.toFen();

    // 1. Continuous analysis check: If already searching this exact position, DO NOT restart!
    if (_activeSearchFen == newFen && _isAnalyzing && _searchState == EngineSearchState.searching) {
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

    // Clear caches for new position
    _pvsReceivedCount = 0;
    _currentLines.clear();
    _candidateArrowsMap.clear();
    _positionPolicyCache.clear();
    _positionVisitsCache.clear();
    _positionMlhCache.clear();
    _currentNodes = 0;
    _currentNps = 0;
    _currentDepth = 0;
    _currentSeldepth = 0;
    _currentTimeMs = 0;
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
      // Already stopping: simply update the pending FEN
      _pendingSearchFen = newFen;
      _pendingRequestId = _analysisRequestId;

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

    _setLifecycle(EngineLifecycleState.analyzing, 'Analyzing with ${_settings.activeEngine.displayName} (Req #$_analysisRequestId)');
    _sendCommand('position fen $_currentFen');

    if (_settings.nodeLimit != null) {
      _sendCommand('go nodes ${_settings.nodeLimit}');
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

  void stopAnalysis() {
    _isAnalyzing = false;
    _pendingSearchFen = null;
    _pendingRequestId = null;
    _activeSearchFen = null;
    _pvsReceivedCount = 0;

    if (_engineProcess != null) {
      if (_searchState == EngineSearchState.searching) {
        _searchState = EngineSearchState.stopping;
        _sendCommand('stop');
      }
    } else {
      _searchState = EngineSearchState.idle;
    }

    _setLifecycle(EngineLifecycleState.idle, 'Analysis stopped');
    _currentLines.clear();
    _candidateArrowsMap.clear();
    _positionPolicyCache.clear();
    _positionVisitsCache.clear();
    _positionMlhCache.clear();
    _currentNodes = 0;
    _currentNps = 0;
    _currentDepth = 0;
    _currentSeldepth = 0;
    _currentTimeMs = 0;
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
      EngineTraceLogger.instance.log(
        requestId: _analysisRequestId,
        activeFen: _activeSearchFen ?? _currentFen,
        engineState: _searchState,
        activationState: _activationState,
        rawUciLine: 'stop',
        action: 'PAUSE_FOR_BACKGROUND',
      );
    }

    _setLifecycle(EngineLifecycleState.idle, 'Analysis paused (backgrounded)');
  }

  /// Resumes search when the app returns to the foreground.
  /// Generates a NEW monotonic analysisRequestId to strictly isolate this search session
  /// from any pre-background output, while preserving positionRevision and the current FEN.
  void resumeFromBackground() {
    _isPausedForBackground = false;
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
        (_settings.lc0Backend != newSettings.lc0Backend || _settings.weightsPath != newSettings.weightsPath);
    _settings = newSettings;

    if (engineChanged || backendChanged || !isProcessAlive) {
      stopAnalysis();
      await initializeEngine(binaryPath, forceRestart: true, settings: newSettings);
      if (isEngineEnabled) {
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
      await _waitForStopCompletion();
    }

    // 2. Dispatch engine-specific options
    _configureEngineOptions();

    // 3. Await readyok confirmation from engine
    await _waitForReadyOk();

    // 4. Resume search if engine was active
    if (isEngineEnabled && wasAnalyzing) {
      startAnalysis(_currentPosition);
    } else {
      _emitThrottledAnalysis(force: true);
    }
  }

  void _sendCommand(String cmd) {
    if (_engineProcess != null) {
      _engineProcess!.stdin.writeln(cmd);
    }
  }

  Future<void> _disposeProcess() async {
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

  void dispose() {
    stopAnalysis();
    _throttleTimer?.cancel();
    _disposeProcess();
    _analysisController.close();
    _statusController.close();
    _evaluationNotifier.dispose();
  }
}
