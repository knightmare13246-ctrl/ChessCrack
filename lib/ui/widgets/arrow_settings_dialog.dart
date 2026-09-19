// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../models/engine_analysis.dart';
import '../../models/engine_settings.dart';

class ArrowSettingsDialog extends StatefulWidget {
  final EngineSettings settings;
  final ValueChanged<EngineSettings> onSettingsChanged;

  const ArrowSettingsDialog({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required EngineSettings settings,
    required ValueChanged<EngineSettings> onSettingsChanged,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ArrowSettingsDialog(
        settings: settings,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  State<ArrowSettingsDialog> createState() => _ArrowSettingsDialogState();
}

class _ArrowSettingsDialogState extends State<ArrowSettingsDialog> {
  late ArrowheadType _selectedArrowhead;
  late ArrowFilterLc0 _selectedFilterLc0;
  late ArrowFilterOthers _selectedFilterOthers;
  late Set<String> _infoboxStats;

  @override
  void initState() {
    super.initState();
    _selectedArrowhead = widget.settings.arrowheadType;
    _selectedFilterLc0 = widget.settings.arrowFilterLc0;
    _selectedFilterOthers = widget.settings.arrowFilterOthers;
    _infoboxStats = Set.from(widget.settings.infoboxStats);
  }

  void _notifyChange() {
    final updated = widget.settings.copyWith(
      arrowheadType: _selectedArrowhead,
      arrowFilterLc0: _selectedFilterLc0,
      arrowFilterOthers: _selectedFilterOthers,
      infoboxStats: _infoboxStats,
    );
    widget.onSettingsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isLc0 = widget.settings.activeEngine == EngineType.lc0;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Arrow & Telemetry Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Changes update the chessboard and analysis panel live without restarting the engine.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  // Section 1: Arrowhead Type
                  _buildSectionHeader('ARROWHEAD TYPE (BADGE DISPLAY)'),
              const SizedBox(height: 6),
              ...ArrowheadType.values.map((type) {
                final isSelected = _selectedArrowhead == type;
                final isAvailable = !((type == ArrowheadType.policy) && !isLc0);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Material(
                    color: isSelected ? const Color(0xFF003830) : const Color(0xFF222222),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF00D2BE) : Colors.white10,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      dense: true,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              type.label,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF00D2BE) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (!isAvailable) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.redAccent, width: 0.8),
                              ),
                              child: const Text(
                                'N/A on Stockfish',
                                style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        type.description,
                        style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                      ),
                      trailing: Radio<ArrowheadType>(
                        value: type,
                        groupValue: _selectedArrowhead,
                        activeColor: const Color(0xFF00D2BE),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedArrowhead = val);
                            _notifyChange();
                          }
                        },
                      ),
                      onTap: () {
                        setState(() => _selectedArrowhead = type);
                        _notifyChange();
                      },
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // Section 2: Arrow Filter
              _buildSectionHeader(
                isLc0 ? 'ARROW FILTER (Lc0 NEURAL CANDIDATES)' : 'ARROW FILTER (TRADITIONAL ENGINE)',
              ),
              const SizedBox(height: 6),

              if (isLc0) ...[
                ...ArrowFilterLc0.values.map((filter) {
                  final isSelected = _selectedFilterLc0 == filter;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Material(
                      color: isSelected ? const Color(0xFF003830) : const Color(0xFF222222),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF00D2BE) : Colors.white10,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RadioListTile<ArrowFilterLc0>(
                        dense: true,
                        value: filter,
                        groupValue: _selectedFilterLc0,
                        activeColor: const Color(0xFF00D2BE),
                        title: Text(
                          filter.label,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF00D2BE) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          filter.description,
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedFilterLc0 = val);
                            _notifyChange();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ] else ...[
                ...ArrowFilterOthers.values.map((filter) {
                  final isSelected = _selectedFilterOthers == filter;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Material(
                      color: isSelected ? const Color(0xFF003830) : const Color(0xFF222222),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF00D2BE) : Colors.white10,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RadioListTile<ArrowFilterOthers>(
                        dense: true,
                        value: filter,
                        groupValue: _selectedFilterOthers,
                        activeColor: const Color(0xFF00D2BE),
                        title: Text(
                          filter.label,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF00D2BE) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          filter.description,
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedFilterOthers = val);
                            _notifyChange();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),

              // Section 3: Infobox Telemetry Items
              _buildSectionHeader('INFOBOX TELEMETRY STATS'),
              const SizedBox(height: 6),
              _buildStatCheckbox('winrate', 'Winrate / Expected Score (%)'),
              _buildStatCheckbox('nodePct', 'Node Visit Allocation (%)'),
              _buildStatCheckbox('policy', 'Neural Policy Prior P (%) [Lc0]'),
              _buildStatCheckbox('multipv', 'MultiPV Preference Rank (1, 2, 3...)'),
              _buildStatCheckbox('movesLeft', 'Moves Left Ahead (MLH) [Lc0]'),
              _buildStatCheckbox('wdl', 'WDL Distribution (% / % / %)'),
              _buildStatCheckbox('depth', 'Search Depth & Seldepth'),
              _buildStatCheckbox('nodes', 'Nodes Searched & Speed (NPS)'),

                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D2BE),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00D2BE),
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildStatCheckbox(String key, String label) {
    final isChecked = _infoboxStats.contains(key);
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: const Color(0xFF00D2BE),
      checkColor: Colors.black,
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      value: isChecked,
      onChanged: (val) {
        setState(() {
          if (val == true) {
            _infoboxStats.add(key);
          } else {
            _infoboxStats.remove(key);
          }
        });
        _notifyChange();
      },
    );
  }
}
