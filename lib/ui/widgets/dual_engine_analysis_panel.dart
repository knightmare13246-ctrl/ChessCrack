import 'package:flutter/material.dart';
import '../../models/chess_move.dart';
import '../../models/chess_position.dart';
import '../../models/maia_dual_analysis.dart';
import 'moves_by_rating_chart.dart';

/// Side-by-side Dual Engine Analysis Panel modeled after the Maia Chess platform:
/// - Left Column: Real Maia Human Move Predictions (probabilities % + blue theme)
/// - Right Column: Real Stockfish Engine Evaluation (centipawns/mate score + green theme)
/// - Bottom Section: Interactive "Moves by Rating" chart across Elo brackets
class DualEngineAnalysisPanel extends StatelessWidget {
  final DualEngineAnalysisState state;
  final VoidCallback onToggleMaia;
  final VoidCallback onToggleStockfish;
  final void Function(ChessMove move) onPlayMove;
  final ChessPosition currentPosition;
  final ValueChanged<int>? onSelectMaiaRating;
  final ValueChanged<String>? onHighlightMove;
  final String? highlightedUciMove;

  const DualEngineAnalysisPanel({
    super.key,
    required this.state,
    required this.onToggleMaia,
    required this.onToggleStockfish,
    required this.onPlayMove,
    required this.currentPosition,
    this.onSelectMaiaRating,
    this.onHighlightMove,
    this.highlightedUciMove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Dual Columns: Maia (Human) | Stockfish (Engine)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT: Maia Human Move Column
                Expanded(
                  child: _buildMaiaColumn(context),
                ),
                const SizedBox(width: 8),
                // Vertical Divider
                Container(
                  width: 1,
                  color: const Color(0xFF263238),
                ),
                const SizedBox(width: 8),
                // RIGHT: Stockfish Engine Column
                Expanded(
                  child: _buildStockfishColumn(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 2. Interactive "Moves by Rating" Chart
          if (state.movesByRatingData != null && state.movesByRatingData!.curves.isNotEmpty)
            MovesByRatingChart(
              dataset: state.movesByRatingData!,
              onRatingSelected: onSelectMaiaRating,
              onMoveSelected: onHighlightMove,
              highlightedUciMove: highlightedUciMove,
            ),
        ],
      ),
    );
  }

  Widget _buildMaiaColumn(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131A22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Maia Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isMaiaAnalyzing ? const Color(0xFF29B6F6) : Colors.white24,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    state.maiaModelName.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF80D4FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onToggleMaia,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: state.isMaiaAnalyzing ? const Color(0xFF0277BD) : const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    state.isMaiaAnalyzing ? 'RUN' : 'OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Subtitle
          const Text(
            'HUMAN MOVE PREDICTION',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 4),
          const Divider(color: Color(0xFF1E3A5F), height: 1),
          const SizedBox(height: 4),

          // Maia Candidates List
          Expanded(
            child: state.maiaCandidates.isEmpty
                ? Center(
                    child: Text(
                      state.isMaiaAnalyzing ? 'Evaluating moves...' : 'Maia paused',
                      style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.maiaCandidates.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final candidate = state.maiaCandidates[index];
                      final isHighlight = highlightedUciMove == candidate.uciMove;
                      return GestureDetector(
                        onTap: () {
                          onHighlightMove?.call(candidate.uciMove);
                          final legalMove = currentPosition.findLegalMoveByUci(candidate.uciMove);
                          if (legalMove != null) {
                            onPlayMove(legalMove);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: isHighlight
                                ? const Color(0xFF0277BD).withValues(alpha: 0.3)
                                : (index == 0 ? const Color(0xFF1A2938) : Colors.transparent),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: isHighlight ? const Color(0xFF29B6F6) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '#${candidate.rank}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    candidate.sanMove.isNotEmpty ? candidate.sanMove : candidate.uciMove,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              // Probability Bar + Label
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: (candidate.probability / 100.0).clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF29B6F6),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${candidate.probability.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Color(0xFF80D4FF),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockfishColumn(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131F17),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E4627), width: 1),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stockfish Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isStockfishAnalyzing ? const Color(0xFF4CAF50) : Colors.white24,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    state.stockfishName.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFA5D6A7),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onToggleStockfish,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: state.isStockfishAnalyzing ? const Color(0xFF2E7D32) : const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    state.isStockfishAnalyzing ? 'RUN' : 'OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Telemetry status
          Text(
            state.stockfishDepth != null
                ? 'D:${state.stockfishDepth}  NPS:${state.stockfishNps != null ? _formatNps(state.stockfishNps!) : "N/A"}'
                : 'OBJECTIVE ENGINE EVALUATION',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(height: 4),
          const Divider(color: Color(0xFF1E4627), height: 1),
          const SizedBox(height: 4),

          // Stockfish Candidates List
          Expanded(
            child: state.stockfishCandidates.isEmpty
                ? Center(
                    child: Text(
                      state.isStockfishAnalyzing ? 'Calculating depth...' : 'Stockfish paused',
                      style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.stockfishCandidates.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final candidate = state.stockfishCandidates[index];
                      final isHighlight = highlightedUciMove == candidate.uciMove;
                      return GestureDetector(
                        onTap: () {
                          onHighlightMove?.call(candidate.uciMove);
                          final legalMove = currentPosition.findLegalMoveByUci(candidate.uciMove);
                          if (legalMove != null) {
                            onPlayMove(legalMove);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: isHighlight
                                ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                                : (index == 0 ? const Color(0xFF1A3320) : Colors.transparent),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: isHighlight ? const Color(0xFF4CAF50) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '#${candidate.multipv}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    candidate.sanMove.isNotEmpty ? candidate.sanMove : candidate.uciMove,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              // Evaluation score badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B4022),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  candidate.formattedScore,
                                  style: const TextStyle(
                                    color: Color(0xFFA5D6A7),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatNps(int nps) {
    if (nps >= 1000000) {
      return '${(nps / 1000000).toStringAsFixed(1)}M';
    }
    if (nps >= 1000) {
      return '${(nps / 1000).toStringAsFixed(0)}k';
    }
    return '$nps';
  }
}
