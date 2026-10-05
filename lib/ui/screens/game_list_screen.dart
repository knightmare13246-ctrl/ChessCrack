import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/chess_database_models.dart';
import '../../services/chesscrack_core.dart';
import 'database_stats_dialog.dart';

class GameListScreen extends StatefulWidget {
  final ChessDatabase database;
  final void Function(String pgn, String title)? onOpenGameInAnalysis;
  final VoidCallback? onDatabaseModified;

  const GameListScreen({
    super.key,
    required this.database,
    this.onOpenGameInAnalysis,
    this.onDatabaseModified,
  });

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  late ChessDatabase _db;
  List<GameSummary> _games = [];
  bool _isLoading = false;
  int _totalCount = 0;
  int _page = 0;
  static const int _pageSize = 50;

  // Filter state
  String _searchPlayer = '';
  String _searchEvent = '';
  String _searchEco = '';
  int? _filterResult; // 1: 1-0, 2: 0-1, 3: 1/2-1/2
  bool _filterComments = false;
  bool _filterVariations = false;
  bool _filterFavorite = false;
  String _sort = 'date';
  bool _desc = true;

  // Selection
  final Set<int> _selectedIds = {};

  // Import background job state
  int? _activeImportJobId;
  Timer? _jobPollTimer;
  Map<String, dynamic>? _importProgress;

  @override
  void initState() {
    super.initState();
    _db = widget.database;
    _refreshList();
  }

