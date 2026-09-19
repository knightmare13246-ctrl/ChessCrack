import 'chess_move.dart';
import 'chess_position.dart';
import 'engine_analysis.dart';

/// Represents an isolated, non-destructive engine PV line or variation being browsed.
/// Tapping moves in the PV line updates this draft state and displays the position on
/// the chessboard without mutating the permanent [GameTree] or active engine search state.
class DraftVariation {
  final String startFen;
  final ChessPosition rootPosition;
  final PvLine pvLine;
  final int selectedMoveIndex; // -1 = at root position (before any PV moves)
  final bool isAutoPlaying;

  const DraftVariation({
    required this.startFen,
    required this.rootPosition,
    required this.pvLine,
    this.selectedMoveIndex = 0,
    this.isAutoPlaying = false,
  });

  /// The board position currently displayed on the chessboard.
  /// O(1) instantaneous lookup from precomputed snapshots.
  ChessPosition get currentPosition {
    if (selectedMoveIndex < 0 || pvLine.pvMoves.isEmpty) {
      return rootPosition;
    }
    final safeIdx = selectedMoveIndex.clamp(0, pvLine.pvMoves.length - 1);
    return pvLine.pvMoves[safeIdx].positionAfter;
  }

  /// The chess move corresponding to the currently selected PV step, or null if at root.
  ChessMove? get currentMove {
    if (selectedMoveIndex < 0 || pvLine.pvMoves.isEmpty) {
      return null;
    }
    final safeIdx = selectedMoveIndex.clamp(0, pvLine.pvMoves.length - 1);
    return pvLine.pvMoves[safeIdx].move;
  }

  /// The full metadata item for the currently selected move.
  PvMoveItem? get currentMoveItem {
    if (selectedMoveIndex < 0 || pvLine.pvMoves.isEmpty) {
      return null;
    }
    final safeIdx = selectedMoveIndex.clamp(0, pvLine.pvMoves.length - 1);
    return pvLine.pvMoves[safeIdx];
  }

  bool get canStepBackward => selectedMoveIndex >= 0;
  bool get canStepForward => selectedMoveIndex < pvLine.pvMoves.length - 1;
  int get totalMoves => pvLine.pvMoves.length;

  /// Returns a new [DraftVariation] at [index] (-1 to totalMoves - 1).
  DraftVariation stepTo(int index) {
    final maxIdx = pvLine.pvMoves.isEmpty ? -1 : pvLine.pvMoves.length - 1;
    final clamped = index.clamp(-1, maxIdx);
    return DraftVariation(
      startFen: startFen,
      rootPosition: rootPosition,
      pvLine: pvLine,
      selectedMoveIndex: clamped,
      isAutoPlaying: isAutoPlaying,
    );
  }

  DraftVariation stepBackward() => stepTo(selectedMoveIndex - 1);
  DraftVariation stepForward() => stepTo(selectedMoveIndex + 1);
  DraftVariation goToStart() => stepTo(-1);
  DraftVariation goToEnd() => stepTo(pvLine.pvMoves.length - 1);

  DraftVariation withAutoPlaying(bool playing) {
    return DraftVariation(
      startFen: startFen,
      rootPosition: rootPosition,
      pvLine: pvLine,
      selectedMoveIndex: selectedMoveIndex,
      isAutoPlaying: playing,
    );
  }
}
