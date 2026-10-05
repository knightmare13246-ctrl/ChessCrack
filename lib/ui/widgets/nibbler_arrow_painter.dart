import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/chess_position.dart';
import '../../models/engine_analysis.dart';
import '../../models/nibbler_arrow_config.dart';
import '../../utils/board_geometry.dart';
import '../../utils/nibbler_badge_layout_engine.dart';
import '../../utils/win_rate_calculator.dart';

/// Dedicated CustomPainter strictly for Nibbler Candidate Arrows (Engine MultiPV).
///
/// Features:
/// - Thin-to-medium curved shafts (quadratic Bézier with deterministic signed curvature)
/// - Deterministic curve separation preventing arrow overlap across ranks
/// - Perceptual visibility floor ensuring lower-ranked arrows (PV2, PV3, PV4) remain clear on mobile screens
/// - Nibbler-style arrowhead notch geometry with high-contrast outlines
/// - Non-obscuring score badges anchored back along the shaft so the arrowhead tip and notch are 100% visible
/// - Strict isolation: never mixes with maneuver plans or user interaction arrows
class NibblerArrowPainter extends CustomPainter {
  final List<CandidateArrow> candidateArrows;
  final List<PvLine> pvLines;
  final ChessPosition position;
  final int positionRevision;
  final int? analysisRequestId;
  final bool isFlipped;
  final ArrowheadType arrowheadType;
  final EngineType engineType;
  final NibblerCandidateArrowConfig config;

  // Backward compatibility convenience fields
  final PvContinuationPlan? continuationPlan;
  final bool showPvContinuation;
  final int? selectedPvIndex;

  NibblerArrowPainter({
    List<CandidateArrow>? candidateArrows,
    this.pvLines = const [],
    required this.position,
    required this.positionRevision,
    this.analysisRequestId,
    this.isFlipped = false,
    this.arrowheadType = ArrowheadType.winrate,
    this.engineType = EngineType.lc0,
    this.config = const NibblerCandidateArrowConfig(),
    this.continuationPlan,
    this.showPvContinuation = false,
    this.selectedPvIndex,
  }) : candidateArrows = candidateArrows ?? _fromPvLines(pvLines, positionRevision, analysisRequestId, position);

