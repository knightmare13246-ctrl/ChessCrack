import 'package:flutter/material.dart';
import '../../models/chess_move.dart';
import '../../models/chess_position.dart';
import '../../models/draft_variation.dart';
import '../../models/engine_analysis.dart';
import '../../models/engine_settings.dart';
import '../../models/maia_dual_analysis.dart';
import '../../utils/win_rate_calculator.dart';
import 'chess_move_token.dart';
import 'maia_stockfish_comparison_section.dart';
import 'moves_by_rating_chart.dart';

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
  // Moves by Rating interactive chart bindings
  final MovesByRatingDataset? movesByRatingData;
  final ValueChanged<int>? onSelectMaiaRating;
  final ValueChanged<String>? onHighlightMove;
  final VoidCallback? onDownloadMaiaModelRequested;
  final String? highlightedUciMove;
  final VoidCallback? onOpenEngineSettings;
  final VoidCallback? onOpenArrowSettings;

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
    this.movesByRatingData,
    this.onSelectMaiaRating,
    this.onHighlightMove,
    this.onDownloadMaiaModelRequested,
    this.highlightedUciMove,
    this.onOpenEngineSettings,
    this.onOpenArrowSettings,
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

    final isMaiaActive = (settings?.isMaiaActive == true) || (analysis?.isMaia == true);

    final engineDisplayName = isMaiaActive
        ? (settings?.selectedMaiaId != null ? 'MAIA ${settings!.selectedMaiaId!.replaceAll(RegExp(r'[^0-9]'), '')}' : (analysis?.engineName?.toUpperCase() ?? 'MAIA'))
        : (settings?.activeEngine.displayName.toUpperCase() ?? (analysis?.engineName?.toUpperCase() ?? 'ENGINE'));
    final engineSubtitle = isMaiaActive ? 'Engine: Lc0' : '';

    final headerText = analysis != null && (lines.isNotEmpty || analysis!.totalNodes != null || analysis!.depth != null || analysis!.isMaia)
        ? analysis!.formattedHeader
        : (isAnalyzing ? 'Analyzing position...' : 'Tap Analyze to start engine evaluation');

    return Container(
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // 1. Engine Header Bar: Engine Identity, Status & Pause/Analyze toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Engine title + Live pulse dot + Tag
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAnalyzing
                              ? const Color(0xFF00D2BE)
                              : (analysis?.searchState == AnalysisDataState.paused
                                  ? const Color(0xFFFFB300)
                                  : Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        engineDisplayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (engineSubtitle.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2832),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFF005FB8), width: 0.6),
                          ),
                          child: Text(
                            engineSubtitle,
                            style: const TextStyle(
                              color: Color(0xFF80D4FF),
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (analysis?.searchState == AnalysisDataState.paused) ...[
                        const SizedBox(width: 6),
                        const Text(
                          'PAUSED',
                          style: TextStyle(
                            color: Color(0xFFFFB300),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onOpenArrowSettings != null)
                  IconButton(
                    icon: const Icon(Icons.north_east, color: Color(0xFF00D2BE), size: 18),
                    onPressed: onOpenArrowSettings,
                    tooltip: 'Arrow Settings',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                if (onOpenEngineSettings != null)
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white70, size: 18),
                    onPressed: onOpenEngineSettings,
                    tooltip: 'Engine Settings',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                const SizedBox(width: 4),
                // Pause / Analyze toggle button
                GestureDetector(
                  onTap: onToggleAnalysis,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isAnalyzing ? const Color(0xFF2E7D32) : const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isAnalyzing ? const Color(0xFF4CAF50) : const Color(0xFF555555),
                        width: 1,
                      ),
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

            const SizedBox(height: 5),

            // 2. Real Telemetry Bar (Never truncated with ellipsis, auto-fits width)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF242424), width: 0.8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  headerText,
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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

            // Scrollable Analysis Body: PV lines + Moves by Rating Chart
            Expanded(
              child: SingleChildScrollView(
                key: const PageStorageKey<String>('engine_analysis_scroll_body'),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Maia vs Stockfish Comparison Section (Maiachess.com workbench layout)
                    if (movesByRatingData != null) ...[
                      MaiaStockfishComparisonSection(
                        analysis: analysis,
                        movesByRatingData: movesByRatingData,
                        activeRating: movesByRatingData!.activeRating,
                        onRatingChanged: onSelectMaiaRating,
                        onHighlightMove: onHighlightMove,
                        onPlayMove: onPlayMove,
                        currentPosition: currentPosition,
                        highlightedUciMove: highlightedUciMove,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 2. Interactive Moves by Rating Chart (Maiachess.com analysis style)
                    if (movesByRatingData != null) ...[
                      RepaintBoundary(
                        child: MovesByRatingChart(
                          dataset: movesByRatingData!,
                          onRatingSelected: onSelectMaiaRating,
                          onMoveSelected: onHighlightMove,
                          onDownloadModelRequested: onDownloadMaiaModelRequested,
                          highlightedUciMove: highlightedUciMove,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 3. Engine PV lines list
                    if (lines.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            isAnalyzing
                                ? 'Awaiting engine evaluation...'
                                : 'Tap Analyze to start live engine evaluation',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      )
                    else ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          'ENGINE LINES & VARIATIONS',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      ...lines.map((line) => _buildPvLineItem(context, line, infoStats)),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF132230),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF005FB8), width: 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
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
            const SizedBox(width: 6),
            // [⏮ Start]
            IconButton(
              icon: const Icon(Icons.first_page, size: 17),
              color: draft.canStepBackward ? Colors.white : Colors.white24,
              onPressed: draft.canStepBackward ? onDraftGoToStart : null,
              tooltip: 'Start of Variation',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            ),
            // [◀ Prev]
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 18),
              color: draft.canStepBackward ? Colors.white : Colors.white24,
              onPressed: draft.canStepBackward ? onDraftStepBackward : null,
              tooltip: 'Previous Move',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
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
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            ),
            // [▶ Next]
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              color: draft.canStepForward ? Colors.white : Colors.white24,
              onPressed: draft.canStepForward ? onDraftStepForward : null,
              tooltip: 'Next Move',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            ),
            // [⏭ End]
            IconButton(
              icon: const Icon(Icons.last_page, size: 17),
              color: draft.canStepForward ? Colors.white : Colors.white24,
              onPressed: draft.canStepForward ? onDraftGoToEnd : null,
              tooltip: 'End of Variation',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            ),
            const SizedBox(width: 6),
            // [➕ Add to Game]
            GestureDetector(
              onTap: onCommitDraftVariation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF005FB8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline, size: 12, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            // [✖ Exit]
            GestureDetector(
              onTap: onExitDraftVariation,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white70),
              ),
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

    // Formatted score (Human Move Probability for Maia, CP/Mate score for Stockfish)
    final bool isMaiaLine = line.isMaia || (settings?.isMaiaActive == true);
    final String displayScore = (isMaiaLine && line.policyPercentage != null)
        ? '${line.policyPercentage!.toStringAsFixed(1)}%'
        : line.formattedScore;

    widgets.add(
      Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: Text(
          displayScore,
          style: TextStyle(
            color: isMaiaLine ? const Color(0xFF80D4FF) : scoreColor,
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
    final bool isMaia = (settings?.isMaiaActive == true) || (line.policyPercentage != null && line.nodes <= 1);

    if (enabledStats.contains('policy') && line.policyPercentage != null) {
      parts.add('P: ${line.policyPercentage!.toStringAsFixed(1)}%');
    }
    if (!isMaia && enabledStats.contains('nodePct') && line.visitPercentage != null) {
      parts.add('N: ${line.visitPercentage!.toStringAsFixed(1)}%');
    }
    if (enabledStats.contains('movesLeft') && line.movesLeft != null) {
      parts.add('M: ${line.movesLeft!.toStringAsFixed(0)}');
    }
    if (!isMaia) {
      if (enabledStats.contains('depth') && line.depth != null && line.depth! > 0) {
        parts.add('d: ${line.depth}');
      }
      if (enabledStats.contains('nodes') && line.nodes != null && line.nodes! > 0) {
        parts.add('nodes: ${line.nodes}');
      }
      if (enabledStats.contains('nps') && line.nps != null && line.nps! > 0) {
        parts.add('${(line.nps! / 1000).toStringAsFixed(0)}k nps');
      }
    }

    return parts.join(', ');
  }
}
