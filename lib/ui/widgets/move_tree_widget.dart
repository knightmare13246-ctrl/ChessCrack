import 'package:flutter/material.dart';
import '../../models/game_tree.dart';
import '../../utils/san_formatter.dart';
import 'chess_move_token.dart';

class MoveTreeWidget extends StatelessWidget {
  final GameTree gameTree;
  final void Function(GameNode node) onSelectNode;
  final VoidCallback onStepBackward;
  final VoidCallback onStepForward;
  final VoidCallback onGoToStart;
  final VoidCallback onGoToEnd;
  final VoidCallback onReturnToOriginal;

  const MoveTreeWidget({
    super.key,
    required this.gameTree,
    required this.onSelectNode,
    required this.onStepBackward,
    required this.onStepForward,
    required this.onGoToStart,
    required this.onGoToEnd,
    required this.onReturnToOriginal,
  });

  @override
  Widget build(BuildContext context) {
    final isExploringVariation = !gameTree.currentNode.isOriginalMainline;

    return Container(
      color: const Color(0xFF141414),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1C),
              border: Border(bottom: BorderSide(color: Color(0xFF2C2C2C), width: 1)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page, size: 20),
                  color: gameTree.canStepBackward() ? Colors.white : Colors.white24,
                  onPressed: gameTree.canStepBackward() ? onGoToStart : null,
                  tooltip: 'Start of game',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 22),
                  color: gameTree.canStepBackward() ? Colors.white : Colors.white24,
                  onPressed: gameTree.canStepBackward() ? onStepBackward : null,
                  tooltip: 'Previous move',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 22),
                  color: gameTree.canStepForward() ? Colors.white : Colors.white24,
                  onPressed: gameTree.canStepForward() ? onStepForward : null,
                  tooltip: 'Next move',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.last_page, size: 20),
                  color: gameTree.canStepForward() ? Colors.white : Colors.white24,
                  onPressed: gameTree.canStepForward() ? onGoToEnd : null,
                  tooltip: 'End of current line',
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                if (isExploringVariation)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007ACC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    icon: const Icon(Icons.undo, size: 14),
                    label: const Text('Return to Game'),
                    onPressed: onReturnToOriginal,
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: SelectableText.rich(
                TextSpan(
                  children: _buildMoveSpans(gameTree.root),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildMoveSpans(GameNode node) {
    final spans = <InlineSpan>[];
    _traverseMoves(node, spans);
    return spans;
  }

  void _traverseMoves(GameNode node, List<InlineSpan> spans) {
    if (!node.hasChildren) return;

    for (int i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      final isVariation = i > 0;
      final isSelected = child == gameTree.currentNode;

      if (isVariation) {
        spans.add(const TextSpan(
          text: ' (',
          style: TextStyle(color: Color(0xFF6E7681), fontFamily: 'monospace'),
        ));
      }

      if (child.isWhiteMove) {
        spans.add(TextSpan(
          text: '${child.moveNumber}. ',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ));
      } else if (isVariation || (i == 0 && child.parent?.isRoot == true)) {
        spans.add(TextSpan(
          text: '${child.moveNumber}... ',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ));
      }

      String figurineText = child.move?.san ?? child.move?.uci ?? '';
      if (child.move != null) {
        final rawSan = child.move!.san ??
            (child.parent != null
                ? SANFormatter.formatSan(child.parent!.position, child.move!)
                : child.move!.uci);
        figurineText = SANFormatter.toFigurine(
          rawSan,
          child.move!.piece.color,
          child.move!.piece.type,
          promotion: child.move!.promotion,
        );
      }

      spans.add(
        ChessMoveToken(
          text: figurineText,
          isSelected: isSelected,
          isVariation: isVariation,
          onTap: () => onSelectNode(child),
        ).toSpan(),
      );

      if (child.comment != null && child.comment!.isNotEmpty) {
        spans.add(TextSpan(
          text: ' {${child.comment}} ',
          style: const TextStyle(
            color: Color(0xFF6A9955),
            fontStyle: FontStyle.italic,
            fontSize: 11.5,
          ),
        ));
      } else {
        spans.add(const TextSpan(text: ' '));
      }

      _traverseMoves(child, spans);

      if (isVariation) {
        spans.add(const TextSpan(
          text: ') ',
          style: TextStyle(color: Color(0xFF6E7681), fontFamily: 'monospace'),
        ));
      }
    }
  }
}
