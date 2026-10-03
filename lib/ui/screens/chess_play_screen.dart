import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/chess_play_controller.dart';
import '../../models/chess_clock.dart';
import '../../models/chess_game_record.dart';
import '../../models/chess_move.dart';
import '../../models/engine_analysis.dart';
import '../../services/engine_download_service.dart';
import '../../services/pgn_storage_service.dart';
import '../../services/theme_service.dart';
import '../../services/uci_engine_service.dart';
import '../widgets/nibbler_board.dart';
import 'my_games_screen.dart';
import 'play_setup_dialog.dart';

class ChessPlayScreen extends StatefulWidget {
  final PlayGameConfig config;
  final UciEngineService engineService;
  final EngineDownloadService downloadService;
  final void Function(ChessGameRecord record)? onReviewGame;

  const ChessPlayScreen({
    super.key,
    required this.config,
    required this.engineService,
    required this.downloadService,
    this.onReviewGame,
  });

  @override
  State<ChessPlayScreen> createState() => _ChessPlayScreenState();
}

class _ChessPlayScreenState extends State<ChessPlayScreen> {
  late final ChessPlayController _controller;
  final ThemeService _themeService = ThemeService();
  bool _gameOverDialogShown = false;

  @override
  void initState() {
    super.initState();
    _controller = ChessPlayController(engineService: widget.engineService);
    _controller.addListener(_onControllerUpdate);

    // Resolve Maia network path if opponent is Maia
    String? maiaWeightsPath;
    if (widget.config.opponentEngine == EngineType.lc0 && widget.config.selectedMaiaId != null) {
      final model = widget.downloadService.getMaiaModel(widget.config.selectedMaiaId!);
      maiaWeightsPath = model?.localPath;
    }

    // Launch game session
    _controller.startNewGame(
      opponentEngine: widget.config.opponentEngine,
      playerColor: widget.config.playerColor,
      timeControl: widget.config.timeControl,
      stockfishElo: widget.config.stockfishElo,
      limitStrength: widget.config.limitStrength,
      selectedMaiaId: widget.config.selectedMaiaId,
      maiaWeightsPath: maiaWeightsPath,
      maiaThinkingProfile: widget.config.maiaThinkingProfile,
    );
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});

    if (_controller.gameState == PlayGameState.gameEnded && !_gameOverDialogShown) {
      _gameOverDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGameOverDialog();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _showLeaveConfirmation() async {
    if (_controller.gameState == PlayGameState.gameEnded) {
      return true;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Leave Game?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Leaving will forfeit your current game.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _controller.resign();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Resign & Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  void _showGameOverDialog() {
    final record = _controller.savedRecord;
    final isWhite = _controller.playerColor == PieceColor.white;
    String outcomeTitle;
    Color outcomeColor;

    if (_controller.gameResult == '1-0') {
      outcomeTitle = isWhite ? 'VICTORY!' : 'DEFEAT';
      outcomeColor = isWhite ? Colors.greenAccent : Colors.redAccent;
    } else if (_controller.gameResult == '0-1') {
      outcomeTitle = isWhite ? 'DEFEAT' : 'VICTORY!';
      outcomeColor = isWhite ? Colors.redAccent : Colors.greenAccent;
    } else if (_controller.gameResult == '1/2-1/2') {
      outcomeTitle = 'DRAW';
      outcomeColor = Colors.amberAccent;
    } else {
      outcomeTitle = 'GAME ABORTED';
      outcomeColor = Colors.white70;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                outcomeTitle,
                style: TextStyle(
                  color: outcomeColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_controller.gameResult} • ${_controller.savedRecord?.readableTermination ?? "Game ended"}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),

              // Automatic save verification badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF003830),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00D2BE).withAlpha(100)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00D2BE), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Game automatically saved',
                      style: TextStyle(
                        color: Color(0xFFE0F2F1),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D2BE),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final rec = _controller.savedRecord ?? record;
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop(rec);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF444444)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Export PGN'),
                      onPressed: () async {
                        final rec = _controller.savedRecord ?? record;
                        if (rec != null) {
                          await Clipboard.setData(ClipboardData(text: rec.pgn));
                          final path = await PgnStorageService.instance.exportToDownloads(
                            rec.pgn,
                            '${rec.whitePlayer}_vs_${rec.blackPlayer}_${rec.id}.pgn',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(path != null
                                    ? 'PGN copied & exported to:\n$path'
                                    : 'PGN copied to clipboard!'),
                                backgroundColor: const Color(0xFF00D2BE),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.folder_open, size: 17, color: Colors.white70),
                      label: const Text('My Games', style: TextStyle(color: Colors.white70)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final rec = await Navigator.of(context).push<ChessGameRecord?>(
                          MaterialPageRoute(
                            builder: (c) => const MyGamesScreen(),
                          ),
                        );
                        if (rec != null && mounted) {
                          Navigator.of(context).pop(rec);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.replay, size: 17, color: Color(0xFF00D2BE)),
                      label: const Text('New Game', style: TextStyle(color: Color(0xFF00D2BE), fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final newCfg = await PlaySetupDialog.show(
                          context,
                          engineService: widget.engineService,
                          downloadService: widget.downloadService,
                        );
                        if (newCfg != null) {
                          setState(() {
                            _gameOverDialogShown = false;
                          });
                          String? newMaiaWeights;
                          if (newCfg.opponentEngine == EngineType.lc0 && newCfg.selectedMaiaId != null) {
                            final model = widget.downloadService.getMaiaModel(newCfg.selectedMaiaId!);
                            newMaiaWeights = model?.localPath;
                          }
                          _controller.startNewGame(
                            opponentEngine: newCfg.opponentEngine,
                            playerColor: newCfg.playerColor,
                            timeControl: newCfg.timeControl,
                            stockfishElo: newCfg.stockfishElo,
                            limitStrength: newCfg.limitStrength,
                            selectedMaiaId: newCfg.selectedMaiaId,
                            maiaWeightsPath: newMaiaWeights,
                            maiaThinkingProfile: newCfg.maiaThinkingProfile,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _controller.gameState == PlayGameState.gameEnded,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldLeave = await _showLeaveConfirmation();
        if (shouldLeave && mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final boardSize = math.min(w - 16, h - 230).clamp(160.0, 600.0);

              final isFlipped = _controller.playerColor == PieceColor.black;
              final opponentSide = isFlipped ? ClockSide.white : ClockSide.black;
              final playerSide = isFlipped ? ClockSide.black : ClockSide.white;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Bar / Top Navigation
                  _buildTopBar(),

                  // Opponent Header Card & Clock
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: _buildPlayerBadge(
                      title: _controller.opponentDisplayName,
                      isOpponent: true,
                      isThinking: _controller.gameState == PlayGameState.engineThinking,
                      clockSide: opponentSide,
                    ),
                  ),

                  // Chess Board Area
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: boardSize,
                        height: boardSize,
                        child: NibblerBoard(
                          position: _controller.position,
                          lastMove: _controller.moveHistory.isNotEmpty ? _controller.moveHistory.last : null,
                          isFlipped: isFlipped,
                          boardTheme: _themeService.activeBoard,
                          pieceSet: _themeService.activePieceSet,
                          candidateArrows: _controller.hintArrow != null ? [_controller.hintArrow!] : const [],
                          arrowheadType: ArrowheadType.winrate,
                          engineType: _controller.opponentEngine,
                          onMove: (move) => _controller.playPlayerMove(move),
                        ),
                      ),
                    ),
                  ),

                  // Player Footer Card & Clock
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: _buildPlayerBadge(
                      title: 'You',
                      isOpponent: false,
                      isThinking: _controller.isPlayerTurn,
                      clockSide: playerSide,
                    ),
                  ),

                  // Move history chips
                  _buildMoveHistoryStrip(),

                  // Bottom Action Bar
                  _buildBottomControls(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(bottom: BorderSide(color: Color(0xFF262626))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
            onPressed: () async {
              final nav = Navigator.of(context);
              if (await _showLeaveConfirmation()) {
                if (mounted) nav.pop();
              }
            },
          ),
          const SizedBox(width: 4),
          const Text(
            'PLAY',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _controller.timeControl.displayName,
              style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.white70, size: 20),
            tooltip: 'My Games',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (c) => MyGamesScreen(
                    onReviewGame: (r) {
                      if (widget.onReviewGame != null) {
                        widget.onReviewGame!(r);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerBadge({
    required String title,
    required bool isOpponent,
    required bool isThinking,
    required ClockSide clockSide,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isThinking ? const Color(0xFF242424) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isThinking ? const Color(0xFF00D2BE).withAlpha(100) : const Color(0xFF2B2B2B),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOpponent ? Icons.smart_toy_outlined : Icons.person_outline,
            color: isThinking ? const Color(0xFF00D2BE) : Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isThinking) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFF00D2BE),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Clock Badge
          if (_controller.clock != null) ...[
            ValueListenableBuilder<ChessClockState>(
              valueListenable: _controller.clock!.notifier,
              builder: (context, clockState, _) {
                final isThisClockActive = clockState.activeSide == clockSide && clockState.isTicking;
                final formatted = clockState.formatTime(clockSide);
                final ms = clockSide == ClockSide.white ? clockState.whiteRemainingMs : clockState.blackRemainingMs;
                final isLowTime = ms < 10000 && ms > 0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isThisClockActive
                        ? (isLowTime ? const Color(0xFF4A1010) : const Color(0xFF003830))
                        : const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isThisClockActive
                          ? (isLowTime ? Colors.redAccent : const Color(0xFF00D2BE))
                          : Colors.white12,
                    ),
                  ),
                  child: Text(
                    formatted,
                    style: TextStyle(
                      color: isThisClockActive
                          ? (isLowTime ? Colors.redAccent : const Color(0xFF00D2BE))
                          : Colors.white60,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoveHistoryStrip() {
    final moves = _controller.sanHistory;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF161616),
      child: moves.isEmpty
          ? const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Game not started',
                style: TextStyle(color: Colors.white30, fontSize: 11),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: moves.length,
              itemBuilder: (ctx, idx) {
                final moveNumber = (idx ~/ 2) + 1;
                final isWhiteMove = idx % 2 == 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: idx == moves.length - 1 ? const Color(0xFF2C2C2C) : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isWhiteMove ? '$moveNumber. ${moves[idx]}' : moves[idx],
                      style: TextStyle(
                        color: idx == moves.length - 1 ? const Color(0xFF00D2BE) : Colors.white70,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: idx == moves.length - 1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBottomControls() {
    final canHint = _controller.isPlayerTurn && !_controller.isHintLoading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Hint Button
          TextButton.icon(
            icon: _controller.isHintLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D2BE)),
                  )
                : const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFF00D2BE)),
            label: const Text('Hint', style: TextStyle(color: Color(0xFF00D2BE))),
            onPressed: canHint ? _controller.requestHint : null,
          ),

          // Resign Button
          TextButton.icon(
            icon: const Icon(Icons.flag_outlined, size: 18, color: Colors.redAccent),
            label: const Text('Resign', style: TextStyle(color: Colors.redAccent)),
            onPressed: _controller.gameState != PlayGameState.gameEnded ? _confirmResign : null,
          ),

          // Abort Button (Available before move 2)
          if (_controller.moveHistory.length < 2 && _controller.gameState != PlayGameState.gameEnded)
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.white54),
              label: const Text('Abort', style: TextStyle(color: Colors.white54)),
              onPressed: _controller.abortGame,
            ),
        ],
      ),
    );
  }

  void _confirmResign() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Resign Game?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to resign?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              _controller.resign();
            },
            child: const Text('Resign', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
