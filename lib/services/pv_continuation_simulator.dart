import 'package:flutter/material.dart';
import '../models/chess_position.dart';
import '../models/pv_continuation.dart';
import '../utils/san_formatter.dart';

/// Pure functional simulation engine for multi-step PV continuation plans.
///
/// Simulates engine PV moves ply-by-ply on cloned [ChessPosition] instances:
/// P_0 -> move_1 -> P_1 -> move_2 -> P_2 -> move_3 -> P_3 ...
///
/// Computes exact legal coordinates, SAN, and geometry outside of UI paint cycles.
/// Strictly terminates simulation if any move is illegal or unparseable.
class PvContinuationSimulator {
  /// Simulates [pvUciMoves] starting from [initialPosition] and returns a [PvContinuationPlan].
  static PvContinuationPlan simulate({
    required ChessPosition initialPosition,
    required List<String> pvUciMoves,
    int multipv = 1,
    int maxPlies = 4,
    required Color baseColor,
    PvContinuationFilter filter = PvContinuationFilter.all,
  }) {
    if (pvUciMoves.isEmpty || maxPlies <= 0) {
      return PvContinuationPlan(
        startFen: initialPosition.toFen(),
        multipv: multipv,
        arrows: const [],
      );
    }

    final arrows = <PvContinuationArrow>[];
    var currentPos = initialPosition;
    final initialTurn = initialPosition.turn;
    int displayStepIndex = 1;

    for (int ply = 0; ply < pvUciMoves.length; ply++) {
      if (arrows.length >= maxPlies && ply > 0) {
        break;
      }

      final uci = pvUciMoves[ply];
      if (uci.length < 4) break;

      final legalMove = currentPos.findLegalMoveByUci(uci);
      if (legalMove == null) {
        // PV continuation ended or encountered illegal move; terminate chain
        break;
      }

      // Generate accurate SAN for this position
      legalMove.san ??= SANFormatter.formatSan(currentPos, legalMove);

      final isOpponent = legalMove.piece.color != initialTurn;
      final shouldIncludeInPlan = (filter == PvContinuationFilter.all) || !isOpponent;

      if (shouldIncludeInPlan) {
        // Visual hierarchy based on ply distance
        final opacity = _calculateOpacity(ply);
        final strokeScale = _calculateStrokeScale(ply);
        final arrowHeadScale = _calculateArrowHeadScale(ply);
        final badgeScale = _calculateBadgeScale(ply);

        // Color and dashing:
        // Friendly moves inherit candidate baseColor (solid).
        // Opponent replies receive contrasting amber/orange tone with dashed shaft.
        final Color shaftColor = isOpponent
            ? const Color(0xFFFFB74D) // Amber accent for opponent responses
            : baseColor;

        final Color badgeColor = isOpponent
            ? const Color(0xFFF57C00) // Deep amber badge
            : baseColor;

        final bool isDashed = isOpponent;

        arrows.add(
          PvContinuationArrow(
            stepIndex: displayStepIndex,
            plyIndex: ply,
            from: legalMove.from,
            to: legalMove.to,
            uci: uci,
            san: legalMove.san!,
            pieceColor: legalMove.piece.color,
            pieceType: legalMove.piece.type,
            isOpponent: isOpponent,
            shaftColor: shaftColor,
            badgeColor: badgeColor,
            textColor: Colors.black,
            borderColor: Colors.white,
            opacity: opacity,
            strokeWidthScale: strokeScale,
            arrowHeadScale: arrowHeadScale,
            badgeScale: badgeScale,
            isDashed: isDashed,
            stepBadgeText: '$displayStepIndex',
          ),
        );

        displayStepIndex++;
      }

      // Progressively advance board state for the next ply in the chain
      currentPos = currentPos.applyMove(legalMove);
    }

    return PvContinuationPlan(
      startFen: initialPosition.toFen(),
      multipv: multipv,
      arrows: arrows,
    );
  }

  static double _calculateOpacity(int ply) {
    if (ply == 0) return 0.95;
    // Step 2 = 0.72, Step 3 = 0.56, Step 4 = 0.42, etc.
    final val = 0.76 - (ply - 1) * 0.14;
    return val.clamp(0.24, 0.95);
  }

  static double _calculateStrokeScale(int ply) {
    if (ply == 0) return 1.0;
    final val = 0.82 - (ply - 1) * 0.10;
    return val.clamp(0.40, 0.90);
  }

  static double _calculateArrowHeadScale(int ply) {
    if (ply == 0) return 1.0;
    final val = 0.82 - (ply - 1) * 0.10;
    return val.clamp(0.42, 0.90);
  }

  static double _calculateBadgeScale(int ply) {
    if (ply == 0) return 1.0;
    final val = 0.78 - (ply - 1) * 0.08;
    return val.clamp(0.48, 0.85);
  }
}
