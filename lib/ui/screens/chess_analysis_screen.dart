import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/chess_move.dart';
import '../../models/chess_position.dart';
import '../../models/draft_variation.dart';
import '../../models/engine_analysis.dart';
import '../../models/engine_settings.dart';
import '../../models/game_tree.dart';
import '../../services/engine_download_service.dart';
import '../../services/native_engine_runner.dart';
import '../../services/pgn_parser.dart';
import '../../services/session_persistence_service.dart';
import '../../services/sound_service.dart';
import '../../services/theme_service.dart';
import '../../services/uci_engine_service.dart';
import '../widgets/about_dialog.dart';
import '../widgets/arrow_settings_dialog.dart';
import '../widgets/engine_analysis_panel.dart';
import '../widgets/engine_diagnostics_panel.dart';
import '../widgets/engine_manager_dialog.dart';
import '../widgets/engine_settings_dialog.dart';
import '../widgets/move_tree_widget.dart';
import '../widgets/nibbler_board.dart';
import '../widgets/nibbler_eval_bar.dart';
import '../widgets/nibbler_fen_bar.dart';
import '../widgets/pgn_paste_dialog.dart';
import '../widgets/theme_settings_dialog.dart';

class ChessAnalysisScreen extends StatefulWidget {
  const ChessAnalysisScreen({super.key});

  @override
  State<ChessAnalysisScreen> createState() => _ChessAnalysisScreenState();
}

