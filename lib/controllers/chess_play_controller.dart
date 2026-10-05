import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/chess_clock.dart';
import '../models/chess_game_record.dart';
import '../models/chess_move.dart';
import '../models/chess_position.dart';
import '../models/chess_time_control.dart';
import '../models/engine_analysis.dart';
import '../models/engine_settings.dart';
import '../services/chess_sound_service.dart';
import '../services/engine_coordinator.dart';
import '../services/chesscrack_core.dart';
import '../services/native_engine_runner.dart';
import '../services/pgn_storage_service.dart';
import '../services/uci_engine_service.dart';
import 'maia_thinking_controller.dart';

enum PlayGameState {
  notStarted,
  playerTurn,
  engineThinking,
  gameEnded,
}

/// Immutable atomic snapshot representing engine analysis for a specific board position.
class PlayAnalysisSnapshot {
  final int engineSessionId;
  final int analysisRequestId;
  final int positionRevision;
  final String fen;
  final List<CandidateArrow> candidateArrows;
  final List<PvLine> pvLines;
  final DateTime timestamp;

  const PlayAnalysisSnapshot({
    required this.engineSessionId,
    required this.analysisRequestId,
    required this.positionRevision,
    required this.fen,
    required this.candidateArrows,
    required this.pvLines,
    required this.timestamp,
  });
}

class ChessPlayController extends ChangeNotifier {
  final UciEngineService engineService;
  final MaiaThinkingController _maiaThinkingController = MaiaThinkingController();

  EngineLease? _playLease;
  int _gameSessionId = 0;
  int _moveRequestId = 0;
  int _positionRevision = 0;
  int get positionRevision => _positionRevision;

  bool _isFinalizingGame = false;
  CancellationToken? _maiaCancelToken;
  Timer? _hintTimer;

  PlayGameState _gameState = PlayGameState.notStarted;
  PlayGameState get gameState => _gameState;

  ChessPosition _position = ChessPosition.initial();
  ChessPosition get position => _position;

  final List<ChessMove> _moveHistory = [];
  List<ChessMove> get moveHistory => List.unmodifiable(_moveHistory);

  final List<String> _sanHistory = [];
  List<String> get sanHistory => List.unmodifiable(_sanHistory);

  ChessClock? _clock;
  ChessClock? get clock => _clock;

  PieceColor _playerColor = PieceColor.white;
  PieceColor get playerColor => _playerColor;

  EngineType _opponentEngine = EngineType.stockfish;
  EngineType get opponentEngine => _opponentEngine;

  String _opponentDisplayName = 'Stockfish';
  String get opponentDisplayName => _opponentDisplayName;

  String? _selectedMaiaId;
  String? get selectedMaiaId => _selectedMaiaId;
  int? _stockfishElo;
  int? get stockfishElo => _stockfishElo;
  ChessTimeControl _timeControl = ChessTimeControl.blitz5_0;
  ChessTimeControl get timeControl => _timeControl;

  MaiaThinkingProfile _maiaProfile = MaiaThinkingProfile.humanLike;
  MaiaThinkingProfile get maiaProfile => _maiaProfile;

  PlayAnalysisSnapshot? _currentSnapshot;
  PlayAnalysisSnapshot? get currentSnapshot => _currentSnapshot;

  bool _showHint = false;
  bool get showHint => _showHint;

  List<CandidateArrow> _hintArrows = const [];
  List<CandidateArrow> get hintArrows => _hintArrows;
  CandidateArrow? get hintArrow => _hintArrows.isNotEmpty ? _hintArrows.first : null;

  bool _isHintLoading = false;
  bool get isHintLoading => _isHintLoading;

  String? _gameResult;
  String? get gameResult => _gameResult;

  GameTerminationReason? _terminationReason;
  GameTerminationReason? get terminationReason => _terminationReason;

  ChessGameRecord? _savedRecord;
  ChessGameRecord? get savedRecord => _savedRecord;

  bool _isGameSaved = false;
  bool get isGameSaved => _isGameSaved;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ChessPlayController({required this.engineService}) {
    engineService.analysisNotifier.addListener(_onAnalysisUpdated);
  }

