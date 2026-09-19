import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/chess_move.dart';
import '../../models/chess_position.dart';
import '../../models/engine_analysis.dart';
import '../../utils/win_rate_calculator.dart';

class NibblerArrowPainter extends CustomPainter {
  final List<CandidateArrow> candidateArrows;
  final List<PvLine> pvLines;
  final ChessPosition position;
  final int positionRevision;
  final int? analysisRequestId;
  final bool isFlipped;
  final ArrowheadType arrowheadType;
  final EngineType engineType;

  NibblerArrowPainter({
    List<CandidateArrow>? candidateArrows,
    this.pvLines = const [],
    required this.position,
    required this.positionRevision,
    this.analysisRequestId,
    this.isFlipped = false,
    this.arrowheadType = ArrowheadType.winrate,
    this.engineType = EngineType.lc0,
  }) : candidateArrows = candidateArrows ?? _fromPvLines(pvLines, positionRevision, analysisRequestId);

  static List<CandidateArrow> _fromPvLines(
    List<PvLine> lines,
    int revision,
    int? reqId,
  ) {
    final list = <CandidateArrow>[];
    for (final line in lines) {
      final from = line.fromSquare;
      final to = line.toSquare;
      final uci = line.primaryMoveUci;
      if (from == null || to == null || uci == null) continue;

      final rank = line.multipv;
      final baseColor = rank == 1
          ? Color(WinRateCalculator.getArrowColorValue(line.expectedScore))
          : (rank == 2
              ? const Color(0xFF4CAF50)
              : (rank == 3
                  ? const Color(0xFF29B6F6)
                  : const Color(0xFFAB47BC)));

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
          textColor: const Color(0xFF111111),
          borderColor: rank == 1 ? Colors.white : Colors.black45,
          opacity: rank == 1 ? 0.95 : 0.80,
          strokeWidthScale: rank == 1 ? 1.15 : 0.90,
          arrowHeadScale: rank == 1 ? 1.15 : 0.90,
          badgeScale: rank == 1 ? 1.05 : 0.95,
        ),
      ));
    }
    return list;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (candidateArrows.isEmpty) return;

    final squareSize = size.width / 8.0;

    // Filter valid arrows
    final validArrows = <CandidateArrow>[];
    for (final arrow in candidateArrows) {
      if (arrow.positionRevision <= 0 || arrow.positionRevision != positionRevision) {
        continue;
      }
      if (arrow.requestId <= 0 || (analysisRequestId != null && arrow.requestId != analysisRequestId)) {
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

    // Prepare geometric arrow data
    final prepared = <_PreparedArrow>[];
    for (final arrow in validArrows) {
      final startCenter = _getSquareCenter(arrow.from, squareSize);
      final endCenter = _getSquareCenter(arrow.to, squareSize);

      final dx = endCenter.dx - startCenter.dx;
      final dy = endCenter.dy - startCenter.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < 1.0) continue;

      final strokeWidth = squareSize * 0.10 * arrow.style.strokeWidthScale;
      final arrowHeadLength = squareSize * 0.28 * arrow.style.arrowHeadScale;
      final badgeRadius = squareSize * 0.25 * arrow.style.badgeScale;
      final arrowColor = arrow.style.shaftColor.withValues(alpha: arrow.style.opacity);

      final unitX = dx / distance;
      final unitY = dy / distance;

      final arrowEndPoint = Offset(
        endCenter.dx - (unitX * (badgeRadius * 0.35)),
        endCenter.dy - (unitY * (badgeRadius * 0.35)),
      );

      final curvature = arrow.style.curvature;
      Path? curvePath;
      double angle;

      if (curvature == 0.0) {
        angle = math.atan2(dy, dx);
      } else {
        final midX = (startCenter.dx + arrowEndPoint.dx) / 2.0;
        final midY = (startCenter.dy + arrowEndPoint.dy) / 2.0;
        final normX = -unitY;
        final normY = unitX;
        final offsetDist = curvature * squareSize;

        final controlPoint = Offset(
          midX + normX * offsetDist,
          midY + normY * offsetDist,
        );

        curvePath = Path()
          ..moveTo(startCenter.dx, startCenter.dy)
          ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, arrowEndPoint.dx, arrowEndPoint.dy);

        final endTangentX = arrowEndPoint.dx - controlPoint.dx;
        final endTangentY = arrowEndPoint.dy - controlPoint.dy;
        angle = math.atan2(endTangentY, endTangentX);
      }

      prepared.add(_PreparedArrow(
        arrow: arrow,
        startCenter: startCenter,
        endCenter: endCenter,
        arrowEndPoint: arrowEndPoint,
        angle: angle,
        strokeWidth: strokeWidth,
        arrowHeadLength: arrowHeadLength,
        badgeRadius: badgeRadius,
        arrowColor: arrowColor,
        curvature: curvature,
        curvePath: curvePath,
      ));
    }

    if (prepared.isEmpty) return;

    // Layout badges with measured TextPainter Rect collision avoidance
    // Process Rank 1 first so it retains its optimal anchor on the destination square
    final rankAscending = List<_PreparedArrow>.from(prepared)
      ..sort((a, b) => a.arrow.rank.compareTo(b.arrow.rank));

    final placedBadges = <_BadgePlacement>[];
    final boardBounds = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);

    for (final p in rankAscending) {
      final text = p.arrow.getBadgeText(arrowheadType, engineType);
      final fontSize = text.length > 2 ? p.badgeRadius * 0.72 : p.badgeRadius * 0.92;

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

      const hPadding = 6.0;
      const vPadding = 3.5;
      final badgeW = math.max(p.badgeRadius * 2.0, textPainter.width + hPadding * 2);
      final badgeH = math.max(p.badgeRadius * 2.0, textPainter.height + vPadding * 2);

      final dx = p.endCenter.dx - p.startCenter.dx;
      final dy = p.endCenter.dy - p.startCenter.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      final uX = dist > 0 ? dx / dist : 0.0;
      final uY = dist > 0 ? dy / dist : 0.0;
      final nX = -uY;
      final nY = uX;

      final preferredCenter = p.endCenter;
      final step = badgeH * 1.15;

      // Candidate offsets: preferred, along trajectory backwards, perpendicular normals, and forward
      final candidateCenters = <Offset>[
        preferredCenter,
        Offset(preferredCenter.dx - uX * step, preferredCenter.dy - uY * step),
        Offset(preferredCenter.dx + nX * step, preferredCenter.dy + nY * step),
        Offset(preferredCenter.dx - nX * step, preferredCenter.dy - nY * step),
        Offset(preferredCenter.dx - uX * (step * 2.0), preferredCenter.dy - uY * (step * 2.0)),
        Offset(preferredCenter.dx + uX * (step * 0.6), preferredCenter.dy + uY * (step * 0.6)),
      ];

      Offset chosenCenter = preferredCenter;
      Rect? chosenRect;
      double minOverlapArea = double.infinity;

      for (int i = 0; i < candidateCenters.length; i++) {
        final c = candidateCenters[i];
        final clampedX = c.dx.clamp(boardBounds.left + badgeW / 2, boardBounds.right - badgeW / 2);
        final clampedY = c.dy.clamp(boardBounds.top + badgeH / 2, boardBounds.bottom - badgeH / 2);
        final candidateCenter = Offset(clampedX, clampedY);
        final candidateRect = Rect.fromCenter(center: candidateCenter, width: badgeW, height: badgeH);

        double overlapArea = 0.0;
        for (final placed in placedBadges) {
          final intersection = candidateRect.intersect(placed.boundingBox);
          if (intersection.width > 0 && intersection.height > 0) {
            overlapArea += intersection.width * intersection.height;
          }
        }

        // Slight penalty for deviating from destination square so preferred is chosen when free
        final cost = overlapArea + (i * 25.0);
        if (cost < minOverlapArea) {
          minOverlapArea = cost;
          chosenCenter = candidateCenter;
          chosenRect = candidateRect;
          if (overlapArea == 0.0) {
            break;
          }
        }
      }

      chosenRect ??= Rect.fromCenter(center: chosenCenter, width: badgeW, height: badgeH);

      placedBadges.add(_BadgePlacement(
        arrow: p.arrow,
        center: chosenCenter,
        boundingBox: chosenRect,
        radius: p.badgeRadius,
        textPainter: textPainter,
        width: badgeW,
        height: badgeH,
      ));
    }

    // Explicit 3-pass layer rendering:
    // Rank 5 down to 1 so Rank 1 draws cleanly on top
    final drawOrder = List<_PreparedArrow>.from(prepared)
      ..sort((a, b) => b.arrow.rank.compareTo(a.arrow.rank));

    // LAYER 1: Arrow Shafts
    for (final p in drawOrder) {
      final shaftPaint = Paint()
        ..color = p.arrowColor
        ..strokeWidth = p.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (p.curvature == 0.0) {
        canvas.drawLine(p.startCenter, p.arrowEndPoint, shaftPaint);
      } else if (p.curvePath != null) {
        canvas.drawPath(p.curvePath!, shaftPaint);
      }
    }

    // LAYER 2: Arrowheads
    for (final p in drawOrder) {
      _drawArrowHead(canvas, p.arrowEndPoint, p.angle, p.arrowHeadLength, p.arrowColor);
    }

    // LAYER 3: Score Badges (rendered strictly on top of all shafts and arrowheads)
    final badgeDrawOrder = List<_BadgePlacement>.from(placedBadges)
      ..sort((a, b) => b.arrow.rank.compareTo(a.arrow.rank));

    for (final b in badgeDrawOrder) {
      _drawBadge(canvas: canvas, placement: b);
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset point,
    double angle,
    double length,
    Color color,
  ) {
    const arrowHeadAngle = math.pi / 6.0;
    final headP1 = Offset(
      point.dx - length * math.cos(angle - arrowHeadAngle),
      point.dy - length * math.sin(angle - arrowHeadAngle),
    );
    final headP2 = Offset(
      point.dx - length * math.cos(angle + arrowHeadAngle),
      point.dy - length * math.sin(angle + arrowHeadAngle),
    );

    final headPath = Path()
      ..moveTo(point.dx, point.dy)
      ..lineTo(headP1.dx, headP1.dy)
      ..lineTo(
        point.dx - (length * 0.6) * math.cos(angle),
        point.dy - (length * 0.6) * math.sin(angle),
      )
      ..lineTo(headP2.dx, headP2.dy)
      ..close();

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

    // 1. Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(rrect.shift(const Offset(0, 1.8)), shadowPaint);

    // 2. Fill badge
    final fillPaint = Paint()
      ..color = placement.arrow.style.badgeColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    // 3. High-contrast border (Rank 1 white, other ranks dark subtle)
    final borderPaint = Paint()
      ..color = placement.arrow.style.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = placement.arrow.rank == 1 ? 2.2 : 1.2;
    canvas.drawRRect(rrect, borderPaint);

    // 4. Badge text
    placement.textPainter.paint(
      canvas,
      Offset(
        center.dx - (placement.textPainter.width / 2.0),
        center.dy - (placement.textPainter.height / 2.0),
      ),
    );
  }

  Offset _getSquareCenter(Square sq, double squareSize) {
    // White orientation: sq.file 0..7 (a..h, left-to-right), sq.rank 0..7 (1..8, bottom-to-top)
    // Black orientation: sq.file 7..0 (h..a, left-to-right), sq.rank 7..0 (8..1, bottom-to-top)
    final f = isFlipped ? (7 - sq.file) : sq.file;
    final r = isFlipped ? sq.rank : (7 - sq.rank);
    return Offset((f + 0.5) * squareSize, (r + 0.5) * squareSize);
  }

  @override
  bool shouldRepaint(covariant NibblerArrowPainter oldDelegate) {
    if (oldDelegate.isFlipped != isFlipped) return true;
    if (oldDelegate.positionRevision != positionRevision) return true;
    if (oldDelegate.analysisRequestId != analysisRequestId) return true;
    if (oldDelegate.position != position) return true;
    if (oldDelegate.arrowheadType != arrowheadType) return true;
    if (oldDelegate.engineType != engineType) return true;
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
  final double strokeWidth;
  final double arrowHeadLength;
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
    required this.strokeWidth,
    required this.arrowHeadLength,
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

  _BadgePlacement({
    required this.arrow,
    required this.center,
    required this.boundingBox,
    required this.radius,
    required this.textPainter,
    required this.width,
    required this.height,
  });
}