class _ChessAnalysisScreenState extends State<ChessAnalysisScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static UciEngineService? _sharedEngineService;

  late GameTree _gameTree;
  late EngineSettings _engineSettings;
  late UciEngineService _engineService;
  late ThemeService _themeService;
  late SoundService _soundService;

  PositionAnalysis? _currentAnalysis;
  StreamSubscription? _analysisSub;
  StreamSubscription? _statusSub;

  DraftVariation? _draftVariation;
  Timer? _draftAutoPlayTimer;

  bool _isFlipped = false;
  bool _isLiveAnalysisActive = true;
  String _engineStatusMessage = 'Initializing engine...';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _downloadService = EngineDownloadService();
    _downloadService.addListener(() {
      if (mounted) setState(() {});
    });

    _gameTree = GameTree.initial();
    _themeService = ThemeService();
    _soundService = SoundService();
    _engineSettings = EngineSettings(
      activeEngine: EngineType.stockfish,
      threads: 1,
      hashSizeMb: 16,
      multiPv: 3,
      lc0Backend: 'auto',
    );

    _engineService = _sharedEngineService ??= UciEngineService(_engineSettings);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      _saveSessionState();
    });

    _statusSub = _engineService.statusStream.listen((status) {
      if (mounted) {
        setState(() => _engineStatusMessage = status);
      }
    });

    _analysisSub = _engineService.analysisStream.listen((analysis) {
      if (mounted && _isLiveAnalysisActive && _gameTree.currentNode.position.toFen() == analysis.fen) {
        setState(() {
          _currentAnalysis = analysis;
          _gameTree.currentNode.cachedAnalysis = analysis;
        });
      }
    });

    _initScreenSession();
  }

  late final EngineDownloadService _downloadService;

  Future<void> _initScreenSession() async {
    await _downloadService.initialize();
    await _restoreSessionState();
    await _initEngineWithNativeCheck();
  }

  Future<void> _initEngineWithNativeCheck() async {
    final nativePath = await NativeEngineRunner.getEngineExecutablePath(_engineSettings.activeEngine);
    if (nativePath == null) {
      if (mounted) {
        setState(() {
          _isLiveAnalysisActive = false;
          _engineStatusMessage = '${_engineSettings.activeEngine.displayName} not installed. Tap Engine to download.';
        });
      }
      return;
    }
    await _engineService.initializeEngine(nativePath, settings: _engineSettings);
    if (mounted && _isLiveAnalysisActive) {
      _startOrUpdateAnalysis();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        _saveSessionState();
        _engineService.pauseForBackground();
        break;
      case AppLifecycleState.resumed:
        if (_isLiveAnalysisActive && _engineService.isPausedForBackground) {
          _engineService.resumeFromBackground();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Non-destructive transition; do not terminate engine
        break;
      case AppLifecycleState.detached:
        _saveSessionState();
        break;
    }
  }

  void _saveSessionState() {
    SessionPersistenceService.saveAppState(
      PersistedAppState(
        schemaVersion: SessionPersistenceService.currentSchemaVersion,
        boardThemeId: _themeService.activeBoard.id,
        pieceSet: _themeService.activePieceSet,
        showCoordinates: true,
        isFlipped: _isFlipped,
        pieceAnimationMs: _themeService.pieceAnimationMs,
        soundEnabled: _soundService.isEnabled,
        soundTheme: _soundService.activeTheme,
        soundVolume: _soundService.volume,
        hapticsEnabled: true,
        activeEngine: _engineSettings.activeEngine,
        isLiveAnalysisActive: _isLiveAnalysisActive,
        multiPv: _engineSettings.multiPv,
        arrowheadType: _engineSettings.arrowheadType,
        arrowFilterLc0: _engineSettings.arrowFilterLc0,
        arrowFilterOthers: _engineSettings.arrowFilterOthers,
        infoboxStats: _engineSettings.infoboxStats,
        stockfishThreads: _engineSettings.activeEngine == EngineType.stockfish ? _engineSettings.threads : 1,
        stockfishHashMb: _engineSettings.activeEngine == EngineType.stockfish ? _engineSettings.hashSizeMb : 16,
        selectedMaiaId: _engineSettings.selectedMaiaId,
        selectedNetworkPath: _engineSettings.weightsPath,
        lc0Backend: _engineSettings.lc0Backend,
        lc0Threads: _engineSettings.activeEngine == EngineType.lc0 ? _engineSettings.threads : 1,
        lc0HashMb: _engineSettings.activeEngine == EngineType.lc0 ? _engineSettings.hashSizeMb : 16,
        fen: _gameTree.currentNode.position.toFen(),
        pgn: PgnParser.exportPgn(_gameTree),
        selectedTab: _tabController.index,
        isDraftActive: _draftVariation != null,
        draftStartFen: _draftVariation?.startFen,
        draftPvMovesUci: _draftVariation?.pvLine.movesUci,
        draftSelectedMoveIndex: _draftVariation?.selectedMoveIndex,
      ),
    );
  }

  Future<void> _restoreSessionState() async {
    final state = await SessionPersistenceService.loadAppState();
    if (!mounted) return;

    setState(() {
      _themeService.activeBoard = _themeService.getBoardTheme(state.boardThemeId);
      _themeService.activePieceSet = state.pieceSet;
      _themeService.pieceAnimationMs = state.pieceAnimationMs;
      _isFlipped = state.isFlipped;

      _soundService.isEnabled = state.soundEnabled;
      _soundService.activeTheme = state.soundTheme;
      _soundService.setVolume(state.soundVolume);

      _isLiveAnalysisActive = state.isLiveAnalysisActive;
      _engineSettings = _engineSettings.copyWith(
        activeEngine: state.activeEngine,
        multiPv: state.multiPv,
        arrowheadType: state.arrowheadType,
        arrowFilterLc0: state.arrowFilterLc0,
        arrowFilterOthers: state.arrowFilterOthers,
        infoboxStats: state.infoboxStats,
        threads: state.activeEngine == EngineType.stockfish ? state.stockfishThreads : state.lc0Threads,
        hashSizeMb: state.activeEngine == EngineType.stockfish ? state.stockfishHashMb : state.lc0HashMb,
        lc0Backend: state.lc0Backend,
        selectedMaiaId: state.selectedMaiaId,
        weightsPath: state.selectedNetworkPath,
        nodeLimit: state.selectedMaiaId != null ? 1 : null,
      );

      if (state.pgn != null && state.pgn!.isNotEmpty) {
        try {
          _gameTree = PgnParser.parse(state.pgn!);
        } catch (_) {}
      } else if (state.fen.isNotEmpty) {
        try {
          final pos = ChessPosition.fromFen(state.fen);
          _gameTree = GameTree(root: GameNode(id: '0', position: pos, isOriginalMainline: true));
        } catch (_) {}
      }

      if (state.selectedTab >= 0 && state.selectedTab < 3) {
        _tabController.index = state.selectedTab;
      }
      final draft = state.reconstructDraftVariation();
      if (draft != null) {
        _draftVariation = draft;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftAutoPlayTimer?.cancel();
    _analysisSub?.cancel();
    _statusSub?.cancel();
    // Do NOT call _engineService.dispose() here! The native engine process
    // is preserved across rotation, backgrounding, and widget tree rebuilds.
    _soundService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startOrUpdateAnalysis() {
    _saveSessionState();
    if (!_isLiveAnalysisActive) return;
    if (_gameTree.currentNode.cachedAnalysis?.engineName == _engineSettings.activeEngine.displayName) {
      _currentAnalysis = _gameTree.currentNode.cachedAnalysis;
    } else {
      _currentAnalysis = null;
    }
    _engineService.startAnalysis(_gameTree.currentNode.position);
  }

  void _onMovePlayed(ChessMove move) {
    _stopDraftAutoPlay();
    _draftVariation = null;

    setState(() {
      _gameTree.addMove(move);
    });

    _soundService.playMoveSound(
      move: move,
      resultingPosition: _gameTree.currentNode.position,
    );

    _startOrUpdateAnalysis();
  }

  void _navigateToNode(GameNode node) {
    _stopDraftAutoPlay();
    _draftVariation = null;
    setState(() {
      _gameTree.jumpToNode(node);
    });
    _soundService.playSound(ChessSoundEvent.move);
    _startOrUpdateAnalysis();
  }

  void _stepBackward() {
    _stopDraftAutoPlay();
    _draftVariation = null;
    if (_gameTree.stepBackward()) {
      setState(() {});
      _soundService.playSound(ChessSoundEvent.move);
      _startOrUpdateAnalysis();
    }
  }

  void _stepForward() {
    _stopDraftAutoPlay();
    _draftVariation = null;
    if (_gameTree.stepForward()) {
      setState(() {});
      _soundService.playSound(ChessSoundEvent.move);
      _startOrUpdateAnalysis();
    }
  }

  void _goToStart() {
    _stopDraftAutoPlay();
    _draftVariation = null;
    setState(() => _gameTree.goToStart());
    _startOrUpdateAnalysis();
  }

  void _goToEnd() {
    _stopDraftAutoPlay();
    _draftVariation = null;
    setState(() => _gameTree.goToEndOfCurrentLine());
    _startOrUpdateAnalysis();
  }

  void _returnToOriginalGame() {
    _stopDraftAutoPlay();
    _draftVariation = null;
    setState(() => _gameTree.returnToOriginalGame());
    _startOrUpdateAnalysis();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Returned to original game mainline'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Interactive Draft Variation Lifecycle ---

  void _onSelectPvMove(PvLine line, int moveIndex) {
    if (moveIndex < 0 || moveIndex >= line.pvMoves.length) return;

    if (_draftVariation == null || _draftVariation!.pvLine.multipv != line.multipv) {
      final draft = DraftVariation(
        startFen: _gameTree.currentNode.position.toFen(),
        rootPosition: _gameTree.currentNode.position,
        pvLine: line,
        selectedMoveIndex: moveIndex,
      );
      setState(() {
        _draftVariation = draft;
      });
    } else {
      setState(() {
        _draftVariation = _draftVariation!.stepTo(moveIndex);
      });
    }
    _soundService.playSound(ChessSoundEvent.move);
    _saveSessionState();
  }

  void _exitDraftVariation() {
    _stopDraftAutoPlay();
    setState(() {
      _draftVariation = null;
    });
    _saveSessionState();
  }

  void _commitDraftVariation() {
    _stopDraftAutoPlay();
    final draft = _draftVariation;
    if (draft == null || draft.selectedMoveIndex < 0) return;

    final movesToCommit = draft.pvLine.pvMoves.take(draft.selectedMoveIndex + 1);
    for (final pvItem in movesToCommit) {
      _gameTree.addMove(pvItem.move);
    }

    setState(() {
      _draftVariation = null;
    });

    _soundService.playSound(ChessSoundEvent.move);
    _startOrUpdateAnalysis();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added variation (${movesToCommit.length} moves) to game tree'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF005FB8),
      ),
    );
  }

  void _onDraftStepBackward() {
    if (_draftVariation == null) return;
    setState(() {
      _draftVariation = _draftVariation!.stepBackward();
    });
    _soundService.playSound(ChessSoundEvent.move);
    _saveSessionState();
  }

  void _onDraftStepForward() {
    if (_draftVariation == null) return;
    setState(() {
      _draftVariation = _draftVariation!.stepForward();
    });
    _soundService.playSound(ChessSoundEvent.move);
    _saveSessionState();
  }

  void _onDraftGoToStart() {
    if (_draftVariation == null) return;
    setState(() {
      _draftVariation = _draftVariation!.goToStart();
    });
    _saveSessionState();
  }

  void _onDraftGoToEnd() {
    if (_draftVariation == null) return;
    setState(() {
      _draftVariation = _draftVariation!.goToEnd();
    });
    _saveSessionState();
  }

  void _onDraftToggleAutoPlay() {
    if (_draftVariation == null) return;
    if (_draftVariation!.isAutoPlaying) {
      _stopDraftAutoPlay();
    } else {
      _startDraftAutoPlay();
    }
    _saveSessionState();
  }

  void _startDraftAutoPlay() {
    if (_draftVariation == null) return;
    _draftAutoPlayTimer?.cancel();
    setState(() {
      _draftVariation = _draftVariation!.withAutoPlaying(true);
    });

    _draftAutoPlayTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted || _draftVariation == null || !_draftVariation!.isAutoPlaying) {
        timer.cancel();
        return;
      }
      if (_draftVariation!.canStepForward) {
        setState(() {
          _draftVariation = _draftVariation!.stepForward();
        });
        _soundService.playSound(ChessSoundEvent.move);
        _saveSessionState();
      } else {
        _stopDraftAutoPlay();
      }
    });
  }

  void _stopDraftAutoPlay() {
    _draftAutoPlayTimer?.cancel();
    _draftAutoPlayTimer = null;
    if (mounted && _draftVariation != null && _draftVariation!.isAutoPlaying) {
      setState(() {
        _draftVariation = _draftVariation!.withAutoPlaying(false);
      });
      _saveSessionState();
    }
  }

  void _toggleLiveAnalysis() async {
    setState(() {
      _isLiveAnalysisActive = !_isLiveAnalysisActive;
    });
    _saveSessionState();
    if (_isLiveAnalysisActive) {
      await _engineService.enableEngine();
      _startOrUpdateAnalysis();
    } else {
      await _engineService.disableEngine();
      setState(() {
        _currentAnalysis = null;
      });
    }
  }

  void _toggleAnalysisPause() {
    if (!_isLiveAnalysisActive) {
      _toggleLiveAnalysis();
      return;
    }
    if (_engineService.searchState == AnalysisDataState.searching) {
      _engineService.pauseAnalysis();
    } else {
      _engineService.resumeAnalysis();
    }
    setState(() {});
  }

  void _flipBoard() {
    setState(() => _isFlipped = !_isFlipped);
    _saveSessionState();
  }

  void _openPgnPasteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => PgnPasteDialog(
        onImportPgn: (pgn) {
          try {
            final parsedTree = PgnParser.parse(pgn);
            setState(() {
              _gameTree = parsedTree;
            });
            _startOrUpdateAnalysis();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PGN loaded successfully!'),
                backgroundColor: Color(0xFF2E7D32),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error parsing PGN: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _openEngineSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => EngineSettingsDialog(
        settings: _engineSettings,
        onSave: (newSettings) async {
          final engineChanged = _engineSettings.activeEngine != newSettings.activeEngine;
          setState(() {
            _engineSettings = newSettings;
            if (engineChanged) {
              _currentAnalysis = null;
              _gameTree.currentNode.cachedAnalysis = null;
            }
          });
          final nativePath = await NativeEngineRunner.getEngineExecutablePath(newSettings.activeEngine);
          await _engineService.updateSettings(newSettings, binaryPath: nativePath);
          _saveSessionState();
          if (_isLiveAnalysisActive) _startOrUpdateAnalysis();
        },
      ),
    );
  }

  void _openEngineManagerDialog() {
    EngineManagerDialog.show(
      context,
      settings: _engineSettings,
      onSettingsChanged: (newSettings) async {
        final engineChanged = _engineSettings.activeEngine != newSettings.activeEngine;
        final maiaChanged = _engineSettings.selectedMaiaId != newSettings.selectedMaiaId;
        setState(() {
          _engineSettings = newSettings;
          if (engineChanged || maiaChanged) {
            _currentAnalysis = null;
            _gameTree.currentNode.cachedAnalysis = null;
          }
        });
        final nativePath = await NativeEngineRunner.getEngineExecutablePath(newSettings.activeEngine);
        await _engineService.updateSettings(_engineSettings, binaryPath: nativePath);
        _saveSessionState();
        if (_isLiveAnalysisActive) _startOrUpdateAnalysis();
      },
    );
  }

  void _openThemeSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ThemeSettingsDialog(
        themeService: _themeService,
        soundService: _soundService,
        onThemeChanged: () {
          setState(() {});
          _saveSessionState();
        },
      ),
    );
  }

  void _openArrowSettingsDialog() {
    ArrowSettingsDialog.show(
      context,
      settings: _engineSettings,
      onSettingsChanged: (updated) {
        setState(() {
          _engineSettings = updated;
        });
        _engineService.updatePresentationSettings(updated);
        _saveSessionState();
      },
    );
  }

  void _openAboutDialog() {
    ChessCrackAboutDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentPos = _gameTree.currentNode.position;
    final displayedPos = _draftVariation?.currentPosition ?? currentPos;
    final displayedLastMove = _draftVariation != null
        ? _draftVariation!.currentMove
        : _gameTree.currentNode.move;
    final candidateLines = _isLiveAnalysisActive
        ? (_currentAnalysis?.pvLines ?? const <PvLine>[])
        : const <PvLine>[];
    // Candidate arrows from Position A are strictly SUPPRESSED while browsing a draft variation (Position D)
    final displayedCandidateArrows = (_isLiveAnalysisActive && _draftVariation == null)
        ? (_currentAnalysis?.candidateArrows ?? const <CandidateArrow>[])
        : const <CandidateArrow>[];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight;
            final isLandscape = availableWidth > availableHeight && availableWidth >= 520;

            const evalBarWidth = 24.0;
            const spacing = 6.0;
            const horizontalPadding = 8.0;

            if (isLandscape) {
              // Dual-Pane Landscape Layout
              final maxPaneHeight = availableHeight - 44.0;
              const fenHeight = 30.0;
              final maxBoardHeight = maxPaneHeight - fenHeight - 16.0;
              final maxBoardWidth = (availableWidth * 0.50) - evalBarWidth - spacing - (horizontalPadding * 2);
              final boardSize = math.min(maxBoardWidth, maxBoardHeight).clamp(160.0, 720.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(availableWidth < 460 || MediaQuery.textScalerOf(context).scale(1.0) > 1.15),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: boardSize + evalBarWidth + spacing + (horizontalPadding * 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                   NibblerEvalBar(
                                     evaluationNotifier: _engineService.evaluationNotifier,
                                     isFlipped: _isFlipped,
                                     width: evalBarWidth,
                                     height: boardSize,
                                   ),
                                  const SizedBox(width: spacing),
                                  SizedBox(
                                    width: boardSize,
                                    height: boardSize,
                                    child: NibblerBoard(
                                      position: displayedPos,
                                      positionRevision: _currentAnalysis?.positionRevision ?? _engineService.positionRevision,
                                      analysisRequestId: _currentAnalysis?.analysisRequestId ?? _engineService.analysisRequestId,
                                      lastMove: displayedLastMove,
                                      isFlipped: _isFlipped,
                                      boardTheme: _themeService.activeBoard,
                                      pieceSet: _themeService.activePieceSet,
                                      candidateLines: candidateLines,
                                      candidateArrows: displayedCandidateArrows,
                                      arrowheadType: _engineSettings.arrowheadType,
                                      engineType: _engineSettings.activeEngine,
                                      animationDurationMs: _themeService.pieceAnimationMs,
                                      onMove: _onMovePlayed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                                child: NibblerFenBar(fen: displayedPos.toFen()),
                              ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1, color: Color(0xFF282828)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF161616),
                                  border: Border(
                                    bottom: BorderSide(color: Color(0xFF282828), width: 1),
                                  ),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  indicatorColor: const Color(0xFF00D2BE),
                                  indicatorWeight: 2,
                                  labelColor: const Color(0xFF00D2BE),
                                  unselectedLabelColor: Colors.white54,
                                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  tabs: const [
                                    Tab(text: 'ENGINE ANALYSIS'),
                                    Tab(text: 'GAME TREE & PGN'),
                                    Tab(text: 'DIAGNOSTICS'),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    EngineAnalysisPanel(
                                      analysis: _currentAnalysis,
                                      isAnalyzing: _isLiveAnalysisActive && _engineService.searchState == AnalysisDataState.searching,
                                      onToggleAnalysis: _toggleAnalysisPause,
                                      onPlayMove: _onMovePlayed,
                                      currentPosition: currentPos,
                                      settings: _engineSettings,
                                      draftVariation: _draftVariation,
                                      onSelectPvMove: _onSelectPvMove,
                                      onExitDraftVariation: _exitDraftVariation,
                                      onCommitDraftVariation: _commitDraftVariation,
                                      onDraftStepBackward: _onDraftStepBackward,
                                      onDraftStepForward: _onDraftStepForward,
                                      onDraftGoToStart: _onDraftGoToStart,
                                      onDraftGoToEnd: _onDraftGoToEnd,
                                      onDraftToggleAutoPlay: _onDraftToggleAutoPlay,
                                    ),
                                    MoveTreeWidget(
                                      gameTree: _gameTree,
                                      onSelectNode: _navigateToNode,
                                      onStepBackward: _stepBackward,
                                      onStepForward: _stepForward,
                                      onGoToStart: _goToStart,
                                      onGoToEnd: _goToEnd,
                                      onReturnToOriginal: _returnToOriginalGame,
                                    ),
                                    EngineDiagnosticsPanel(
                                      diagnostics: _currentAnalysis?.diagnostics,
                                      isAnalyzing: _isLiveAnalysisActive && _engineService.isAnalyzing,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Single-Pane Portrait Layout
            const headerHeight = 44.0;
            const fenHeight = 28.0;
            const tabBarHeight = 36.0;
            const minTabsHeight = 150.0;
            const verticalFixed = headerHeight + fenHeight + tabBarHeight + minTabsHeight + 12.0;

            final maxBoardWidth = availableWidth - (horizontalPadding * 2) - evalBarWidth - spacing;
            final maxBoardHeight = availableHeight - verticalFixed;
            final boardSize = math.min(maxBoardWidth, maxBoardHeight > 180.0 ? maxBoardHeight : maxBoardWidth).clamp(180.0, 640.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(availableWidth < 460 || MediaQuery.textScalerOf(context).scale(1.0) > 1.15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NibblerEvalBar(
                        evaluationNotifier: _engineService.evaluationNotifier,
                        isFlipped: _isFlipped,
                        width: evalBarWidth,
                        height: boardSize,
                      ),
                      const SizedBox(width: spacing),
                      SizedBox(
                        width: boardSize,
                        height: boardSize,
                        child: NibblerBoard(
                          position: displayedPos,
                          positionRevision: _currentAnalysis?.positionRevision ?? _engineService.positionRevision,
                          analysisRequestId: _currentAnalysis?.analysisRequestId ?? _engineService.analysisRequestId,
                          lastMove: displayedLastMove,
                          isFlipped: _isFlipped,
                          boardTheme: _themeService.activeBoard,
                          pieceSet: _themeService.activePieceSet,
                          candidateLines: candidateLines,
                          candidateArrows: displayedCandidateArrows,
                          arrowheadType: _engineSettings.arrowheadType,
                          engineType: _engineSettings.activeEngine,
                          animationDurationMs: _themeService.pieceAnimationMs,
                          onMove: _onMovePlayed,
                        ),
                      ),
                    ],
                  ),
                ),
                NibblerFenBar(fen: displayedPos.toFen()),
                Container(
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF161616),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF282828), width: 1),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: const Color(0xFF00D2BE),
                    indicatorWeight: 2,
                    labelColor: const Color(0xFF00D2BE),
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'ENGINE ANALYSIS'),
                      Tab(text: 'GAME TREE & PGN'),
                      Tab(text: 'DIAGNOSTICS'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      EngineAnalysisPanel(
                        analysis: _currentAnalysis,
                        isAnalyzing: _isLiveAnalysisActive && _engineService.searchState == AnalysisDataState.searching,
                        onToggleAnalysis: _toggleAnalysisPause,
                        onPlayMove: _onMovePlayed,
                        currentPosition: currentPos,
                        settings: _engineSettings,
                        draftVariation: _draftVariation,
                        onSelectPvMove: _onSelectPvMove,
                        onExitDraftVariation: _exitDraftVariation,
                        onCommitDraftVariation: _commitDraftVariation,
                        onDraftStepBackward: _onDraftStepBackward,
                        onDraftStepForward: _onDraftStepForward,
                        onDraftGoToStart: _onDraftGoToStart,
                        onDraftGoToEnd: _onDraftGoToEnd,
                        onDraftToggleAutoPlay: _onDraftToggleAutoPlay,
                      ),
                      MoveTreeWidget(
                        gameTree: _gameTree,
                        onSelectNode: _navigateToNode,
                        onStepBackward: _stepBackward,
                        onStepForward: _stepForward,
                        onGoToStart: _goToStart,
                        onGoToEnd: _goToEnd,
                        onReturnToOriginal: _returnToOriginalGame,
                      ),
                      EngineDiagnosticsPanel(
                        diagnostics: _currentAnalysis?.diagnostics,
                        isAnalyzing: _isLiveAnalysisActive && _engineService.isAnalyzing,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isNarrow) {
    final bool isEngineInstalled = _downloadService.isEngineInstalled(_engineSettings.activeEngine);
    final bool isMaiaRequired = _engineSettings.activeEngine == EngineType.lc0 &&
        _engineSettings.isMaiaActive &&
        _engineSettings.selectedMaiaId != null;
    final bool isMaiaInstalled = !isMaiaRequired ||
        (_downloadService.getMaiaModel(_engineSettings.selectedMaiaId!)?.isInstalled ?? false);
    final bool isFullyReady = isEngineInstalled && isMaiaInstalled;

    String enginePillText;
    if (_engineSettings.activeEngine == EngineType.stockfish) {
      enginePillText = 'Stockfish 19';
    } else {
      if (_engineSettings.isMaiaActive && _engineSettings.selectedMaiaId != null) {
        enginePillText = 'Lc0 • ${_engineSettings.selectedMaiaId}';
      } else {
        enginePillText = 'Lc0 v0.32.1';
      }
    }
    if (!isFullyReady) {
      enginePillText += ' [Not Installed]';
    }

    final Color statusDotColor = !isFullyReady
        ? Colors.redAccent
        : (_isLiveAnalysisActive ? const Color(0xFF00D2BE) : Colors.amber);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(bottom: BorderSide(color: Color(0xFF222222), width: 1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              'assets/icon/chesscrack_icon.png',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => const Icon(Icons.flash_on, color: Color(0xFF00D2BE), size: 20),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'ChessCrack',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: _openEngineManagerDialog,
              child: Tooltip(
                message: isFullyReady
                    ? 'Engine: $enginePillText ($_engineStatusMessage) - Tap to manage'
                    : 'Engine or Network not installed! Tap to download.',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFullyReady ? const Color(0xFF1F1F1F) : const Color(0xFF331111),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isFullyReady ? const Color(0xFF333333) : const Color(0x99FF5252),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusDotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          enginePillText,
                          style: TextStyle(
                            color: isFullyReady ? const Color(0xFFE0E0E0) : Colors.redAccent.shade100,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Explicit Engine ON / OFF Toggle
          GestureDetector(
            onTap: _toggleLiveAnalysis,
            child: Tooltip(
              message: _isLiveAnalysisActive
                  ? 'Engine is active (Tap to turn OFF)'
                  : 'Engine is disabled (Tap to turn ON)',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _isLiveAnalysisActive ? const Color(0xFF003830) : const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isLiveAnalysisActive ? const Color(0xFF00D2BE) : Colors.white24,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isLiveAnalysisActive ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: _isLiveAnalysisActive ? const Color(0xFF00D2BE) : Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isLiveAnalysisActive ? const Color(0xFF00D2BE) : Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          // Core primary actions (always in identical order across portrait & landscape)
          IconButton(
            icon: const Icon(Icons.download_for_offline, color: Color(0xFF00D2BE), size: 19),
            onPressed: _openEngineManagerDialog,
            tooltip: 'Engine & Maia Manager',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.paste, color: Color(0xFF00D2BE), size: 19),
            onPressed: _openPgnPasteDialog,
            tooltip: 'Paste PGN',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.swap_vert, color: Colors.white70, size: 20),
            onPressed: _flipBoard,
            tooltip: 'Flip Board',
            visualDensity: VisualDensity.compact,
          ),
          if (!isNarrow) ...[
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white70, size: 19),
              onPressed: _openEngineSettingsDialog,
              tooltip: 'Engine Settings',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.north_east, color: Color(0xFF00D2BE), size: 19),
              onPressed: _openArrowSettingsDialog,
              tooltip: 'Arrow Settings',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.palette_outlined, color: Colors.white70, size: 19),
              onPressed: _openThemeSettingsDialog,
              tooltip: 'Board & Appearance',
              visualDensity: VisualDensity.compact,
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
            color: const Color(0xFF222222),
            onSelected: (value) {
              switch (value) {
                case 'engine_manager':
                  _openEngineManagerDialog();
                  break;
                case 'arrows':
                  _openArrowSettingsDialog();
                  break;
                case 'engine':
                  _openEngineSettingsDialog();
                  break;
                case 'theme':
                  _openThemeSettingsDialog();
                  break;
                case 'return':
                  _returnToOriginalGame();
                  break;
                case 'about':
                  _openAboutDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (isNarrow) ...[
                const PopupMenuItem(
                  value: 'engine',
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text('Engine Settings', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'arrows',
                  child: Row(
                    children: [
                      Icon(Icons.north_east, color: Color(0xFF00D2BE), size: 18),
                      SizedBox(width: 8),
                      Text('Arrow Settings', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'theme',
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text('Board & Appearance', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ],
              const PopupMenuItem(
                value: 'return',
                child: Row(
                  children: [
                    Icon(Icons.replay, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text('Return to Mainline', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 8),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF00D2BE), size: 18),
                    SizedBox(width: 8),
                    Text('About & Licenses', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