  void _onAnalysisUpdated() {
    final analysis = engineService.analysisNotifier.value;
    if (_gameState == PlayGameState.playerTurn &&
        analysis != null &&
        analysis.fen == _position.toFen() &&
        analysis.candidateArrows.isNotEmpty) {
      _currentSnapshot = PlayAnalysisSnapshot(
        engineSessionId: analysis.engineSessionId,
        analysisRequestId: analysis.analysisRequestId,
        positionRevision: _positionRevision,
        fen: analysis.fen,
        candidateArrows: List.unmodifiable(analysis.candidateArrows),
        pvLines: List.unmodifiable(analysis.pvLines),
        timestamp: DateTime.now(),
      );
      _hintArrows = _currentSnapshot!.candidateArrows;
      if (_isHintLoading) {
        _isHintLoading = false;
        notifyListeners();
      } else if (_showHint) {
        notifyListeners();
      }
    }
  }

  bool get isPlayerTurn =>
      _gameState == PlayGameState.playerTurn &&
      _position.turn == _playerColor &&
      !_isFinalizingGame;

  bool get isEngineTurn =>
      _gameState == PlayGameState.engineThinking ||
      (_gameState != PlayGameState.gameEnded && _position.turn != _playerColor);

  /// Initializes a fresh game session with the chosen setup.
  Future<void> startNewGame({
    required EngineType opponentEngine,
    required PieceColor playerColor,
    required ChessTimeControl timeControl,
    int? stockfishElo,
    bool limitStrength = false,
    String? selectedMaiaId,
    String? maiaWeightsPath,
    MaiaThinkingProfile maiaThinkingProfile = MaiaThinkingProfile.humanLike,
  }) async {
    _hintTimer?.cancel();
    _hintTimer = null;
    _maiaCancelToken?.cancel();

    _gameSessionId++;
    _moveRequestId = 0;
    _positionRevision++;
    _isFinalizingGame = false;
    _isGameSaved = false;
    _savedRecord = null;
    _errorMessage = null;
    _currentSnapshot = null;
    _hintArrows = const [];
    _showHint = false;
    _isHintLoading = false;

    _opponentEngine = opponentEngine;
    _playerColor = playerColor;
    _timeControl = timeControl;
    _stockfishElo = stockfishElo;
    _selectedMaiaId = selectedMaiaId;
    _maiaProfile = maiaThinkingProfile;

    // Build honest opponent label
    if (opponentEngine == EngineType.stockfish) {
      if (limitStrength && stockfishElo != null) {
        _opponentDisplayName = 'Stockfish (Elo limit $stockfishElo)';
      } else {
        _opponentDisplayName = 'Stockfish (Full Strength)';
      }
    } else if (opponentEngine == EngineType.lc0 && selectedMaiaId != null) {
      final eloNum = selectedMaiaId.replaceAll(RegExp(r'[^\d]'), '');
      _opponentDisplayName = 'Maia $eloNum';
    } else {
      _opponentDisplayName = 'Lc0';
    }

    _position = ChessPosition.initial();
    _moveHistory.clear();
    _sanHistory.clear();

    // Acquire exclusive engine lease for Play mode
    _playLease = await EngineCoordinator().acquireLease(EngineLeaseType.play);

    // Apply engine settings for this game with MultiPV 4 for Nibbler candidate arrows
    final newSettings = engineService.settings.copyWith(
      activeEngine: opponentEngine,
      limitStrength: limitStrength,
      uciElo: stockfishElo,
      selectedMaiaId: selectedMaiaId,
      weightsPath: maiaWeightsPath ?? engineService.settings.weightsPath,
      nodeLimit: opponentEngine == EngineType.lc0 && selectedMaiaId != null ? 1 : engineService.settings.nodeLimit,
      multiPv: 4,
    );
    await engineService.updateSettings(newSettings);

    // Initialize clock
    _clock?.dispose();
    _clock = ChessClock(
      timeControl: timeControl,
      onFlagged: (flaggedSide) {
        final winnerColor = flaggedSide == ClockSide.white ? PieceColor.black : PieceColor.white;
        _finalizeGame(
          termination: GameTerminationReason.timeout,
          result: winnerColor == PieceColor.white ? '1-0' : '0-1',
        );
      },
    );

    // Play start audio
    ChessSoundService().playSound(ChessSoundEvent.gameStart);

    if (_playerColor == PieceColor.white) {
      _gameState = PlayGameState.playerTurn;
      _clock?.start(ClockSide.white);
      _startPlayerTurnAnalysis();
      notifyListeners();
    } else {
      _gameState = PlayGameState.engineThinking;
      _clock?.start(ClockSide.white);
      notifyListeners();
      _dispatchEngineMove();
    }
  }

