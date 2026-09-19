import 'package:flutter/material.dart';
import '../../models/chess_move.dart';
import '../../models/chess_position.dart';
import '../../models/draft_variation.dart';
import '../../models/engine_analysis.dart';
import '../../models/engine_settings.dart';
import '../../utils/win_rate_calculator.dart';
import 'chess_move_token.dart';

class EngineAnalysisPanel extends StatelessWidget {
  final PositionAnalysis? analysis;
  final bool isAnalyzing;
  final VoidCallback onToggleAnalysis;
  final void Function(ChessMove move) onPlayMove;
  final ChessPosition currentPosition;
  final EngineSettings? settings;

  // Interactive Draft Variation bindings
  final DraftVariation? draftVariation;
  final void Function(PvLine line, int moveIndex)? onSelectPvMove;
  final VoidCallback? onExitDraftVariation;
  final VoidCallback? onCommitDraftVariation;
  final VoidCallback? onDraftStepBackward;
  final VoidCallback? onDraftStepForward;
  final VoidCallback? onDraftGoToStart;
  final VoidCallback? onDraftGoToEnd;
  final VoidCallback? onDraftToggleAutoPlay;

  const EngineAnalysisPanel({
    super.key,
    required this.analysis,
    required this.isAnalyzing,
    required this.onToggleAnalysis,
    required this.onPlayMove,
    required this.currentPosition,
    this.settings,
    this.draftVariation,
    this.onSelectPvMove,
    this.onExitDraftVariation,
    this.onCommitDraftVariation,
    this.onDraftStepBackward,
    this.onDraftStepForward,
    this.onDraftGoToStart,
    this.onDraftGoToEnd,
    this.onDraftToggleAutoPlay,
  });