  static List<CandidateArrow> _fromPvLines(
    List<PvLine> lines,
    int revision,
    int? reqId, [
    ChessPosition? startPosition,
  ]) {
    final list = <CandidateArrow>[];
    for (final line in lines) {
      final from = line.fromSquare;
      final to = line.toSquare;
      final uci = line.primaryMoveUci;
      if (from == null || to == null || uci == null) continue;

      final rank = line.multipv;
      final isMaia = line.isMaia;
      final baseColor = isMaia
          ? (rank == 1
              ? const Color(0xFF29B6F6)
              : (rank == 2
                  ? const Color(0xFF0288D1)
                  : (rank == 3
                      ? const Color(0xFF01579B)
                      : const Color(0xFF5C6BC0))))
          : (rank == 1
              ? Color(WinRateCalculator.getArrowColorValue(line.expectedScore))
              : (rank == 2
                  ? const Color(0xFF4CAF50)
                  : (rank == 3
                      ? const Color(0xFF81C784)
                      : const Color(0xFFA5D6A7))));

      list.add(CandidateArrow(
        rank: rank,
        uciMove: uci,
        from: from,
        to: to,
        pvUci: line.movesUci,
        pvSan: line.movesSan,
        winProbability: line.winPercentage,
        expectedScore: line.expectedScore,
        scoreCp: line.scoreCp,
        scoreMate: line.scoreMate,
        visits: line.nodes,
        nodePercentage: line.visitPercentage,
        policyPercentage: line.policyPercentage,
        movesLeft: line.movesLeft,
        depth: line.depth,
        positionRevision: line.positionRevision != 0 ? line.positionRevision : revision,
        requestId: line.analysisRequestId != 0 ? line.analysisRequestId : (reqId ?? 0),
        style: ArrowVisualStyle(
          shaftColor: baseColor,
          badgeColor: baseColor,
          textColor: isMaia ? Colors.white : const Color(0xFF111111),
          borderColor: rank == 1 ? Colors.white : Colors.black87,
          opacity: rank == 1 ? 0.98 : 0.88,
          strokeWidthScale: rank == 1 ? 1.15 : 0.92,
          arrowHeadScale: rank == 1 ? 1.15 : 0.92,
          badgeScale: rank == 1 ? 1.05 : 0.95,
        ),
      ));
    }
    return list;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (candidateArrows.isEmpty) return;

    final geo = BoardGeometry(boardSize: size.width, isFlipped: isFlipped);
    final squareSize = geo.squareSize;

    // Filter valid moves against current position and revisions
    final validArrows = <CandidateArrow>[];
    for (final arrow in candidateArrows) {
      if (arrow.positionRevision > 0 && positionRevision > 0 && arrow.positionRevision != positionRevision) {
        continue;
      }
      if (arrow.requestId > 0 && analysisRequestId != null && arrow.requestId != analysisRequestId) {
        continue;
      }
      if (arrow.from == arrow.to) {
        continue;
      }
      final legalMove = position.findLegalMoveByUci(arrow.uciMove);
      if (legalMove == null) continue;

      validArrows.add(arrow);
    }

    if (validArrows.isEmpty) return;

    // Prepare geometric arrow trajectories with deterministic curved paths
    final prepared = <_PreparedArrow>[];
    for (final arrow in validArrows) {
      final startCenter = geo.getSquareCenter(arrow.from);
      final endCenter = geo.getSquareCenter(arrow.to);

      final dx = endCenter.dx - startCenter.dx;
      final dy = endCenter.dy - startCenter.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < 1.0) continue;

      // Refined, thin-to-medium shafts with mobile visibility floor:
      // Minimum stroke width on mobile is enforced so lower ranks never vanish.
      final double baseShaftScale = switch (arrow.rank) {
        1 => 0.082,
        2 => 0.070,
        3 => 0.062,
        _ => 0.055,
      };
      final double baseHeadLengthScale = switch (arrow.rank) {
        1 => 0.26,
        2 => 0.23,
        3 => 0.21,
        _ => 0.19,
      };
      final double baseHeadWidthScale = switch (arrow.rank) {
        1 => 0.28,
        2 => 0.25,
        3 => 0.23,
        _ => 0.21,
      };

      final strokeWidth = math.max(
        config.minStrokeWidth,
        squareSize * baseShaftScale * arrow.style.strokeWidthScale,
      );
      final arrowHeadLength = math.max(9.0, squareSize * baseHeadLengthScale * arrow.style.arrowHeadScale);
      final arrowHeadWidth = math.max(10.0, squareSize * baseHeadWidthScale * arrow.style.arrowHeadScale);
      final badgeRadius = math.max(10.0, squareSize * 0.175 * arrow.style.badgeScale);

      // Ensure minimum opacity floor so ranks 2..4 remain crisp on mobile
      final effectiveOpacity = math.max(0.85, arrow.style.opacity);
      final arrowColor = arrow.style.shaftColor.withValues(alpha: effectiveOpacity);

      final unitX = dx / distance;
      final unitY = dy / distance;

      // Deterministic signed curvature for elegant trajectory and overlap prevention:
      // PV1: almost straight with very subtle natural bow (0.02)
      // PV2: gentle counter curve (-0.09)
      // PV3: gentle clockwise curve (0.11)
      // PV4: outer separation curve (-0.14)
      double effectiveCurvature = arrow.style.curvature;
      if (effectiveCurvature == 0.0) {
        effectiveCurvature = switch (arrow.rank) {
          1 => 0.025,
          2 => -0.090,
          3 => 0.110,
          4 => -0.140,
          _ => (arrow.rank.isEven ? -0.16 : 0.16),
        };
      }
      effectiveCurvature *= config.curveAmount;

      // Start slightly inset from start square center for clean piece clearance
      final startOffset = Offset(
        startCenter.dx + unitX * (squareSize * 0.14),
        startCenter.dy + unitY * (squareSize * 0.14),
      );

      final arrowEndPoint = endCenter;
      final normX = -unitY;
      final normY = unitX;
      final offsetDist = effectiveCurvature * squareSize;

      // Quadratic Bézier control point at midpoint + perpendicular normal
      final midX = (startOffset.dx + arrowEndPoint.dx) / 2.0;
      final midY = (startOffset.dy + arrowEndPoint.dy) / 2.0;
      final controlPoint = Offset(
        midX + normX * offsetDist,
        midY + normY * offsetDist,
      );

      final curvePath = Path()
        ..moveTo(startOffset.dx, startOffset.dy)
        ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, arrowEndPoint.dx, arrowEndPoint.dy);

      // Tangent angle at arrival point (arrowEndPoint)
      final endTangentX = arrowEndPoint.dx - controlPoint.dx;
      final endTangentY = arrowEndPoint.dy - controlPoint.dy;
      final angle = math.atan2(endTangentY, endTangentX);