  void _startPlayerTurnAnalysis() {
    if (_gameState != PlayGameState.playerTurn || _isFinalizingGame) return;
    _currentSnapshot = null;
    _hintArrows = const [];
    engineService.startAnalysis(_position);
  }

  /// Handles human player move.
  Future<bool> playPlayerMove(ChessMove move) async {
    if (!isPlayerTurn) return false;

    // Check move legality
    final legalMove = _position.legalMoves.cast<ChessMove?>().firstWhere(
      (m) => m!.from == move.from && m.to == move.to && (m.promotion == null || m.promotion == move.promotion),
      orElse: () => null,
    );
    if (legalMove == null) {
      ChessSoundService().playSound(ChessSoundEvent.illegalMove);
      return false;
    }

    // Dismiss ephemeral hint state on move and stop analysis
    _hintTimer?.cancel();
    _showHint = false;
    _isHintLoading = false;
    _currentSnapshot = null;
    _hintArrows = const [];
    _positionRevision++;

    engineService.stopAnalysis();

    final nextPos = _position.applyMove(legalMove);
    _moveHistory.add(legalMove);
    _sanHistory.add(legalMove.san ?? legalMove.uci);
    _position = nextPos;

    // Sound
    ChessSoundService().playMoveSound(
      move: legalMove,
      resultingPosition: nextPos,
      isCheckmate: nextPos.isCheckmate(),
      isStalemate: nextPos.isStalemate(),
    );

    // Switch clock
    _clock?.switchTurn(
      newActiveSide: _position.turn == PieceColor.white ? ClockSide.white : ClockSide.black,
    );

    // Check game termination
    if (_checkAndHandleGameOver()) {
      return true;
    }

    _gameState = PlayGameState.engineThinking;
    notifyListeners();

    _dispatchEngineMove();
    return true;
  }

  /// Deterministic MultiPV hint request.
  /// Reads the current analysis snapshot without restarting search or altering engine state.
  void requestHint() {
    if (_gameState != PlayGameState.playerTurn || _isFinalizingGame) {
      return;
    }

    if (_showHint) {
      // Toggle off if already showing
      _showHint = false;
      notifyListeners();
      return;
    }

    _showHint = true;

    // If a snapshot is already available for this exact position, display it immediately
    if (_currentSnapshot != null && _currentSnapshot!.fen == _position.toFen()) {
      _isHintLoading = false;
      _hintArrows = _currentSnapshot!.candidateArrows;
      notifyListeners();
      return;
    }

    // If analysis is still calculating, show waiting indicator without restarting search
    _isHintLoading = true;
    notifyListeners();

    // Ensure engine is actively analyzing current position
    if (!engineService.isAnalyzing) {
      engineService.startAnalysis(_position);
    }
  }

  /// User resigns game.
  void resign() {
    if (_gameState == PlayGameState.gameEnded || _isFinalizingGame) return;
    final engineWonResult = _playerColor == PieceColor.white ? '0-1' : '1-0';
    _finalizeGame(
      termination: GameTerminationReason.resignation,
      result: engineWonResult,
    );
  }

  /// User aborts or claims draw.
  void abortGame() {
    if (_gameState == PlayGameState.gameEnded || _isFinalizingGame) return;
    _finalizeGame(
      termination: GameTerminationReason.aborted,
      result: '*',
    );
  }

