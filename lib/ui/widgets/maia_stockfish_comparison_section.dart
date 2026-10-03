import 'package:flutter/material.dart';
import '../../models/chess_move.dart';
import '../../models/chess_position.dart';
import '../../models/engine_analysis.dart';
import '../../models/maia_dual_analysis.dart';

/// A dedicated comparison widget matching the official Maia chess workbench:
/// Displays "Maia [Elo] ▾: Human Moves" alongside "SF [Ver] ▾: Engine Moves",
/// allowing side-by-side or stacked candidate evaluation with genuine percentages and eval scores.
class MaiaStockfishComparisonSection extends StatefulWidget {
  final PositionAnalysis? analysis;
  final MovesByRatingDataset? movesByRatingData;
  final int activeRating;
  final List<int> availableRatings;
  final ValueChanged<int>? onRatingChanged;
  final ValueChanged<String>? onHighlightMove;
  final void Function(ChessMove move)? onPlayMove;
  final ChessPosition currentPosition;
  final String? highlightedUciMove;
  final bool isInitiallyExpanded;

  const MaiaStockfishComparisonSection({
    super.key,
    required this.analysis,
    required this.movesByRatingData,
    required this.activeRating,
    this.availableRatings = const [
      1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2200
    ],
    this.onRatingChanged,
    this.onHighlightMove,
    this.onPlayMove,
    required this.currentPosition,
    this.highlightedUciMove,
    this.isInitiallyExpanded = true,
  });

  @override
  State<MaiaStockfishComparisonSection> createState() => _MaiaStockfishComparisonSectionState();
}

class _MaiaStockfishComparisonSectionState extends State<MaiaStockfishComparisonSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF282833), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header Bar: [📊 Analysis] + [👁️ Hide / Show]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_outlined, size: 16, color: Color(0xFFFE7F6D)),
                  SizedBox(width: 6),
                  Text(
                    'Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpanded ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isExpanded ? 'Hide' : 'Show',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isExpanded) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 380;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildMaiaColumn(context)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildEngineColumn(context)),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMaiaColumn(context),
                      const SizedBox(height: 8),
                      _buildEngineColumn(context),
                    ],
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaiaColumn(BuildContext context) {
    // Gather candidate moves from rating sweep dataset at active rating
    final dataset = widget.movesByRatingData;
    final List<_HumanCandidateItem> humanItems = [];

    if (dataset != null && dataset.curves.isNotEmpty) {
      final sortedCurves = List<MoveRatingCurve>.from(dataset.curves)
        ..sort((a, b) {
          final pa = a.probabilityAtRating(widget.activeRating) ?? 0.0;
          final pb = b.probabilityAtRating(widget.activeRating) ?? 0.0;
          return pb.compareTo(pa);
        });

      for (final curve in sortedCurves) {
        final prob = curve.probabilityAtRating(widget.activeRating) ?? 0.0;
        humanItems.add(_HumanCandidateItem(
          san: curve.sanMove.isNotEmpty ? curve.sanMove : curve.uciMove,
          uci: curve.uciMove,
          probability: prob,
          color: curve.curveColor,
        ));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF191920),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2E2E3C), width: 0.8),
      ),
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header with Maia Elo Dropdown Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Maia ${widget.activeRating}: Human Moves',
                  style: const TextStyle(
                    color: Color(0xFFFE7F6D),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<int>(
                initialValue: widget.activeRating,
                tooltip: 'Select Maia Rating',
                onSelected: (int r) => widget.onRatingChanged?.call(r),
                color: const Color(0xFF22222C),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFFFE7F6D)),
                itemBuilder: (context) {
                  return widget.availableRatings.map((rating) {
                    final isCur = rating == widget.activeRating;
                    return PopupMenuItem<int>(
                      value: rating,
                      height: 32,
                      child: Text(
                        'Maia $rating',
                        style: TextStyle(
                          color: isCur ? const Color(0xFFFE7F6D) : Colors.white,
                          fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  }).toList();
                },
              ),
            ],
          ),

          const SizedBox(height: 2),
          // Subheader: move | prob
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'move',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'prob',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF2C2C3A), height: 8),

          // Items List
          if (humanItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  dataset?.isComputing == true
                      ? 'Calculating human moves...'
                      : (dataset?.isModelInstalled == false
                          ? 'Maia model not installed'
                          : 'No candidate moves'),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            )
          else
            ...humanItems.take(5).map((item) {
              final isHighlighted = widget.highlightedUciMove == item.uci;
              return InkWell(
                onTap: () {
                  widget.onHighlightMove?.call(item.uci);
                  final move = widget.currentPosition.findLegalMoveByUci(item.uci);
                  if (move != null) widget.onPlayMove?.call(move);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? item.color.withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isHighlighted ? item.color : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            item.san,
                            style: TextStyle(
                              color: item.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${item.probability.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEngineColumn(BuildContext context) {
    final lines = widget.analysis?.pvLines ?? [];
    final depth = widget.analysis?.depth ?? (lines.isNotEmpty ? lines.first.depth : null);
    final engineName = widget.analysis?.engineName ?? 'Stockfish';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151D24),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1F3242), width: 0.8),
      ),
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header: Engine Name + Depth
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '$engineName: Engine Moves',
                  style: const TextStyle(
                    color: Color(0xFF42A5F5),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (depth != null && depth > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2A38),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'd$depth',
                    style: const TextStyle(
                      color: Color(0xFF90CAF9),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 2),
          // Subheader: move | eval
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'move',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'eval',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E3547), height: 8),

          // Engine lines
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'Awaiting engine evaluation...',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            )
          else
            ...lines.take(5).map((line) {
              final firstUci = line.primaryMoveUci ?? (line.movesUci.isNotEmpty ? line.movesUci.first : '');
              final firstSan = line.pvMoves.isNotEmpty
                  ? line.pvMoves.first.figurineSan
                  : (line.movesUci.isNotEmpty ? line.movesUci.first : '');
              final isHighlighted = widget.highlightedUciMove == firstUci;

              return InkWell(
                onTap: () {
                  if (firstUci.isNotEmpty) {
                    widget.onHighlightMove?.call(firstUci);
                    final move = widget.currentPosition.findLegalMoveByUci(firstUci);
                    if (move != null) widget.onPlayMove?.call(move);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? const Color(0xFF42A5F5).withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isHighlighted ? const Color(0xFF42A5F5) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        firstSan.isNotEmpty ? firstSan : firstUci,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3547),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          line.evaluation != null
                              ? line.evaluation!.formattedScore
                              : (line.scoreMate != null
                                  ? (line.scoreMate! > 0 ? '+M${line.scoreMate!}' : '-M${line.scoreMate!.abs()}')
                                  : (line.scoreCp != null
                                      ? '${line.scoreCp! >= 0 ? '+' : ''}${(line.scoreCp! / 100.0).toStringAsFixed(2)}'
                                      : line.formattedScore)),
                          style: const TextStyle(
                            color: Color(0xFF90CAF9),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _HumanCandidateItem {
  final String san;
  final String uci;
  final double probability;
  final Color color;

  const _HumanCandidateItem({
    required this.san,
    required this.uci,
    required this.probability,
    required this.color,
  });
}
