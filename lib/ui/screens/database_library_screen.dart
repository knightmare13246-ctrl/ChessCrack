import 'package:flutter/material.dart';
import '../../models/chess_database_models.dart';
import '../../services/chesscrack_core.dart';
import 'game_list_screen.dart';

class DatabaseLibraryScreen extends StatefulWidget {
  final void Function(String pgn, String title)? onOpenGameInAnalysis;

  const DatabaseLibraryScreen({
    super.key,
    this.onOpenGameInAnalysis,
  });

  @override
  State<DatabaseLibraryScreen> createState() => _DatabaseLibraryScreenState();
}

class _DatabaseLibraryScreenState extends State<DatabaseLibraryScreen> {
  List<ChessDatabase> _databases = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDatabases();
  }

  Future<void> _loadDatabases() async {
    setState(() => _isLoading = true);
    try {
      await ChessCrackCore.instance.init();
      final list = await ChessCrackCore.instance.listDatabases();
      if (mounted) {
        setState(() {
          _databases = list.map((e) => ChessDatabase.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load databases: $e')),
        );
      }
    }
  }

  List<ChessDatabase> get _filteredDatabases {
    if (_searchQuery.trim().isEmpty) return _databases;
    final q = _searchQuery.toLowerCase();
    return _databases.where((d) => d.name.toLowerCase().contains(q) || d.description.toLowerCase().contains(q)).toList();
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

  Future<void> _createNewDatabaseDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    int selectedColor = 0xFF4CAF50;
    const selectedIcon = 'folder';

    final created = await showDialog<bool>(
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
                        child: Icon(Icons.folder_open, color: Color(selectedColor), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Create New Database',
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
                    autofocus: true,
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
                        child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
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

    if (created == true && nameController.text.trim().isNotEmpty) {
      await ChessCrackCore.instance.createDatabase(
        name: nameController.text.trim(),
        description: descController.text.trim(),
        color: selectedColor,
        icon: selectedIcon,
      );
      _loadDatabases();
    }
  }

  Future<void> _editDatabaseDialog(ChessDatabase db) async {
    final nameController = TextEditingController(text: db.name);
    final descController = TextEditingController(text: db.description);
    int selectedColor = db.colorValue;
    bool isRef = db.isReference;

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
      if (newName != db.name) {
        await ChessCrackCore.instance.renameDatabase(db.id, newName);
      }
      if (selectedColor != db.colorValue) {
        await ChessCrackCore.instance.styleDatabase(
          db.id,
          color: selectedColor,
          icon: db.icon,
          category: db.category,
        );
      }
      if (isRef != db.isReference) {
        await ChessCrackCore.instance.setReferenceDatabase(isRef ? db.id : null);
      }
      _loadDatabases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated database "$newName"'),
            backgroundColor: const Color(0xFF00D2BE),
          ),
        );
      }
    }
  }

  Future<void> _deleteDatabaseDialog(ChessDatabase db) async {
    // Safety protection for default/primary database
    if (db.category == 'my_games' || db.id == 1 || _databases.length <= 1) {
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
            'The database "${db.name}" is protected and cannot be deleted because it is your primary workspace.',
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

    int gameCount = db.gameCount;
    try {
      gameCount = await ChessCrackCore.instance.countGames(db.id);
    } catch (_) {}
    if (!mounted) return;

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
                  'Are you sure you want to permanently delete "${db.name}"?',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will permanently erase all $gameCount game(s) and their move indexes. This action cannot be undone.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (db.isReference) ...[
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
        if (db.isReference) {
          await ChessCrackCore.instance.setReferenceDatabase(null);
        }
        await ChessCrackCore.instance.deleteDatabase(db.id);
        await _loadDatabases();
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Database "${db.name}" deleted successfully'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete database: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _toggleReference(ChessDatabase db) async {
    try {
      final nextRef = !db.isReference;
      await ChessCrackCore.instance.setReferenceDatabase(nextRef ? db.id : null);
      await _loadDatabases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextRef
                  ? 'Set "${db.name}" as Reference Database'
                  : 'Removed "${db.name}" from Reference Database',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141619),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E22),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: Color(0xFF00D2BE), size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Chess Library',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Reload',
            onPressed: _loadDatabases,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D2BE)))
          : RefreshIndicator(
              color: const Color(0xFF00D2BE),
              backgroundColor: const Color(0xFF22252A),
              onRefresh: _loadDatabases,
              child: CustomScrollView(
                slivers: [
                  // Search & Quick Action Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        children: [
                          TextField(
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Search databases...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                              filled: true,
                              fillColor: const Color(0xFF22252A),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00D2BE),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add, size: 20),
                                  label: const Text('New Database', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: _createNewDatabaseDialog,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Empty State
                  if (_filteredDatabases.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'Your Chess Library is empty' : 'No databases match "$_searchQuery"',
                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            if (_searchQuery.isEmpty)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D2BE), foregroundColor: Colors.black),
                                onPressed: _createNewDatabaseDialog,
                                child: const Text('Create Database'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Database Cards Grid / List
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, idx) {
                            final db = _filteredDatabases[idx];
                            return _buildDatabaseCard(db);
                          },
                          childCount: _filteredDatabases.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildDatabaseCard(ChessDatabase db) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2126),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: db.isReference ? const Color(0xFFFFD700).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
          width: db.isReference ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => GameListScreen(
                  database: db,
                  onOpenGameInAnalysis: widget.onOpenGameInAnalysis != null
                      ? (pgn, title) {
                          widget.onOpenGameInAnalysis!(pgn, title);
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        }
                      : null,
                  onDatabaseModified: _loadDatabases,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Colorful Left Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: db.color.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: db.color.withValues(alpha: 0.8), width: 1.5),
                  ),
                  child: Icon(Icons.folder, color: db.color, size: 24),
                ),
                const SizedBox(width: 14),

                // Database Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              db.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (db.isReference) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFD700), width: 0.8),
                              ),
                              child: const Text(
                                'REF',
                                style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${db.gameCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} games',
                            style: TextStyle(
                              color: db.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (db.description.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(color: Colors.white30, fontSize: 13)),
                            Expanded(
                              child: Text(
                                db.description,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions Popup Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white60, size: 22),
                  color: const Color(0xFF22252A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tooltip: 'Database options',
                  onSelected: (val) {
                    switch (val) {
                      case 'open':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => GameListScreen(
                              database: db,
                              onOpenGameInAnalysis: widget.onOpenGameInAnalysis != null
                                  ? (pgn, title) {
                                      widget.onOpenGameInAnalysis!(pgn, title);
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      }
                                    }
                                  : null,
                              onDatabaseModified: _loadDatabases,
                            ),
                          ),
                        );
                        break;
                      case 'edit':
                        _editDatabaseDialog(db);
                        break;
                      case 'toggle_ref':
                        _toggleReference(db);
                        break;
                      case 'delete':
                        _deleteDatabaseDialog(db);
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.folder_open, size: 18, color: Color(0xFF00D2BE)),
                          SizedBox(width: 10),
                          Text('Open Games', style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
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
                            db.isReference ? Icons.star : Icons.star_border,
                            size: 18,
                            color: const Color(0xFFFFD700),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            db.isReference ? 'Remove Reference' : 'Set as Reference',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
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
                const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
