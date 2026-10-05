import 'package:flutter/material.dart';
import '../../models/chess_database_models.dart';
import '../../services/chesscrack_core.dart';

class DatabaseStatsDialog extends StatefulWidget {
  final ChessDatabase database;

  const DatabaseStatsDialog({super.key, required this.database});

  @override
  State<DatabaseStatsDialog> createState() => _DatabaseStatsDialogState();
}

class _DatabaseStatsDialogState extends State<DatabaseStatsDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _stats;

  bool _isPerformingMaintenance = false;
  String? _maintenanceResult;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ChessCrackCore.instance.getStats(widget.database.id);
      if (mounted) {
        setState(() {
          _stats = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runIntegrityCheck() async {
    setState(() {
      _isPerformingMaintenance = true;
      _maintenanceResult = null;
    });
    try {
      final res = await ChessCrackCore.instance.checkIntegrity();
      final integrity = res['integrity'] ?? 'unknown';
      final fk = res['foreignKeyViolations'] ?? 0;
      if (mounted) {
        setState(() {
          _isPerformingMaintenance = false;
          _maintenanceResult = 'Integrity: $integrity\nFK Violations: $fk';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPerformingMaintenance = false;
          _maintenanceResult = 'Error: $e';
        });
      }
    }
  }

  Future<void> _runVacuum() async {
    setState(() {
      _isPerformingMaintenance = true;
      _maintenanceResult = null;
    });
    try {
      await ChessCrackCore.instance.vacuum();
      if (mounted) {
        setState(() {
          _isPerformingMaintenance = false;
          _maintenanceResult = 'Database vacuum completed successfully.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPerformingMaintenance = false;
          _maintenanceResult = 'Vacuum failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availH = media.size.height - media.padding.top - media.padding.bottom - media.viewInsets.bottom;
    final availW = media.size.width - media.padding.left - media.padding.right;

    final dialogHeight = (availH * 0.90).clamp(240.0, 600.0);
    final dialogWidth = (availW * 0.92).clamp(280.0, 520.0);

    return Dialog(
      backgroundColor: const Color(0xFF1B1E22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.database.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.analytics, color: widget.database.color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.database.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Database Statistics & Health',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),

              // Body
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00D2BE)),
                      )
                    : _error != null
                        ? Center(
                            child: Text(
                              'Failed to load stats:\n$_error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          )
                        : _buildStatsContent(),
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF00D2BE))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsContent() {
    final s = _stats ?? {};
    final games = (s['games'] as num?)?.toInt() ?? 0;
    final players = (s['whitePlayers'] as num?)?.toInt() ?? 0;
    final firstYear = s['firstYear'] as String?;
    final lastYear = s['lastYear'] as String?;
    final yearSpan = (firstYear != null && lastYear != null)
        ? (firstYear == lastYear ? firstYear : '$firstYear - $lastYear')
        : 'N/A';
    final avgElo = (s['avgElo'] as num?)?.toDouble();
    final annotated = (s['annotated'] as num?)?.toInt() ?? 0;
    final variations = (s['withVariations'] as num?)?.toInt() ?? 0;
    final whiteWins = (s['whiteWins'] as num?)?.toInt() ?? 0;
    final blackWins = (s['blackWins'] as num?)?.toInt() ?? 0;
    final draws = (s['draws'] as num?)?.toInt() ?? 0;

    final whitePct = games > 0 ? (whiteWins / games * 100).toStringAsFixed(1) : '0';
    final drawPct = games > 0 ? (draws / games * 100).toStringAsFixed(1) : '0';
    final blackPct = games > 0 ? (blackWins / games * 100).toStringAsFixed(1) : '0';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat grid
          Row(
            children: [
              Expanded(child: _buildMetricCard('Total Games', '$games', Icons.storage_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard('Players', '$players', Icons.people_outline)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Years', yearSpan, Icons.date_range_outlined)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Avg Rating',
                  avgElo != null && avgElo > 0 ? avgElo.toStringAsFixed(0) : 'N/A',
                  Icons.trending_up,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Text('Results Breakdown', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),

          // Result bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      if (whiteWins > 0)
                        Expanded(
                          flex: whiteWins,
                          child: Container(height: 8, color: Colors.white),
                        ),
                      if (draws > 0)
                        Expanded(
                          flex: draws,
                          child: Container(height: 8, color: Colors.grey.shade600),
                        ),
                      if (blackWins > 0)
                        Expanded(
                          flex: blackWins,
                          child: Container(height: 8, color: const Color(0xFF2C2C2E)),
                        ),
                      if (whiteWins == 0 && draws == 0 && blackWins == 0)
                        Expanded(
                          child: Container(height: 8, color: Colors.white12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text('1-0: $whiteWins ($whitePct%)', style: const TextStyle(color: Colors.white, fontSize: 10), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 4),
                    Flexible(child: Text('½-½: $draws ($drawPct%)', style: TextStyle(color: Colors.grey.shade400, fontSize: 10), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 4),
                    Flexible(child: Text('0-1: $blackWins ($blackPct%)', style: TextStyle(color: Colors.grey.shade300, fontSize: 10), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Text('Annotations & Variations', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Comments/NAGs', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text('$annotated games', style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Move Variations', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text('$variations games', style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Text('Database Maintenance', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF00D2BE)),
                  label: const Text('Integrity Check', style: TextStyle(color: Colors.white, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  ),
                  onPressed: _isPerformingMaintenance ? null : _runIntegrityCheck,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services_outlined, size: 14, color: Colors.orangeAccent),
                  label: const Text('Vacuum DB', style: TextStyle(color: Colors.white, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  ),
                  onPressed: _isPerformingMaintenance ? null : _runVacuum,
                ),
              ),
            ],
          ),

          if (_isPerformingMaintenance) ...[
            const SizedBox(height: 8),
            const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D2BE)))),
          ],

          if (_maintenanceResult != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00D2BE).withValues(alpha: 0.3)),
              ),
              child: Text(
                _maintenanceResult!,
                style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: widget.database.color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
