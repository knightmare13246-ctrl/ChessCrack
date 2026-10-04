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
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF141416),
        border: Border(
          top: BorderSide(color: Color(0xFF242426), width: 0.8),
          bottom: BorderSide(color: Color(0xFF242426), width: 0.8),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // If available width is very narrow (< 350dp), collapse secondary settings into a menu
          final useOverflowMenu = width < 350 && (onOpenArrowSettings != null || onOpenEngineSettings != null);

          Widget wrapBtn(Widget btn) => Expanded(child: btn);

          final List<Widget> children = [
            // 1. Go to Start of Game
            wrapBtn(
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                color: canStepBackward ? Colors.white70 : Colors.white24,
                onPressed: canStepBackward ? onGoToStart : null,
                tooltip: 'Start of game (|<)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            // 2. Previous Move (Backward)
            wrapBtn(
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                color: canStepBackward ? Colors.white : Colors.white24,
                onPressed: canStepBackward ? onStepBackward : null,
                tooltip: 'Previous move (<)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            // 3. Play / Pause Auto-play
            wrapBtn(
              IconButton(
                icon: Icon(
                  isAutoPlaying ? Icons.pause : Icons.play_arrow,
                  size: 20,
                  color: const Color(0xFF00D2BE),
                ),
                onPressed: (canStepForward || isAutoPlaying) ? onToggleAutoPlay : null,
                tooltip: isAutoPlaying ? 'Pause auto-play (⏸)' : 'Play moves (▶)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            // 4. Next Move (Forward)
            wrapBtn(
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                color: canStepForward ? Colors.white : Colors.white24,
                onPressed: canStepForward ? onStepForward : null,
                tooltip: 'Next move (>)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            // 5. Go to End of Line
            wrapBtn(
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                color: canStepForward ? Colors.white70 : Colors.white24,
                onPressed: canStepForward ? onGoToEnd : null,
                tooltip: 'End of line (>|)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            // Divider
            Container(
              height: 18,
              width: 1,
              color: const Color(0xFF333333),
              margin: const EdgeInsets.symmetric(horizontal: 2),
            ),

            // 6. Flip Board
            wrapBtn(
              IconButton(
                icon: const Icon(Icons.swap_vert, size: 19),
                color: Colors.white70,
                onPressed: onFlipBoard,
                tooltip: 'Flip board orientation (⇅)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ];

          // 7. Continuation Plan toggle
          if (onTogglePlan != null) {
            children.add(
              wrapBtn(
                IconButton(
                  icon: Icon(
                    Icons.alt_route,
                    size: 18,
                    color: isPlanActive ? const Color(0xFF00D2BE) : Colors.white38,
                  ),
                  onPressed: onTogglePlan,
                  tooltip: isPlanActive
                      ? 'Continuation Plan: ON (tap for hint/toggle)'
                      : 'Continuation Plan: OFF (tap to show plan)',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            );
          }

          if (useOverflowMenu) {
            // Secondary settings collapsed into an overflow menu on tight screens
            children.add(
              wrapBtn(
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 19, color: Colors.white70),
                  tooltip: 'More Controls',
                  color: const Color(0xFF222226),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    if (val == 'arrows') onOpenArrowSettings?.call();
                    if (val == 'engine') onOpenEngineSettings?.call();
                  },
                  itemBuilder: (context) => [
                    if (onOpenArrowSettings != null)
                      const PopupMenuItem(
                        value: 'arrows',
                        child: Row(
                          children: [
                            Icon(Icons.north_east, size: 18, color: Color(0xFF00D2BE)),
                            SizedBox(width: 8),
                            Text('Candidate Arrows & MultiPV', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    if (onOpenEngineSettings != null)
                      const PopupMenuItem(
                        value: 'engine',
                        child: Row(
                          children: [
                            Icon(Icons.tune, size: 18, color: Colors.white70),
                            SizedBox(width: 8),
                            Text('Engine Settings & Threads', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          } else {
            // 8. Arrow Settings
            if (onOpenArrowSettings != null) {
              children.add(
                wrapBtn(
                  IconButton(
                    icon: const Icon(Icons.north_east, size: 18),
                    color: const Color(0xFF00D2BE),
                    onPressed: onOpenArrowSettings,
                    tooltip: 'Candidate Arrows & MultiPV',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              );
            }
            // 9. Engine Settings
            if (onOpenEngineSettings != null) {
              children.add(
                wrapBtn(
                  IconButton(
                    icon: const Icon(Icons.tune, size: 18),
                    color: Colors.white70,
                    onPressed: onOpenEngineSettings,
                    tooltip: 'Engine Settings & Threads',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              );
            }
          }

          return Row(
            children: children,
          );
        },
      ),
    );
  }
}
