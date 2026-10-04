import 'package:flutter/material.dart';

/// A sleek, responsive control bar positioned directly below the chessboard.
///
/// Provides primary move navigation (First, Previous, Play/Pause, Next, Last)
/// and Flip Board controls right under the board so users never have to dig into tabs.
class BoardControlsBar extends StatelessWidget {
  final VoidCallback? onGoToStart;
  final VoidCallback? onStepBackward;
  final VoidCallback? onToggleAutoPlay;
  final VoidCallback? onStepForward;
  final VoidCallback? onGoToEnd;
  final VoidCallback? onFlipBoard;
  final VoidCallback? onOpenArrowSettings;
  final VoidCallback? onOpenEngineSettings;
  final VoidCallback? onTogglePlan;
  final bool canStepBackward;
  final bool canStepForward;
  final bool isAutoPlaying;
  final bool isPlanActive;

  const BoardControlsBar({
    super.key,
    this.onGoToStart,
    this.onStepBackward,
    this.onToggleAutoPlay,
    this.onStepForward,
    this.onGoToEnd,
    this.onFlipBoard,
    this.onOpenArrowSettings,
    this.onOpenEngineSettings,
    this.onTogglePlan,
    this.canStepBackward = false,
    this.canStepForward = false,
    this.isAutoPlaying = false,
    this.isPlanActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF141416),
        border: Border(
          top: BorderSide(color: Color(0xFF242426), width: 0.8),
          bottom: BorderSide(color: Color(0xFF242426), width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Go to Start of Game
          IconButton(
            icon: const Icon(Icons.first_page, size: 20),
            color: canStepBackward ? Colors.white70 : Colors.white24,
            onPressed: canStepBackward ? onGoToStart : null,
            tooltip: 'Start of game (|<)',
            style: buttonStyle,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
          ),

          // 2. Previous Move (Backward)
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 22),
            color: canStepBackward ? Colors.white : Colors.white24,
            onPressed: canStepBackward ? onStepBackward : null,
            tooltip: 'Previous move (<)',
            style: buttonStyle,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
          ),

          // 3. Play / Pause Auto-play
          IconButton(
            icon: Icon(
              isAutoPlaying ? Icons.pause : Icons.play_arrow,
              size: 20,
              color: const Color(0xFF00D2BE),
            ),
            onPressed: (canStepForward || isAutoPlaying) ? onToggleAutoPlay : null,
            tooltip: isAutoPlaying ? 'Pause auto-play (⏸)' : 'Play moves (▶)',
            style: buttonStyle,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
          ),

          // 4. Next Move (Forward)
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 22),
            color: canStepForward ? Colors.white : Colors.white24,
            onPressed: canStepForward ? onStepForward : null,
            tooltip: 'Next move (>)',
            style: buttonStyle,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
          ),

          // 5. Go to End of Line
          IconButton(
            icon: const Icon(Icons.last_page, size: 20),
            color: canStepForward ? Colors.white70 : Colors.white24,
            onPressed: canStepForward ? onGoToEnd : null,
            tooltip: 'End of line (>|)',
            style: buttonStyle,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
          ),

          // Divider
          Container(
            height: 18,
            width: 1,
            color: const Color(0xFF333333),
            margin: const EdgeInsets.symmetric(horizontal: 2),
          ),

          // 6. Flip Board
          IconButton(
            icon: const Icon(Icons.swap_vert, size: 19),
            color: Colors.white70,
            onPressed: onFlipBoard,
            tooltip: 'Flip board orientation (⇅)',
            style: buttonStyle,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
          ),
          if (onTogglePlan != null)
            IconButton(
              icon: Icon(
                Icons.alt_route,
                size: 18,
                color: isPlanActive ? const Color(0xFF00D2BE) : Colors.white38,
              ),
              onPressed: onTogglePlan,
              tooltip: isPlanActive ? 'Continuation Plan: ON (tap for hint/toggle)' : 'Continuation Plan: OFF (tap to show plan)',
              style: buttonStyle,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
            ),
          if (onOpenArrowSettings != null)
            IconButton(
              icon: const Icon(Icons.north_east, size: 18),
              color: const Color(0xFF00D2BE),
              onPressed: onOpenArrowSettings,
              tooltip: 'Candidate Arrows & MultiPV',
              style: buttonStyle,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
            ),
          if (onOpenEngineSettings != null)
            IconButton(
              icon: const Icon(Icons.tune, size: 18),
              color: Colors.white70,
              onPressed: onOpenEngineSettings,
              tooltip: 'Engine Settings & Threads',
              style: buttonStyle,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
            ),
        ],
      ),
    );
  }
}
