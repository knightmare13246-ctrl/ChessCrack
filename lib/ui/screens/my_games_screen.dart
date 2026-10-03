import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chess_game_record.dart';
import '../../services/pgn_storage_service.dart';

class MyGamesScreen extends StatefulWidget {
  final void Function(ChessGameRecord record)? onReviewGame;

  const MyGamesScreen({super.key, this.onReviewGame});

  @override
  State<MyGamesScreen> createState() => _MyGamesScreenState();
}

class _MyGamesScreenState extends State<MyGamesScreen> {
  List<ChessGameRecord> _games = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() => _isLoading = true);
    final games = await PgnStorageService.instance.loadAllGames();
    if (mounted) {
      setState(() {
        _games = games;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteGame(ChessGameRecord game) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Delete Game?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${game.whitePlayer} vs ${game.blackPlayer} (${game.result})?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PgnStorageService.instance.deleteGame(game.id);
      _loadGames();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game deleted')),
        );
      }
    }
  }

  Future<void> _exportGame(ChessGameRecord game) async {
    final pgn = await PgnStorageService.instance.loadGamePgn(game.id) ?? game.pgn;
    if (pgn.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load PGN for export')),
        );
      }
      return;
    }

    await Clipboard.setData(ClipboardData(text: pgn));
    final filename = '${game.whitePlayer}_vs_${game.blackPlayer}_${game.id}.pgn';
    final path = await PgnStorageService.instance.exportToDownloads(pgn, filename);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('My Games Library', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00D2BE)),
            onPressed: _loadGames,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D2BE)))
          : _games.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _games.length,
                  itemBuilder: (ctx, index) {
                    final game = _games[index];
                    return _buildGameCard(game);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withAlpha(50)),
          const SizedBox(height: 16),
          const Text(
            'No Games Saved Yet',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Completed games against Stockfish or Maia\nare automatically saved here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(ChessGameRecord game) {
    final isWhiteUser = game.userSide == 'white';
    Color resultColor;
    String userOutcome;
    if (game.result == '1-0') {
      userOutcome = isWhiteUser ? 'WON' : 'LOST';
      resultColor = isWhiteUser ? Colors.greenAccent : Colors.redAccent;
    } else if (game.result == '0-1') {
      userOutcome = isWhiteUser ? 'LOST' : 'WON';
      resultColor = isWhiteUser ? Colors.redAccent : Colors.greenAccent;
    } else if (game.result == '1/2-1/2') {
      userOutcome = 'DRAW';
      resultColor = Colors.amberAccent;
    } else {
      userOutcome = 'ABORTED';
      resultColor = Colors.white54;
    }

    final dateFormatted =
        '${game.date.year}-${game.date.month.toString().padLeft(2, '0')}-${game.date.day.toString().padLeft(2, '0')} ${game.date.hour.toString().padLeft(2, '0')}:${game.date.minute.toString().padLeft(2, '0')}';

    return Card(
      color: const Color(0xFF202020),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF2E2E2E)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          var fullGame = game;
          if (fullGame.pgn.isEmpty) {
            final loadedPgn = await PgnStorageService.instance.loadGamePgn(game.id);
            if (loadedPgn != null && loadedPgn.isNotEmpty) {
              fullGame = ChessGameRecord(
                id: game.id,
                date: game.date,
                whitePlayer: game.whitePlayer,
                blackPlayer: game.blackPlayer,
                userSide: game.userSide,
                result: game.result,
                terminationReason: game.terminationReason,
                timeControl: game.timeControl,
                moveCount: game.moveCount,
                finalFen: game.finalFen,
                pgn: loadedPgn,
              );
            }
          }
          if (mounted) {
            if (widget.onReviewGame != null) {
              widget.onReviewGame!(fullGame);
            }
            Navigator.of(context).pop(fullGame);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Players + Outcome Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('♔ ', style: TextStyle(color: Colors.white, fontSize: 14)),
                            Expanded(
                              child: Text(
                                game.whitePlayer,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isWhiteUser ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Text('♚ ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Expanded(
                              child: Text(
                                game.blackPlayer,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: !isWhiteUser ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: resultColor.withAlpha(35),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: resultColor.withAlpha(120)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          game.result,
                          style: TextStyle(
                            color: resultColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          userOutcome,
                          style: TextStyle(
                            color: resultColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Bottom Details Row: Date, TC, Moves, Termination
              Row(
                children: [
                  Text(
                    dateFormatted,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      game.timeControl.displayName,
                      style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${game.moveCount} plies',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const Spacer(),
                  // Action buttons
                  IconButton(
                    icon: const Icon(Icons.share, size: 18, color: Colors.white60),
                    tooltip: 'Export PGN',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _exportGame(game),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                    tooltip: 'Delete',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _deleteGame(game),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