      prepared.add(_PreparedArrow(
        arrow: arrow,
        startCenter: startOffset,
        endCenter: endCenter,
        arrowEndPoint: arrowEndPoint,
        angle: angle,
        distance: distance,
        strokeWidth: strokeWidth,
        arrowHeadLength: arrowHeadLength,
        arrowHeadWidth: arrowHeadWidth,
        badgeRadius: badgeRadius,
        arrowColor: arrowColor,
        curvature: effectiveCurvature,
        curvePath: curvePath,
      ));
    }

    if (prepared.isEmpty) return;

    // Layout badges using dedicated collision-aware NibblerBadgeLayoutEngine.
    // Badges are placed along the curved shaft backwards from the arrowhead so the arrowhead remains 100% visible,
    // and offset if needed to guarantee zero badge-on-badge overlaps, board edge containment, and piece avoidance.
    final badgeRequests = <BadgeLayoutRequest>[];
    final textPainters = <CandidateArrow, TextPainter>{};

    for (final p in prepared) {
      final text = p.arrow.getBadgeText(arrowheadType, engineType);
      final fontSize = text.length > 2 ? p.badgeRadius * 0.76 : p.badgeRadius * 0.95;

      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: p.arrow.style.textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            letterSpacing: text.length > 2 ? -0.8 : -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainters[p.arrow] = textPainter;

      const hPadding = 6.0;
      const vPadding = 3.5;
      final badgeW = math.max(p.badgeRadius * 2.0, textPainter.width + hPadding * 2);
      final badgeH = math.max(p.badgeRadius * 2.0, textPainter.height + vPadding * 2);

      badgeRequests.add(BadgeLayoutRequest(
        arrow: p.arrow,
        arrowStart: p.startCenter,
        arrowEnd: p.arrowEndPoint,
        arrowMid: Offset(
          (p.startCenter.dx + p.arrowEndPoint.dx) / 2.0 + (-math.sin(p.angle)) * (p.curvature * squareSize),
          (p.startCenter.dy + p.arrowEndPoint.dy) / 2.0 + (math.cos(p.angle)) * (p.curvature * squareSize),
        ),
        arrowAngle: p.angle,
        arrowHeadLength: p.arrowHeadLength,
        arrowHeadWidth: p.arrowHeadWidth,
        badgeRadius: p.badgeRadius,
        width: badgeW,
        height: badgeH,
        arrowPath: p.curvePath,
      ));
    }

    final solvedBadges = NibblerBadgeLayoutEngine.layoutBadges(
      requests: badgeRequests,
      geometry: geo,
      position: position,
      boardPadding: 4.0,
    );

    final placedBadges = <_BadgePlacement>[];
    for (final s in solvedBadges) {
      final tp = textPainters[s.arrow]!;
      placedBadges.add(_BadgePlacement(
        arrow: s.arrow,
        center: s.center,
        boundingBox: s.boundingBox,
        radius: s.radius,
        textPainter: tp,
        width: s.width,
        height: s.height,
        leaderStart: s.leaderStart,
        hasLeader: s.hasLeader,
      ));
    }

    // Explicit 3-pass layer rendering:
    // Nibbler layering: Longer arrows underneath shorter arrows.
    final drawOrder = List<_PreparedArrow>.from(prepared)
      ..sort((a, b) {
        final lenCmp = b.distance.compareTo(a.distance);
        if (lenCmp != 0) return lenCmp;
        return b.arrow.rank.compareTo(a.arrow.rank);
      });

    // LAYER 1: Arrow Shafts with subtle dark border for contrast
    for (final p in drawOrder) {
      final borderPaint = Paint()
        ..color = Colors.black.withValues(alpha: p.arrow.rank == 1 ? 0.35 : 0.22)
        ..strokeWidth = p.strokeWidth + 1.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final shaftPaint = Paint()
        ..color = p.arrowColor
        ..strokeWidth = p.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (p.curvature == 0.0) {
        canvas.drawLine(p.startCenter, p.arrowEndPoint, borderPaint);
        canvas.drawLine(p.startCenter, p.arrowEndPoint, shaftPaint);
      } else if (p.curvePath != null) {
        canvas.drawPath(p.curvePath!, borderPaint);
        canvas.drawPath(p.curvePath!, shaftPaint);
      }
    }

    // LAYER 2: Arrowheads with prominent Nibbler geometry & dark outline
    for (final p in drawOrder) {
      _drawArrowHead(
        canvas: canvas,
        tip: p.arrowEndPoint,
        angle: p.angle,
        length: p.arrowHeadLength,
        width: p.arrowHeadWidth,
        color: p.arrowColor,
        isRank1: p.arrow.rank == 1,
      );
    }

    // LAYER 3: Score Badges (rendered strictly on top of all shafts and arrowheads)
    final badgeDrawOrder = List<_BadgePlacement>.from(placedBadges)
      ..sort((a, b) => b.arrow.rank.compareTo(a.arrow.rank));

    for (final b in badgeDrawOrder) {
      _drawBadge(canvas: canvas, placement: b);
    }
  }

  void _drawArrowHead({
    required Canvas canvas,
    required Offset tip,
    required double angle,
    required double length,
    required double width,
    required Color color,
    required bool isRank1,
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

    final notchX = tip.dx - (length * 0.76) * cosA;
    final notchY = tip.dy - (length * 0.76) * sinA;

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(wing1.dx, wing1.dy)
      ..lineTo(notchX, notchY)
      ..lineTo(wing2.dx, wing2.dy)
      ..close();

    final outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: isRank1 ? 0.38 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isRank1 ? 1.6 : 1.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(headPath, outlinePaint);

    final headFillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headFillPaint);
  }

  void _drawBadge({
    required Canvas canvas,
    required _BadgePlacement placement,
  }) {
    final center = placement.center;
    final rrect = RRect.fromRectAndRadius(
      placement.boundingBox,
      Radius.circular(placement.height / 2.0),
    );

    // Subtle connector leader line if badge was offset away from the arrow tip
    if (placement.hasLeader) {
      // Connect from arrowhead base/tip to the edge of the badge
      final dir = center - placement.leaderStart;
      final dist = dir.distance;
      if (dist > 1.0) {
        final uDir = dir / dist;
        // End point slightly before the badge edge
        final targetPt = Offset(
          center.dx - uDir.dx * (placement.width / 2.0 * 0.9),
          center.dy - uDir.dy * (placement.height / 2.0 * 0.9),
        );

        final leaderOutline = Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(placement.leaderStart, targetPt, leaderOutline);

        final leaderPaint = Paint()
          ..color = placement.arrow.style.badgeColor.withValues(alpha: 0.85)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(placement.leaderStart, targetPt, leaderPaint);
      }
    }

    // Subtle soft drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawRRect(rrect.shift(const Offset(0, 1.2)), shadowPaint);

    // Fill badge
    final fillPaint = Paint()
      ..color = placement.arrow.style.badgeColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    // High-contrast border (Rank 1 crisp white, other ranks crisp dark border)
    final borderPaint = Paint()
      ..color = placement.arrow.style.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = placement.arrow.rank == 1 ? 1.8 : 1.0;
    canvas.drawRRect(rrect, borderPaint);

    // Badge text
    placement.textPainter.paint(
      canvas,
      Offset(
        center.dx - (placement.textPainter.width / 2.0),
        center.dy - (placement.textPainter.height / 2.0),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant NibblerArrowPainter oldDelegate) {
    if (oldDelegate.isFlipped != isFlipped) return true;
    if (oldDelegate.positionRevision != positionRevision) return true;
    if (oldDelegate.analysisRequestId != analysisRequestId) return true;
    if (oldDelegate.position != position) return true;
    if (oldDelegate.arrowheadType != arrowheadType) return true;
    if (oldDelegate.engineType != engineType) return true;
    if (oldDelegate.config.curveAmount != config.curveAmount) return true;
    if (oldDelegate.config.arrowOpacity != config.arrowOpacity) return true;
    if (oldDelegate.config.minStrokeWidth != config.minStrokeWidth) return true;
    if (oldDelegate.candidateArrows.length != candidateArrows.length) return true;

    for (int i = 0; i < candidateArrows.length; i++) {
      final a = candidateArrows[i];
      final b = oldDelegate.candidateArrows[i];
      if (a.uciMove != b.uciMove) return true;
      if (a.rank != b.rank) return true;
      if (a.winProbability != b.winProbability) return true;
      if (a.nodePercentage != b.nodePercentage) return true;
      if (a.policyPercentage != b.policyPercentage) return true;
      if (a.movesLeft != b.movesLeft) return true;
    }
    return false;
  }
}

class _PreparedArrow {
  final CandidateArrow arrow;
  final Offset startCenter;
  final Offset endCenter;
  final Offset arrowEndPoint;
  final double angle;
  final double distance;
  final double strokeWidth;
  final double arrowHeadLength;
  final double arrowHeadWidth;
  final double badgeRadius;
  final Color arrowColor;
  final double curvature;
  final Path? curvePath;

  _PreparedArrow({
    required this.arrow,
    required this.startCenter,
    required this.endCenter,
    required this.arrowEndPoint,
    required this.angle,
    required this.distance,
    required this.strokeWidth,
    required this.arrowHeadLength,
    required this.arrowHeadWidth,
    required this.badgeRadius,
    required this.arrowColor,
    required this.curvature,
    this.curvePath,
  });
}

class _BadgePlacement {
  final CandidateArrow arrow;
  final Offset center;
  final Rect boundingBox;
  final double radius;
  final TextPainter textPainter;
  final double width;
  final double height;
  final Offset leaderStart;
  final bool hasLeader;

  _BadgePlacement({
    required this.arrow,
    required this.center,
    required this.boundingBox,
    required this.radius,
    required this.textPainter,
    required this.width,
    required this.height,
    required this.leaderStart,
    required this.hasLeader,
  });
}
