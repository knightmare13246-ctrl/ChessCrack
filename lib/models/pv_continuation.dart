import 'dart:ui';
import 'chess_move.dart';

/// Filter mode for PV continuation plan arrows.
enum PvContinuationFilter {
  all('All Moves (Plan + Responses)', 'Shows both friendly maneuvers and opponent replies in the PV'),
  friendlyOnly('Active Side Only (Maneuver)', 'Shows only the moves of the active player to trace piece maneuvers');

  final String label;
  final String description;
  const PvContinuationFilter(this.label, this.description);
}

/// Represents a single move arrow in a multi-step engine PV continuation plan.
class PvContinuationArrow {
  final int stepIndex; // 1-based step along the displayed chain (e.g. 1, 2, 3...)
  final int plyIndex; // 0-based ply index in the raw PV (0 = root candidate move, 1 = first reply...)
  final Square from;
  final Square to;
  final String uci;
  final String san;
  final PieceColor pieceColor;
  final PieceType pieceType;
  final bool isOpponent;
  final Color shaftColor;
  final Color badgeColor;
  final Color textColor;
  final Color borderColor;
  final double opacity;
  final double strokeWidthScale;
  final double arrowHeadScale;
  final double badgeScale;
  final bool isDashed;
  final String stepBadgeText;

  const PvContinuationArrow({
    required this.stepIndex,
    required this.plyIndex,
    required this.from,
    required this.to,
    required this.uci,
    required this.san,
    required this.pieceColor,
    required this.pieceType,
    required this.isOpponent,
    required this.shaftColor,
    required this.badgeColor,
    required this.textColor,
    required this.borderColor,
    required this.opacity,
    required this.strokeWidthScale,
    required this.arrowHeadScale,
    required this.badgeScale,
    required this.isDashed,
    required this.stepBadgeText,
  });

  PvContinuationArrow copyWith({
    int? stepIndex,
    int? plyIndex,
    Square? from,
    Square? to,
    String? uci,
    String? san,
    PieceColor? pieceColor,
    PieceType? pieceType,
    bool? isOpponent,
    Color? shaftColor,
    Color? badgeColor,
    Color? textColor,
    Color? borderColor,
    double? opacity,
    double? strokeWidthScale,
    double? arrowHeadScale,
    double? badgeScale,
    bool? isDashed,
    String? stepBadgeText,
  }) {
    return PvContinuationArrow(
      stepIndex: stepIndex ?? this.stepIndex,
      plyIndex: plyIndex ?? this.plyIndex,
      from: from ?? this.from,
      to: to ?? this.to,
      uci: uci ?? this.uci,
      san: san ?? this.san,
      pieceColor: pieceColor ?? this.pieceColor,
      pieceType: pieceType ?? this.pieceType,
      isOpponent: isOpponent ?? this.isOpponent,
      shaftColor: shaftColor ?? this.shaftColor,
      badgeColor: badgeColor ?? this.badgeColor,
      textColor: textColor ?? this.textColor,
      borderColor: borderColor ?? this.borderColor,
      opacity: opacity ?? this.opacity,
      strokeWidthScale: strokeWidthScale ?? this.strokeWidthScale,
      arrowHeadScale: arrowHeadScale ?? this.arrowHeadScale,
      badgeScale: badgeScale ?? this.badgeScale,
      isDashed: isDashed ?? this.isDashed,
      stepBadgeText: stepBadgeText ?? this.stepBadgeText,
    );
  }
}

/// Immutable collection of continuation arrows representing the strategic idea / multi-step plan
/// derived strictly from the engine's real principal variation.
class PvContinuationPlan {
  final String startFen;
  final int multipv; // MultiPV rank (1, 2, 3...)
  final List<PvContinuationArrow> arrows;

  const PvContinuationPlan({
    required this.startFen,
    required this.multipv,
    required this.arrows,
  });

  static const PvContinuationPlan empty = PvContinuationPlan(
    startFen: '',
    multipv: 1,
    arrows: [],
  );

  bool get isEmpty => arrows.isEmpty;
  bool get isNotEmpty => arrows.isNotEmpty;
  int get length => arrows.length;

  /// Returns arrows excluding the initial root candidate move (ply 0),
  /// since the root candidate move is already painted by the primary candidate arrow.
  List<PvContinuationArrow> get continuationOnly =>
      arrows.where((a) => a.plyIndex > 0).toList();
}