  @override
  Widget build(BuildContext context) {
    final lines = analysis?.pvLines ?? [];
    final diag = analysis?.diagnostics;
    final infoStats = settings?.infoboxStats ??
        {
          'winrate',
          'nodePct',
          'policy',
          'multipv',
          'movesLeft',
          'depth',
          'nodes',
          'nps',
          'wdl',
        };

    final headerText = analysis != null && lines.isNotEmpty
        ? analysis!.formattedHeader
        : (isAnalyzing ? 'Analyzing position...' : 'Engine paused');

    return Container(
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Engine header bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  headerText,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onToggleAnalysis,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAnalyzing ? const Color(0xFF2E7D32) : const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAnalyzing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAnalyzing ? 'Pause' : 'Analyze',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // WDL diagnostics row
          if (diag != null &&
              diag.wdl != null &&
              diag.wdl!.length >= 3 &&
              infoStats.contains('wdl')) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'WDL: ${(diag.wdl![0] / 10).toStringAsFixed(1)}% / ${(diag.wdl![1] / 10).toStringAsFixed(1)}% / ${(diag.wdl![2] / 10).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Color(0xFF00D2BE),
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Rev: #${diag.positionRevision} (${diag.backend})',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],

          // Draft Variation Playback Toolbar
          if (draftVariation != null) ...[
            const SizedBox(height: 6),
            _buildDraftToolbar(context, draftVariation!),
          ],

          const SizedBox(height: 4),
          const Divider(color: Color(0xFF222222), height: 1),
          const SizedBox(height: 4),

          // PV lines list
          Expanded(
            child: lines.isEmpty
                ? Center(
                    child: Text(
                      isAnalyzing
                          ? 'Awaiting engine evaluation...'
                          : 'Tap Analyze to start live engine evaluation',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: lines.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return _buildPvLineItem(context, line, infoStats);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftToolbar(BuildContext context, DraftVariation draft) {
    final currentIdx = draft.selectedMoveIndex;
    final totalMoves = draft.totalMoves;
    final stepText = currentIdx < 0 ? 'Start' : '${currentIdx + 1}/$totalMoves';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF132230),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF005FB8), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alt_route, size: 14, color: Color(0xFF00D2BE)),
            const SizedBox(width: 4),
            Text(
              'Draft ($stepText)',
              style: const TextStyle(
                color: Color(0xFF00D2BE),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            // [⏮ Start]
            IconButton(
              icon: const Icon(Icons.first_page, size: 17),
              color: draft.canStepBackward ? Colors.white : Colors.white24,
              onPressed: draft.canStepBackward ? onDraftGoToStart : null,
              tooltip: 'Start of Variation',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            // [◀ Prev]
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 18),
              color: draft.canStepBackward ? Colors.white : Colors.white24,
              onPressed: draft.canStepBackward ? onDraftStepBackward : null,
              tooltip: 'Previous Move',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            // [▶ Play / ⏸ Pause]
            IconButton(
              icon: Icon(
                draft.isAutoPlaying ? Icons.pause : Icons.play_arrow,
                size: 17,
              ),
              color: const Color(0xFF00D2BE),
              onPressed: onDraftToggleAutoPlay,
              tooltip: draft.isAutoPlaying ? 'Pause Auto-play' : 'Auto-play Variation',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            // [▶ Next]
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              color: draft.canStepForward ? Colors.white : Colors.white24,
              onPressed: draft.canStepForward ? onDraftStepForward : null,
              tooltip: 'Next Move',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            // [⏭ End]
            IconButton(
              icon: const Icon(Icons.last_page, size: 17),
              color: draft.canStepForward ? Colors.white : Colors.white24,
              onPressed: draft.canStepForward ? onDraftGoToEnd : null,
              tooltip: 'End of Variation',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            const SizedBox(width: 4),
            // [➕ Add to Game]
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 12),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005FB8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              onPressed: onCommitDraftVariation,
            ),
            const SizedBox(width: 2),
            // [✖ Exit]
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.white70),
              onPressed: onExitDraftVariation,
              tooltip: 'Exit Variation',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPvLineItem(
    BuildContext context,
    PvLine line,
    Set<String> infoStats,
  ) {
    final scoreColor = Color(WinRateCalculator.getArrowColorValue(line.winPercentage));
    final metrics = _formatLineMetrics(line, infoStats);
    final pvMoves = line.pvMoves;

    final isLineInDraft = draftVariation != null && draftVariation!.pvLine.multipv == line.multipv;

    final widgets = <Widget>[];

    // MultiPV Rank Badge
    if (infoStats.contains('multipv')) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: Text(
            '#${line.multipv}',
            style: const TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 10.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
      );
    }

    // Formatted score
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: Text(
          line.formattedScore,
          style: TextStyle(
            color: scoreColor,
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );

    // Interactive Move Tokens
    if (pvMoves.isNotEmpty) {
      for (int i = 0; i < pvMoves.length; i++) {
        final item = pvMoves[i];
        final isSelected = isLineInDraft && draftVariation!.selectedMoveIndex == i;

        // Prefix formatting:
        // First move in PV: if White "12. ", if Black "12... "
        // Subsequent moves: if White "13. ", if Black ""
        String prefix = '';
        if (i == 0) {
          prefix = item.isWhite ? '${item.moveNumber}. ' : '${item.moveNumber}... ';
        } else if (item.isWhite) {
          prefix = '${item.moveNumber}. ';
        }

        widgets.add(
          ChessMoveToken(
            prefix: prefix,
            text: item.figurineSan,
            isSelected: isSelected,
            isVariation: line.multipv > 1,
            onTap: () {
              if (onSelectPvMove != null) {
                onSelectPvMove!(line, i);
              } else {
                onPlayMove(item.move);
              }
            },
          ),
        );
      }
    } else {
      // Fallback for UCI strings if pvMoves is empty
      for (int i = 0; i < line.movesUci.length; i++) {
        final uci = line.movesUci[i];
        widgets.add(
          ChessMoveToken(
            text: uci,
            isSelected: false,
            onTap: () {
              final move = currentPosition.findLegalMoveByUci(uci);
              if (move != null) onPlayMove(move);
            },
          ),
        );
      }
    }

    // Line Metrics (N, P, depth, nodes, etc.)
    if (metrics.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            '($metrics)',
            style: const TextStyle(
              color: Color(0xFF6E7681),
              fontSize: 10.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2.0,
        runSpacing: 3.0,
        children: widgets,
      ),
    );
  }

  String _formatLineMetrics(PvLine line, Set<String> enabledStats) {
    final parts = <String>[];

    if (enabledStats.contains('nodePct') && line.visitPercentage != null) {
      parts.add('N: ${line.visitPercentage!.toStringAsFixed(1)}%');
    }
    if (enabledStats.contains('policy') && line.policyPercentage != null) {
      parts.add('P: ${line.policyPercentage!.toStringAsFixed(1)}%');
    }
    if (enabledStats.contains('movesLeft') && line.movesLeft != null) {
      parts.add('M: ${line.movesLeft!.toStringAsFixed(0)}');
    }
    if (enabledStats.contains('depth') && line.depth > 0) {
      parts.add('d: ${line.depth}');
    }
    if (enabledStats.contains('nodes') && line.nodes > 0) {
      parts.add('nodes: ${line.nodes}');
    }
    if (enabledStats.contains('nps') && line.nps > 0) {
      parts.add('${(line.nps / 1000).toStringAsFixed(0)}k nps');
    }

    return parts.join(', ');
  }
}