  @override
  void dispose() {
    _jobPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshList() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _selectedIds.clear();
    });

    final filter = _buildFilter();
    try {
      final count = await ChessCrackCore.instance.countGames(_db.id, filter);
      final rows = await ChessCrackCore.instance.searchGames(
        dbId: _db.id,
        filter: filter,
        sort: _sort,
        desc: _desc,
        offset: 0,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _totalCount = count;
          _games = rows.map((e) => GameSummary.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading games: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _games.length >= _totalCount) return;
    setState(() => _isLoading = true);

    final nextPage = _page + 1;
    final filter = _buildFilter();

    try {
      final rows = await ChessCrackCore.instance.searchGames(
        dbId: _db.id,
        filter: filter,
        sort: _sort,
        desc: _desc,
        offset: nextPage * _pageSize,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _page = nextPage;
          _games.addAll(rows.map((e) => GameSummary.fromJson(e)));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _buildFilter() {
    final f = <String, dynamic>{};
    if (_searchPlayer.trim().isNotEmpty) f['player'] = _searchPlayer.trim();
    if (_searchEvent.trim().isNotEmpty) f['event'] = _searchEvent.trim();
    if (_searchEco.trim().isNotEmpty) f['eco'] = _searchEco.trim();
    if (_filterResult != null) f['results'] = [_filterResult];
    if (_filterComments) f['hasComments'] = true;
    if (_filterVariations) f['hasVariations'] = true;
    if (_filterFavorite) f['favorite'] = true;
    return f;
  }

  Future<void> _importPgnFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pgn', 'txt'],
    );
    if (result == null || result.files.single.path == null) return;
    final filePath = result.files.single.path!;

    final jobId = await ChessCrackCore.instance.startImport(
      dbId: _db.id,
      filePath: filePath,
      batchSize: 1000,
      indexMode: _db.indexMode,
    );

    setState(() {
      _activeImportJobId = jobId;
    });

    _jobPollTimer?.cancel();
    _jobPollTimer = Timer.periodic(const Duration(milliseconds: 200), (t) async {
      final st = ChessCrackCore.instance.pollJobStatus(jobId);
      if (!mounted) {
        t.cancel();
        return;
      }

      setState(() {
        _importProgress = st;
      });

      final state = st['state'] as String? ?? 'running';
      if (state == 'done' || state == 'cancelled' || state == 'failed') {
        t.cancel();
        setState(() {
          _activeImportJobId = null;
        });
        widget.onDatabaseModified?.call();
        _refreshList();

        if (state == 'done') {
          final summary = st['summary'] as Map?;
          final imported = summary?['imported'] ?? 0;
          final dups = summary?['duplicates'] ?? 0;
          final invalid = summary?['invalid'] ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import complete: $imported imported, $dups duplicates, $invalid invalid'),
              backgroundColor: const Color(0xFF00D2BE),
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (state == 'failed') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: ${st['error']}'), backgroundColor: Colors.redAccent),
          );
        }
      }
    });
  }

  Future<void> _openGame(GameSummary game) async {
    try {
      final pgn = await ChessCrackCore.instance.getGamePgn(game.id);
      if (!mounted) return;
      if (widget.onOpenGameInAnalysis != null) {
        widget.onOpenGameInAnalysis!(pgn, '${game.white} vs ${game.black}');
        if (!mounted) return;
        Navigator.of(context).pop(); // Back to library/analysis
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded ${game.white} vs ${game.black}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load game: $e')),
      );
    }
  }

  Future<void> _toggleFavorite(GameSummary game) async {
    final nextFav = !game.favorite;
    await ChessCrackCore.instance.setFavorite(game.id, nextFav);
    setState(() {
      final idx = _games.indexWhere((g) => g.id == game.id);
      if (idx != -1) {
        _games[idx] = GameSummary(
          id: game.id,
          white: game.white,
          black: game.black,
          whiteElo: game.whiteElo,
          blackElo: game.blackElo,
          result: game.result,
          event: game.event,
          site: game.site,
          date: game.date,
          round: game.round,
          eco: game.eco,
          opening: game.opening,
          variation: game.variation,
          plyCount: game.plyCount,
          flags: game.flags,
          favorite: nextFav,
        );
      }
    });
  }

  void _enterSelectionMode(int id) {
    setState(() {
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _games.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_games.map((g) => g.id));
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2124),
        title: const Text('Delete Games?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete $count selected game(s)?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final deleted = await ChessCrackCore.instance.deleteGames(_selectedIds.toList());
      if (!mounted) return;
      _clearSelection();
      widget.onDatabaseModified?.call();
      _refreshList();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully deleted $deleted game(s)'),
          backgroundColor: const Color(0xFF00D2BE),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete games: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _copyMoveSelected({required bool deleteSource}) async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final dbsRaw = await ChessCrackCore.instance.listDatabases();
    final dbs = dbsRaw.map((e) => ChessDatabase.fromJson(e)).toList();
    final otherDbs = dbs.where((d) => d.id != _db.id).toList();

    if (otherDbs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other databases available. Create another database first.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    final actionName = deleteSource ? 'Move' : 'Copy';
    final targetDb = await showDialog<ChessDatabase>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2124),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionName $count Games', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select destination database:', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.of(ctx).size.height * 0.45).clamp(140.0, 320.0),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: otherDbs.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (ctx, i) {
                    final d = otherDbs[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.folder, color: d.color),
                      title: Text(d.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text('${d.gameCount} games', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      onTap: () => Navigator.of(ctx).pop(d),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );

    if (targetDb == null || !mounted) return;

    try {
      final res = await ChessCrackCore.instance.copyGames(
        gameIds: _selectedIds.toList(),
        targetDbId: targetDb.id,
        deleteSource: deleteSource,
      );
      if (!mounted) return;
      final copied = res['copied'] ?? 0;
      final dups = res['duplicates'] ?? 0;
      _clearSelection();
      widget.onDatabaseModified?.call();
      _refreshList();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$actionName complete: $copied game(s) to "${targetDb.name}"${dups > 0 ? ' ($dups duplicates skipped)' : ''}',
          ),
          backgroundColor: const Color(0xFF00D2BE),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $actionName games: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2124),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Game Filters & Sort', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _searchPlayer = '';
                          _searchEvent = '';
                          _searchEco = '';
                          _filterResult = null;
                          _filterComments = false;
                          _filterVariations = false;
                          _filterFavorite = false;
                          _sort = 'date';
                          _desc = true;
                        });
                      },
                      child: const Text('Reset', style: TextStyle(color: Color(0xFF00D2BE))),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),

                // Player text filter
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Player (White or Black)', labelStyle: TextStyle(color: Colors.white70)),
                  controller: TextEditingController(text: _searchPlayer),
                  onChanged: (v) => _searchPlayer = v,
                ),
                const SizedBox(height: 8),

                // Event text filter
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Event / Tournament', labelStyle: TextStyle(color: Colors.white70)),
                  controller: TextEditingController(text: _searchEvent),
                  onChanged: (v) => _searchEvent = v,
                ),
                const SizedBox(height: 8),

                // ECO filter
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'ECO Code (e.g. B06, E20)', labelStyle: TextStyle(color: Colors.white70)),
                  controller: TextEditingController(text: _searchEco),
                  onChanged: (v) => _searchEco = v,
                ),
                const SizedBox(height: 16),

                // Results chips
                const Text('Result', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: _filterResult == null,
                      onSelected: (s) => setSheetState(() => _filterResult = null),
                    ),
                    ChoiceChip(
                      label: const Text('1-0 (White)'),
                      selected: _filterResult == 1,
                      onSelected: (s) => setSheetState(() => _filterResult = s ? 1 : null),
                    ),
                    ChoiceChip(
                      label: const Text('½-½ (Draw)'),
                      selected: _filterResult == 3,
                      onSelected: (s) => setSheetState(() => _filterResult = s ? 3 : null),
                    ),
                    ChoiceChip(
                      label: const Text('0-1 (Black)'),
                      selected: _filterResult == 2,
                      onSelected: (s) => setSheetState(() => _filterResult = s ? 2 : null),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Checkbox options
                CheckboxListTile(
                  title: const Text('Has Comments / Annotations', style: TextStyle(color: Colors.white)),
                  value: _filterComments,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF00D2BE),
                  onChanged: (v) => setSheetState(() => _filterComments = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Has Move Variations', style: TextStyle(color: Colors.white)),
                  value: _filterVariations,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF00D2BE),
                  onChanged: (v) => setSheetState(() => _filterVariations = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Favorites Only', style: TextStyle(color: Colors.white)),
                  value: _filterFavorite,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF00D2BE),
                  onChanged: (v) => setSheetState(() => _filterFavorite = v ?? false),
                ),
                const SizedBox(height: 16),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D2BE),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _refreshList();
                    },
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<int> _paletteColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFFFEB3B, // Yellow
    0xFFF44336, // Red
  ];

  Future<void> _editCurrentDatabase() async {
    final nameController = TextEditingController(text: _db.name);
    final descController = TextEditingController(text: _db.description);
    int selectedColor = _db.colorValue;
    bool isRef = _db.isReference;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1E2124),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(selectedColor).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.edit_outlined, color: Color(selectedColor), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Edit Database',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Database Name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF2C2F33),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF2C2F33),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Card Color', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paletteColors.map((c) {
                      final isSel = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: isSel ? [BoxShadow(color: Color(c).withValues(alpha: 0.6), blurRadius: 6)] : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => setDialogState(() => isRef = !isRef),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2F33),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isRef ? const Color(0xFFFFD700) : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isRef ? Icons.star : Icons.star_border,
                            color: isRef ? const Color(0xFFFFD700) : Colors.white54,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reference Database',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Use as primary reference for master game analysis & opening stats',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isRef,
                            activeThumbColor: const Color(0xFFFFD700),
                            onChanged: (v) => setDialogState(() => isRef = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(selectedColor),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (nameController.text.trim().isNotEmpty) {
                            Navigator.of(ctx).pop(true);
                          }
                        },
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      final newName = nameController.text.trim();
      final newDesc = descController.text.trim();
      if (newName != _db.name) {
        await ChessCrackCore.instance.renameDatabase(_db.id, newName);
      }
      if (selectedColor != _db.colorValue) {
        await ChessCrackCore.instance.styleDatabase(
          _db.id,
          color: selectedColor,
          icon: _db.icon,
          category: _db.category,
        );
      }
      if (isRef != _db.isReference) {
        await ChessCrackCore.instance.setReferenceDatabase(isRef ? _db.id : null);
      }
      setState(() {
        _db = ChessDatabase(
          id: _db.id,
          name: newName,
          description: newDesc,
          category: _db.category,
          colorValue: selectedColor,
          icon: _db.icon,
          gameCount: _totalCount,
          indexMode: _db.indexMode,
          createdAt: _db.createdAt,
          updatedAt: DateTime.now(),
          isReference: isRef,
        );
      });
      widget.onDatabaseModified?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated database "$newName"'), backgroundColor: const Color(0xFF00D2BE)),
        );
      }
    }
  }

  Future<void> _toggleCurrentReference() async {
    try {
      final nextRef = !_db.isReference;
      await ChessCrackCore.instance.setReferenceDatabase(nextRef ? _db.id : null);
      setState(() {
        _db = ChessDatabase(
          id: _db.id,
          name: _db.name,
          description: _db.description,
          category: _db.category,
          colorValue: _db.colorValue,
          icon: _db.icon,
          gameCount: _totalCount,
          indexMode: _db.indexMode,
          createdAt: _db.createdAt,
          updatedAt: DateTime.now(),
          isReference: nextRef,
        );
      });
      widget.onDatabaseModified?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextRef ? 'Set "${_db.name}" as Reference Database' : 'Removed "${_db.name}" from Reference Database',
            ),
            backgroundColor: const Color(0xFF00D2BE),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating reference: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _deleteCurrentDatabase() async {
    // Safety check for primary database
    if (_db.category == 'my_games' || _db.id == 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2124),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.orangeAccent, size: 24),
              SizedBox(width: 10),
              Flexible(child: Text('Protected Database', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(
            'The database "${_db.name}" is protected and cannot be deleted.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D2BE),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E2124),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Delete Database?',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to permanently delete "${_db.name}"?',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will permanently erase all $_totalCount game(s) and their move indexes. This action cannot be undone.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (_db.isReference) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFFFD700), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is your active Reference Database. Deleting it will clear the reference.',
                            style: TextStyle(color: Color(0xFFFFD700), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete Database', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF1E2124),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.redAccent),
                    ),
                    SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        'Deleting database...',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      try {
        if (_db.isReference) {
          await ChessCrackCore.instance.setReferenceDatabase(null);
        }
        await ChessCrackCore.instance.deleteDatabase(_db.id);
        widget.onDatabaseModified?.call();
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress dialog
          Navigator.of(context).pop(); // Exit game list screen back to library
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete database: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelecting = _selectedIds.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF141619),
      appBar: isSelecting
          ? AppBar(
              backgroundColor: const Color(0xFF1E2836),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Cancel selection',
                onPressed: _clearSelection,
              ),
              title: Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedIds.length == _games.length ? Icons.deselect : Icons.select_all,
                    color: Colors.white70,
                  ),
                  tooltip: _selectedIds.length == _games.length ? 'Deselect All' : 'Select All',
                  onPressed: _selectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                  tooltip: 'Copy to database',
                  onPressed: () => _copyMoveSelected(deleteSource: false),
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outlined, color: Colors.white70),
                  tooltip: 'Move to database',
                  onPressed: () => _copyMoveSelected(deleteSource: true),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete selected',
                  onPressed: _deleteSelected,
                ),
              ],
            )
          : AppBar(
              backgroundColor: const Color(0xFF1B1E22),
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _db.name,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (_db.isReference) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFD700), width: 0.8),
                          ),
                          child: const Text(
                            'REF',
                            style: TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text('$_totalCount games', style: TextStyle(color: _db.color, fontSize: 12)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white70),
                  tooltip: 'Filter & Search',
                  onPressed: _showFilterSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload_outlined, color: Color(0xFF00D2BE)),
                  tooltip: 'Import PGN',
                  onPressed: _importPgnFile,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  color: const Color(0xFF22252A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tooltip: 'Database options',
                  onSelected: (val) {
                    switch (val) {
                      case 'edit':
                        _editCurrentDatabase();
                        break;
                      case 'toggle_ref':
                        _toggleCurrentReference();
                        break;
                      case 'stats':
                        showDialog(
                          context: context,
                          builder: (ctx) => DatabaseStatsDialog(database: _db),
                        );
                        break;
                      case 'delete':
                        _deleteCurrentDatabase();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                          SizedBox(width: 10),
                          Text('Edit / Rename', style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_ref',
                      child: Row(
                        children: [
                          Icon(
                            _db.isReference ? Icons.star : Icons.star_border,
                            size: 18,
                            color: const Color(0xFFFFD700),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _db.isReference ? 'Remove Reference' : 'Set as Reference',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'stats',
                      child: Row(
                        children: [
                          Icon(Icons.analytics_outlined, size: 18, color: Colors.white70),
                          SizedBox(width: 10),
                          Text('Statistics', style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text('Delete Database', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          // Active Import Progress Indicator Banner
          if (_activeImportJobId != null && _importProgress != null) _buildImportProgressBanner(),

          // Game List / Empty state
          Expanded(
            child: _isLoading && _games.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D2BE)))
                : _games.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 54, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            const Text('No games match these filters', style: TextStyle(color: Colors.white70, fontSize: 15)),
                            const SizedBox(height: 8),
                            TextButton(onPressed: _refreshList, child: const Text('Reset & Reload')),
                          ],
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (sn) {
                          if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 200) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          itemCount: _games.length + (_games.length < _totalCount ? 1 : 0),
                          itemBuilder: (ctx, idx) {
                            if (idx >= _games.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF00D2BE), strokeWidth: 2)),
                              );
                            }
                            final g = _games[idx];
                            return _buildGameRow(g);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportProgressBanner() {
    final processed = _importProgress?['processed'] ?? 0;
    final imported = _importProgress?['imported'] ?? 0;
    final speed = (_importProgress?['gamesPerSec'] as num?)?.toDouble() ?? 0.0;
    final frac = (_importProgress?['fraction'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF00D2BE).withValues(alpha: 0.15),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Importing PGN... ($processed processed, $imported added)',
                    style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Cancel Import',
                  onPressed: () {
                    if (_activeImportJobId != null) {
                      ChessCrackCore.instance.cancelJob(_activeImportJobId!);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: frac > 0 ? frac.clamp(0.0, 1.0) : null,
              color: const Color(0xFF00D2BE),
              backgroundColor: Colors.white12,
            ),
            const SizedBox(height: 4),
            Text(
              '${speed.toStringAsFixed(0)} games/sec',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameRow(GameSummary g) {
    final isSelected = _selectedIds.contains(g.id);
    final isSelecting = _selectedIds.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF00D2BE).withValues(alpha: 0.12) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () {
          if (isSelecting) {
            _toggleSelection(g.id);
          } else {
            _openGame(g);
          }
        },
        onLongPress: () {
          if (!isSelecting) {
            _enterSelectionMode(g.id);
          } else {
            _toggleSelection(g.id);
          }
        },
        leading: isSelecting
            ? Checkbox(
                value: isSelected,
                activeColor: const Color(0xFF00D2BE),
                checkColor: Colors.black,
                onChanged: (_) => _toggleSelection(g.id),
              )
            : null,
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${g.white} (${g.whiteElo ?? '?'})',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                g.result,
                style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${g.black} (${g.blackElo ?? '?'})',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (g.eco != null) ...[
                  Text(g.eco!, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w600)),
                  const Text(' • ', style: TextStyle(color: Colors.white24, fontSize: 11)),
                ],
                Text(g.year.isNotEmpty ? g.year : g.date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const Text(' • ', style: TextStyle(color: Colors.white24, fontSize: 11)),
                Text('${g.moveCount} moves', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                if (g.hasComments) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.comment, size: 11, color: Colors.white54),
                ],
                if (g.hasVariations) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.alt_route, size: 11, color: Colors.white54),
                ],
              ],
            ),
          ],
        ),
        trailing: isSelecting
            ? null
            : IconButton(
                icon: Icon(
                  g.favorite ? Icons.star : Icons.star_border,
                  color: g.favorite ? const Color(0xFFFFD700) : Colors.white24,
                  size: 20,
                ),
                onPressed: () => _toggleFavorite(g),
              ),
      ),
    );
  }
}
