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
  late int _multiPv;
  late bool _showPvContinuation;
  late int _pvContinuationDepth;
  late PvContinuationFilter _pvContinuationFilter;

  @override
  void initState() {
    super.initState();
    _selectedArrowhead = widget.settings.arrowheadType;
    _selectedFilterLc0 = widget.settings.arrowFilterLc0;
    _selectedFilterOthers = widget.settings.arrowFilterOthers;
    _infoboxStats = Set.from(widget.settings.infoboxStats);
    _multiPv = widget.settings.multiPv;
    _showPvContinuation = widget.settings.showPvContinuation;
    _pvContinuationDepth = widget.settings.pvContinuationDepth;
    _pvContinuationFilter = widget.settings.pvContinuationFilter;
  }

  void _notifyChange() {
    final updated = widget.settings.copyWith(
      arrowheadType: _selectedArrowhead,
      arrowFilterLc0: _selectedFilterLc0,
      arrowFilterOthers: _selectedFilterOthers,
      infoboxStats: _infoboxStats,
      multiPv: _multiPv,
      showPvContinuation: _showPvContinuation,
      pvContinuationDepth: _pvContinuationDepth,
      pvContinuationFilter: _pvContinuationFilter,
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
                  onPressed: () {
                _notifyChange();
                Navigator.of(context).pop();
              },
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
                  // Section 1: Arrow Quantity (MultiPV)
                  _buildSectionHeader('ARROW QUANTITY (MULTIPV LINES)'),
                  const SizedBox(height: 6),
                  Material(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text('Candidate Moves / Arrows:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Text('$_multiPv', style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Direct 1-tap buttons for 1, 2, 3, 4, 5
                          Row(
                            children: [1, 2, 3, 4, 5].map((pv) {
                              final isSel = _multiPv == pv;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _multiPv = pv;
                                      });
                                      _notifyChange();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 7),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSel ? const Color(0xFF00D2BE) : const Color(0xFF262626),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSel ? const Color(0xFF00D2BE) : const Color(0xFF444444),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        '$pv',
                                        style: TextStyle(
                                          color: isSel ? Colors.black : Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                          Slider(
                            value: _multiPv.toDouble().clamp(1.0, 10.0),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            activeColor: const Color(0xFF00D2BE),
                            inactiveColor: Colors.white24,
                            onChanged: (val) {
                              setState(() {
                                _multiPv = val.round();
                              });
                              _notifyChange();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 1.5: PV Continuation & Maneuver Plan
                  _buildSectionHeader('PV CONTINUATION & MANEUVER PLAN (ENGINE IDEA)'),
                  const SizedBox(height: 6),
                  Material(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Show Multi-Step Plan / Idea Arrows',
                              style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Visualizes future engine PV moves as an idea / maneuver chain with step numbers',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            value: _showPvContinuation,
                            activeColor: const Color(0xFF00D2BE),
                            onChanged: (val) {
                              setState(() => _showPvContinuation = val);
                              _notifyChange();
                            },
                          ),
                          if (_showPvContinuation) ...[
                            const Divider(color: Colors.white12),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text('Continuation Depth (Plies):', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 8),
                                Text('$_pvContinuationDepth plies', style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [2, 4, 6, 8].map((depth) {
                                final isSel = _pvContinuationDepth == depth;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        setState(() => _pvContinuationDepth = depth);
                                        _notifyChange();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 7),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSel ? const Color(0xFF00D2BE) : const Color(0xFF262626),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSel ? const Color(0xFF00D2BE) : const Color(0xFF444444),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Text(
                                          '$depth plies',
                                          style: TextStyle(
                                            color: isSel ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11.5,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 4),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Plan Display Scope:', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 6),
                          ...PvContinuationFilter.values.map((f) {
                            final isSel = _pvContinuationFilter == f;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.5),
                              child: Material(
                                color: isSel ? const Color(0xFF003830) : const Color(0xFF262626),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(
                                    color: isSel ? const Color(0xFF00D2BE) : Colors.white10,
                                  ),
                                ),
                                child: RadioListTile<PvContinuationFilter>(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  value: f,
                                  groupValue: _pvContinuationFilter,
                                  activeColor: const Color(0xFF00D2BE),
                                  title: Text(f.label, style: TextStyle(color: isSel ? const Color(0xFF00D2BE) : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  subtitle: Text(f.description, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _pvContinuationFilter = val);
                                      _notifyChange();
                                    }
                                  },
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),

                  const SizedBox(height: 16),

                  // Section 2: Arrowhead Type
                  _buildSectionHeader('ARROWHEAD TYPE (BADGE DISPLAY)'),
                  const SizedBox(height: 6),
                  ...ArrowheadType.values.map((type) {
                    final isSelected = _selectedArrowhead == type;
                    final isAvailable = !((type == ArrowheadType.policy || type == ArrowheadType.nodePct) && !isLc0);

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

              // Section 3: Arrow Filter
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
              onPressed: () {
                _notifyChange();
                Navigator.of(context).pop();
              },
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