  bool _checkAndHandleGameOver() {
    if (_position.isCheckmate()) {
      final winnerResult = _position.turn == PieceColor.white ? '0-1' : '1-0';
      _finalizeGame(
        termination: GameTerminationReason.checkmate,
        result: winnerResult,
      );
      return true;
    }
    if (_position.isStalemate()) {
      _finalizeGame(
        termination: GameTerminationReason.stalemate,
        result: '1/2-1/2',
      );
      return true;
    }
    if (_position.isInsufficientMaterial()) {
      _finalizeGame(
        termination: GameTerminationReason.insufficientMaterial,
        result: '1/2-1/2',
      );
      return true;
    }
    return false;
  }

  /// Dispatches the engine's move computation with crash resilience.
  Future<void> _dispatchEngineMove({int retry = 0}) async {
    final currentSession = _gameSessionId;
    final currentReq = ++_moveRequestId;

    try {
      final clockState = _clock?.currentState;
      final wTime = clockState != null ? clockState.whiteRemainingMs : 300000;
      final bTime = clockState != null ? clockState.blackRemainingMs : 300000;
      final inc = _timeControl.incrementSeconds * 1000;

      String? uciMove;

      // 1. Move calculation with 1 crash-recovery retry
      int attempts = 0;
      while (attempts < 2 && uciMove == null) {
        attempts++;
        try {
          if (!engineService.isProcessAlive) {
            final exePath = await NativeEngineRunner.getEngineExecutablePath(_opponentEngine);
            await engineService.initializeEngine(exePath, forceRestart: true);
          }

          uciMove = await engineService.requestGameMove(
            position: _position,
            whiteTimeMs: wTime,
            blackTimeMs: bTime,
            whiteIncMs: inc,
            blackIncMs: inc,
            nodeLimit: _opponentEngine == EngineType.lc0 && _selectedMaiaId != null ? 1 : null,
          );
        } catch (e) {
          if (kDebugMode) {
            developer.log('Engine move attempt $attempts error: $e', name: 'ChessPlayController');
          }
          if (attempts >= 2) rethrow;
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }

      // Check session validity after async engine calculation
      if (currentSession != _gameSessionId || currentReq != _moveRequestId || _isFinalizingGame) {
        return;
      }

      if (uciMove == null || uciMove == '(none)') {
        _checkAndHandleGameOver();
        return;
      }

      // 2. Maia human pacing layer (without move tampering)
      if (_opponentEngine == EngineType.lc0 && _selectedMaiaId != null) {
        _maiaCancelToken = CancellationToken();
        await _maiaThinkingController.paceMove(
          profile: _maiaProfile,
          moveNumber: (_moveHistory.length ~/ 2) + 1,
          isCheck: _position.isCheck(),
          isCapture: false,
          cancellationToken: _maiaCancelToken,
        );
      }

      // Check session validity again after Maia pacing delay
      if (currentSession != _gameSessionId || currentReq != _moveRequestId || _isFinalizingGame) {
        return;
      }

      // 3. Apply engine move
      final legalMove = _position.findLegalMoveByUci(uciMove);
      if (legalMove == null) {
        if (kDebugMode) {
          developer.log('Engine returned illegal move: $uciMove (retry=$retry)', name: 'ChessPlayController');
        }
        if (_checkAndHandleGameOver()) return;
        if (retry < 1) {
          // Likely a stale bestmove from an aborted search — request again for this position.
          unawaited(_dispatchEngineMove(retry: retry + 1));
        } else {
          _errorMessage = 'Engine returned an illegal move ($uciMove)';
          notifyListeners();
        }
        return;
      }

      final nextPos = _position.applyMove(legalMove);
      _moveHistory.add(legalMove);
      _sanHistory.add(legalMove.san ?? legalMove.uci);
      _position = nextPos;

      ChessSoundService().playMoveSound(
        move: legalMove,
        resultingPosition: nextPos,
        isCheckmate: nextPos.isCheckmate(),
        isStalemate: nextPos.isStalemate(),
      );

      _clock?.switchTurn(
        newActiveSide: _position.turn == PieceColor.white ? ClockSide.white : ClockSide.black,
      );

      if (_checkAndHandleGameOver()) {
        return;
      }

      _positionRevision++;
      _currentSnapshot = null;
      _hintArrows = const [];
      _gameState = PlayGameState.playerTurn;
      _startPlayerTurnAnalysis();
      notifyListeners();
    } catch (e, st) {
      if (currentSession != _gameSessionId) return;
      if (kDebugMode) {
        developer.log('Fatal engine move failure: $e', error: e, stackTrace: st, name: 'ChessPlayController');
      }
      _errorMessage = 'Engine stopped responding: $e';
      notifyListeners();
    }
  }

  /// Atomic game finalization mutex.
  Future<void> _finalizeGame({
    required GameTerminationReason termination,
    required String result,
  }) async {
    if (_isFinalizingGame) return;
    _isFinalizingGame = true;

    _clock?.stop();
    _hintTimer?.cancel();
    _showHint = false;
    _isHintLoading = false;
    _currentSnapshot = null;
    _hintArrows = const [];
    _maiaCancelToken?.cancel();
    engineService.stopAnalysis();

    _gameState = PlayGameState.gameEnded;
    _terminationReason = termination;
    _gameResult = result;
    notifyListeners();

    // Construct full PGN
    final now = DateTime.now();
    final dateStr = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
    final whiteName = _playerColor == PieceColor.white ? 'User' : _opponentDisplayName;
    final blackName = _playerColor == PieceColor.black ? 'User' : _opponentDisplayName;

    final movesPgnBuffer = StringBuffer();
    for (int i = 0; i < _sanHistory.length; i++) {
      if (i % 2 == 0) {
        movesPgnBuffer.write('${(i ~/ 2) + 1}. ');
      }
      movesPgnBuffer.write('${_sanHistory[i]} ');
    }
    movesPgnBuffer.write(result);

    final fullPgn = '''
[Event "ChessCrack Play"]
[Site "ChessCrack Android"]
[Date "$dateStr"]
[Round "1"]
[White "$whiteName"]
[Black "$blackName"]
[Result "$result"]
[TimeControl "${_timeControl.displayName}"]
[Termination "${termination.name}"]

${movesPgnBuffer.toString().trim()}
''';

    final record = ChessGameRecord(
      id: 'game_${now.millisecondsSinceEpoch}',
      date: now,
      whitePlayer: whiteName,
      blackPlayer: blackName,
      userSide: _playerColor == PieceColor.white ? 'white' : 'black',
      result: result,
      terminationReason: termination,
      timeControl: _timeControl,
      moveCount: _sanHistory.length,
      finalFen: _position.toFen(),
      pgn: fullPgn,
    );

    // Save with atomic write verification
    final savedOk = await PgnStorageService.instance.saveGame(record);
    _savedRecord = record;
    _isGameSaved = savedOk;

    // Also persist into ChessCrack Core default "My Games" database
    try {
      if (ChessCrackCore.instance.isInitialized) {
        final dbs = await ChessCrackCore.instance.listDatabases();
        final myGamesDb = dbs.firstWhere(
          (d) => d['category'] == 'my_games' || d['name'] == 'My Games',
          orElse: () => dbs.isNotEmpty ? dbs.first : {'id': 1},
        );
        final dbId = (myGamesDb['id'] as num).toInt();
        await ChessCrackCore.instance.savePgn(dbId: dbId, pgn: fullPgn);
      }
    } catch (e) {
      developer.log('Auto-saving play game to ChessCrack database failed: $e', name: 'ChessPlayController');
    }

    notifyListeners();
  }

  /// Releases engine lease and cleans up resources when user navigates away.
  @override
  void dispose() {
    _hintTimer?.cancel();
    _maiaCancelToken?.cancel();
    _clock?.dispose();
    if (_playLease != null) {
      EngineCoordinator().releaseLease(_playLease!);
      _playLease = null;
    }
    engineService.restoreAnalysisOptions();
    super.dispose();
  }
}
