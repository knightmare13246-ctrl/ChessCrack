import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/nibbler_arrow_config.dart';
import '../../models/pv_continuation.dart';
import '../../utils/board_geometry.dart';

/// Dedicated CustomPainter for piece maneuvers and multi-step continuation plans.
///
/// Fully decoupled from candidate arrows. Renders sequential arrows with step badges
/// (②, ③, ④...), dashed opponent replies, and subtle trajectories.
class PieceManeuverArrowPainter extends CustomPainter {
  final PvContinuationPlan? continuationPlan;
  final bool isFlipped;
  final PieceManeuverConfig config;

  PieceManeuverArrowPainter({
    required this.continuationPlan,
    this.isFlipped = false,
    this.config = const PieceManeuverConfig(),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!config.enabled || continuationPlan == null || continuationPlan!.isEmpty) {
      return;
    }

    final geo = BoardGeometry(boardSize: size.width, isFlipped: isFlipped);
    final squareSize = geo.squareSize;

    // Only render continuation plies (plyIndex > 0) because plyIndex == 0
    // is the root move rendered separately by the candidate arrow layer.
    final continuationArrows = continuationPlan!.continuationOnly;
    if (continuationArrows.isEmpty) return;

    // LAYER 1: Continuation Shafts
    for (final arrow in continuationArrows) {
      final startCenter = geo.getSquareCenter(arrow.from);
      final endCenter = geo.getSquareCenter(arrow.to);

      final dx = endCenter.dx - startCenter.dx;
      final dy = endCenter.dy - startCenter.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < 1.0) continue;

      // Maintain mobile visibility floor for continuation lines
      final strokeWidth = math.max(2.4, squareSize * 0.065 * arrow.strokeWidthScale);
      final badgeRadius = math.max(9.0, squareSize * 0.15 * arrow.badgeScale);
      final unitX = dx / distance;
      final unitY = dy / distance;

      final arrowEndPoint = Offset(
        endCenter.dx - (unitX * (badgeRadius * 0.40)),
        endCenter.dy - (unitY * (badgeRadius * 0.40)),
      );

      final effectiveOpacity = (arrow.opacity * config.opacity).clamp(0.40, 1.0);
      final shaftColor = arrow.isOpponent ? config.opponentColor : arrow.shaftColor;

      // Dark background trace for contrast
      final borderPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..strokeWidth = strokeWidth + 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final shaftPaint = Paint()
        ..color = shaftColor.withValues(alpha: effectiveOpacity)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (arrow.isDashed) {
        _drawDashedLine(canvas, startCenter, arrowEndPoint, borderPaint);
        _drawDashedLine(canvas, startCenter, arrowEndPoint, shaftPaint);
      } else {
        canvas.drawLine(startCenter, arrowEndPoint, borderPaint);
        canvas.drawLine(startCenter, arrowEndPoint, shaftPaint);
      }
    }

    // LAYER 2: Continuation Arrowheads
    for (final arrow in continuationArrows) {
      final startCenter = geo.getSquareCenter(arrow.from);
      final endCenter = geo.getSquareCenter(arrow.to);
      final dx = endCenter.dx - startCenter.dx;
      final dy = endCenter.dy - startCenter.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < 1.0) continue;

      final badgeRadius = math.max(9.0, squareSize * 0.15 * arrow.badgeScale);
      final unitX = dx / distance;
      final unitY = dy / distance;
      final arrowEndPoint = Offset(
        endCenter.dx - (unitX * (badgeRadius * 0.40)),
        endCenter.dy - (unitY * (badgeRadius * 0.40)),
      );

      final arrowHeadLength = math.max(8.0, squareSize * 0.20 * arrow.arrowHeadScale);
      final arrowHeadWidth = math.max(9.0, squareSize * 0.22 * arrow.arrowHeadScale);
      final angle = math.atan2(dy, dx);
      final effectiveOpacity = (arrow.opacity * config.opacity).clamp(0.40, 1.0);
      final shaftColor = arrow.isOpponent ? config.opponentColor : arrow.shaftColor;

      _drawArrowHead(
        canvas: canvas,
        tip: arrowEndPoint,
        angle: angle,
        length: arrowHeadLength,
        width: arrowHeadWidth,
        color: shaftColor.withValues(alpha: effectiveOpacity),
      );
    }

    // LAYER 3: Continuation Step Sequence Badges (②, ③, ④...)
    if (config.showStepNumbers) {
      for (final arrow in continuationArrows) {
        final endCenter = geo.getSquareCenter(arrow.to);
        final badgeRadius = math.max(9.5, squareSize * 0.15 * arrow.badgeScale);
        final badgeColor = arrow.isOpponent ? config.opponentColor : arrow.badgeColor;

        _drawStepBadge(
          canvas: canvas,
          center: endCenter,
          radius: badgeRadius,
          text: arrow.stepBadgeText,
          badgeColor: badgeColor.withValues(alpha: 0.95),
          textColor: Colors.black,
          borderColor: Colors.white,
        );
      }
    }
  }

  void _drawArrowHead({
    required Canvas canvas,
    required Offset tip,
    required double angle,
    required double length,
    required double width,
    required Color color,
  }) {
    final halfWidth = width / 2.0;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final normX = -sinA;
    final normY = cosA;

    final baseCenterX = tip.dx - length * cosA;
    final baseCenterY = tip.dy - length * sinA;

    final wing1 = Offset(baseCenterX + normX * halfWidth, baseCenterY + normY * halfWidth);
    final wing2 = Offset(baseCenterX - normX * halfWidth, baseCenterY - normY * halfWidth);

    final notchX = tip.dx - (length * 0.75) * cosA;
    final notchY = tip.dy - (length * 0.75) * sinA;

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(wing1.dx, wing1.dy)
      ..lineTo(notchX, notchY)
      ..lineTo(wing2.dx, wing2.dy)
      ..close();

    final outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(headPath, outlinePaint);

    final headFillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headFillPaint);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    double dashLength = 6.0,
    double dashSpace = 4.0,
  }) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 1.0) return;

    final unitX = dx / distance;
    final unitY = dy / distance;
    double current = 0.0;

    while (current < distance) {
      final startX = p1.dx + unitX * current;
      final startY = p1.dy + unitY * current;
      final endDist = math.min(current + dashLength, distance);
      final endX = p1.dx + unitX * endDist;
      final endY = p1.dy + unitY * endDist;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      current += dashLength + dashSpace;
    }
  }

  void _drawStepBadge({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required String text,
    required Color badgeColor,
    required Color textColor,
    required Color borderColor,
  }) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(center.translate(0, 1.0), radius, shadowPaint);

    final fillPaint = Paint()
      ..color = badgeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: radius * 1.10,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2.0), center.dy - (textPainter.height / 2.0)),
    );
  }

  @override
  bool shouldRepaint(covariant PieceManeuverArrowPainter oldDelegate) {
    if (oldDelegate.isFlipped != isFlipped) return true;
    if (oldDelegate.config.enabled != config.enabled) return true;
    if (oldDelegate.config.opacity != config.opacity) return true;
    if (oldDelegate.config.depthPlies != config.depthPlies) return true;
    if (oldDelegate.config.showStepNumbers != config.showStepNumbers) return true;
    if (oldDelegate.continuationPlan != continuationPlan) return true;
    return false;
  }
}
