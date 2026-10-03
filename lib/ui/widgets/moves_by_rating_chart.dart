import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/maia_dual_analysis.dart';
import 'moves_by_rating_info_dialog.dart';

/// An authentic, interactive Moves by Rating chart matching maiachess.com analysis.
///
/// Plots dynamic player rating on the X axis (600 to 2600) and Maia move probability
/// on the Y axis (0% to 100%). Features smooth cubic curves with gradient area fills,
/// dashed gridlines, rotated "Maia Probability" axis label, and curve-end SAN labels.
class MovesByRatingChart extends StatefulWidget {
  final MovesByRatingDataset dataset;
  final ValueChanged<int>? onRatingSelected;
  final ValueChanged<String>? onMoveSelected;
  final VoidCallback? onDownloadModelRequested;
  final String? highlightedUciMove;
  final bool isInitiallyExpanded;

  const MovesByRatingChart({
    super.key,
    required this.dataset,
    this.onRatingSelected,
    this.onMoveSelected,
    this.onDownloadModelRequested,
    this.highlightedUciMove,
    this.isInitiallyExpanded = true,
  });

  @override
  State<MovesByRatingChart> createState() => _MovesByRatingChartState();
}

class _MovesByRatingChartState extends State<MovesByRatingChart> {
  int? _hoverRating;
  Offset? _touchPosition;
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final dataset = widget.dataset;
    final activeRating = _hoverRating ?? dataset.activeRating;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A33), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header Bar: Title + (i) Info + Legend/Rating + Collapse Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title + (i) Info icon (flexible)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Moves by Rating',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 15, color: Color(0xFF888899)),
                      onPressed: () => MovesByRatingInfoDialog.show(context),
                      tooltip: 'What is Moves by Rating?',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                    if (dataset.isComputing) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFE7F6D)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Right-side controls: Rating badge & collapse chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Active Rating Badge
                  GestureDetector(
                    onTap: () => widget.onRatingSelected?.call(activeRating),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22222C),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF3D3D4E), width: 0.8),
                      ),
                      child: Text(
                        'Elo $activeRating',
                        style: const TextStyle(
                          color: Color(0xFF80D4FF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Collapse / Expand Toggle
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    tooltip: _isExpanded ? 'Collapse Chart' : 'Expand Chart',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ],
          ),

          if (!dataset.isModelInstalled) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E26),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF383848), width: 0.8),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.psychology_outlined, size: 16, color: Color(0xFFFE7F6D)),
                      SizedBox(width: 6),
                      Text(
                        'Maia model not installed',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Install Maia neural weights to explore human move likelihood across player ratings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  if (widget.onDownloadModelRequested != null) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007ACC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text(
                        'Download Model',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: widget.onDownloadModelRequested,
                    ),
                  ],
                ],
              ),
            ),
          ] else if (_isExpanded) ...[
            const SizedBox(height: 6),

            // 2. Dynamic Move Legend Chips (Colored tags with probabilities)
            if (dataset.curves.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: dataset.curves.map((curve) {
                  final isSelected = widget.highlightedUciMove == curve.uciMove;
                  final prob = curve.probabilityAtRating(activeRating) ?? 0.0;
                  return GestureDetector(
                    onTap: () {
                      widget.onMoveSelected?.call(curve.uciMove);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? curve.curveColor.withValues(alpha: 0.25)
                            : const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? curve.curveColor
                              : curve.curveColor.withValues(alpha: 0.45),
                          width: isSelected ? 1.4 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: curve.curveColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            curve.sanMove.isNotEmpty ? curve.sanMove : curve.uciMove,
                            style: TextStyle(
                              color: curve.curveColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${prob.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 8),

            // 3. Interactive Chart Canvas
            SizedBox(
              height: 135,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanDown: (details) =>
                        _handleTouch(details.localPosition, constraints.biggest),
                    onPanUpdate: (details) =>
                        _handleTouch(details.localPosition, constraints.biggest),
                    onPanEnd: (_) => _finishTouch(),
                    onPanCancel: () => _finishTouch(),
                    onTapUp: (details) =>
                        _handleTap(details.localPosition, constraints.biggest),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: constraints.biggest,
                        painter: _RatingChartPainter(
                          dataset: dataset,
                          activeRating: activeRating,
                          touchPosition: _touchPosition,
                          highlightedUciMove: widget.highlightedUciMove,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleTouch(Offset localPos, Size size) {
    const leftPad = 48.0;
    const rightPad = 34.0;
    final chartW = size.width - leftPad - rightPad;
    if (chartW <= 0) return;

    final x = (localPos.dx - leftPad).clamp(0.0, chartW);
    final ratio = x / chartW;

    final ratings = widget.dataset.supportedRatings;
    if (ratings.isEmpty) return;

    final minRating = ratings.first;
    final maxRating = ratings.last;
    final targetRating = (minRating + ratio * (maxRating - minRating)).round();

    // Snap to closest rating node
    int closest = ratings.first;
    int minDiff = 999999;
    for (final r in ratings) {
      final diff = (r - targetRating).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = r;
      }
    }

    setState(() {
      _hoverRating = closest;
      _touchPosition = localPos;
    });
    widget.onRatingSelected?.call(closest);
  }

  void _handleTap(Offset localPos, Size size) {
    _handleTouch(localPos, size);
  }

  void _finishTouch() {
    setState(() {
      _touchPosition = null;
    });
  }
}

class _RatingChartPainter extends CustomPainter {
  final MovesByRatingDataset dataset;
  final int activeRating;
  final Offset? touchPosition;
  final String? highlightedUciMove;

  _RatingChartPainter({
    required this.dataset,
    required this.activeRating,
    this.touchPosition,
    this.highlightedUciMove,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 48.0;
    const rightPad = 34.0;
    const topPad = 8.0;
    const bottomPad = 20.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    if (chartW <= 0 || chartH <= 0) return;

    final ratings = dataset.supportedRatings;
    if (ratings.isEmpty) return;

    final minRating = ratings.first.toDouble();
    final maxRating = ratings.last.toDouble();
    final ratingSpan = maxRating - minRating > 0 ? maxRating - minRating : 1.0;

    // Determine Y max domain (default 100%, or 60% if all points are low)
    double maxObservedProb = 0.0;
    for (final curve in dataset.curves) {
      for (final pt in curve.points) {
        if (pt.probability > maxObservedProb) {
          maxObservedProb = pt.probability;
        }
      }
    }
    final yMax = maxObservedProb > 60.0 ? 100.0 : 60.0;

    // 1. Draw Vertical Rotated Y-Axis Label: "Maia Probability"
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'Maia Probability',
        style: TextStyle(
          color: Color(0xFFFE7F6D),
          fontSize: 10.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    // Rotate 90 degrees counter-clockwise
    canvas.translate(11, topPad + chartH / 2 + labelPainter.width / 2);
    canvas.rotate(-math.pi / 2);
    labelPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // 2. Dashed Horizontal Grid Lines (0%, 25%, 50%, 75%, 100% or based on yMax)
    final gridPaint = Paint()
      ..color = const Color(0xFF33333D)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final axisTextPainter = TextPainter(textDirection: TextDirection.ltr);
    final ySteps = yMax == 100.0 ? [0, 25, 50, 75, 100] : [0, 20, 40, 60];

    for (final pct in ySteps) {
      final y = topPad + chartH * (1.0 - (pct / yMax));
      _drawDashedLine(canvas, Offset(leftPad, y), Offset(leftPad + chartW, y), gridPaint);

      axisTextPainter.text = TextSpan(
        text: '$pct%',
        style: const TextStyle(
          color: Color(0xFF8E8E9F),
          fontSize: 8.5,
          fontFamily: 'monospace',
        ),
      );
      axisTextPainter.layout();
      axisTextPainter.paint(
        canvas,
        Offset(leftPad - axisTextPainter.width - 4, y - axisTextPainter.height / 2),
      );
    }

    // 3. Dynamic Model-Driven X-Axis Rating Ticks (Derived from actual model conditions)
    final displayedRatings = <int>[];
    if (ratings.length <= 6) {
      displayedRatings.addAll(ratings);
    } else {
      displayedRatings.add(ratings.first);
      final span = ratings.last - ratings.first;
      final targetTicks = chartW > 300 ? 5 : 4;
      final step = (span / targetTicks).round();
      for (int i = 1; i < targetTicks; i++) {
        final target = ratings.first + (step * i);
        int closest = ratings.first;
        int minD = 999999;
        for (final r in ratings) {
          final d = (r - target).abs();
          if (d < minD) {
            minD = d;
            closest = r;
          }
        }
        if (!displayedRatings.contains(closest) && closest != ratings.last) {
          displayedRatings.add(closest);
        }
      }
      if (!displayedRatings.contains(ratings.last)) {
        displayedRatings.add(ratings.last);
      }
      displayedRatings.sort();
    }

    for (final r in displayedRatings) {
      final x = leftPad + ((r - minRating) / ratingSpan) * chartW;

      // Small tick line
      canvas.drawLine(
        Offset(x, topPad + chartH),
        Offset(x, topPad + chartH + 3),
        Paint()..color = const Color(0xFF444455)..strokeWidth = 1.0,
      );

      axisTextPainter.text = TextSpan(
        text: '$r',
        style: const TextStyle(
          color: Color(0xFF8E8E9F),
          fontSize: 8.5,
          fontFamily: 'monospace',
        ),
      );
      axisTextPainter.layout();
      axisTextPainter.paint(
        canvas,
        Offset(x - axisTextPainter.width / 2, topPad + chartH + 5),
      );
    }

    // 4. Highlighted Active Rating Vertical Line (Clamped to model bounds)
    final clampedActive = activeRating.clamp(minRating.round(), maxRating.round());
    final activeX = leftPad + ((clampedActive - minRating) / ratingSpan) * chartW;
    final activeLinePaint = Paint()
      ..color = const Color(0xFF00D2BE).withValues(alpha: 0.65)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
      canvas,
      Offset(activeX, topPad),
      Offset(activeX, topPad + chartH),
      activeLinePaint,
      dashWidth: 4,
      dashSpace: 3,
    );

    // 5. Plot Curves with Gradient Area Fills & Data Dots
    final endLabels = <_CurveEndLabel>[];

    for (final curve in dataset.curves) {
      if (curve.points.isEmpty) continue;

      final isHighlight = highlightedUciMove == curve.uciMove;
      final sortedPoints = List<MoveRatingPoint>.from(curve.points)
        ..sort((a, b) => a.rating.compareTo(b.rating));

      final pixelPoints = <Offset>[];
      for (final pt in sortedPoints) {
        final x = leftPad + ((pt.rating - minRating) / ratingSpan) * chartW;
        final y = topPad + chartH * (1.0 - (pt.probability.clamp(0.0, yMax) / yMax));
        pixelPoints.add(Offset(x, y));
      }

      if (pixelPoints.isEmpty) continue;

      // A. Build Cubic Path
      final linePath = Path();
      linePath.moveTo(pixelPoints.first.dx, pixelPoints.first.dy);

      for (int i = 0; i < pixelPoints.length - 1; i++) {
        final p0 = pixelPoints[i];
        final p1 = pixelPoints[i + 1];
        final cx1 = p0.dx + (p1.dx - p0.dx) / 2.0;
        final cy1 = p0.dy;
        final cx2 = p0.dx + (p1.dx - p0.dx) / 2.0;
        final cy2 = p1.dy;
        linePath.cubicTo(cx1, cy1, cx2, cy2, p1.dx, p1.dy);
      }

      // B. Draw Shaded Gradient Area beneath curve
      final areaPath = Path.from(linePath);
      areaPath.lineTo(pixelPoints.last.dx, topPad + chartH);
      areaPath.lineTo(pixelPoints.first.dx, topPad + chartH);
      areaPath.close();

      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            curve.curveColor.withValues(alpha: isHighlight ? 0.45 : 0.30),
            curve.curveColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH))
        ..style = PaintingStyle.fill;

      canvas.drawPath(areaPath, gradientPaint);

      // C. Draw Curve Stroke
      final strokePaint = Paint()
        ..color = isHighlight ? curve.curveColor : curve.curveColor.withValues(alpha: 0.90)
        ..strokeWidth = isHighlight ? 3.0 : 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(linePath, strokePaint);

      // D. Draw circular data dots
      final dotFillPaint = Paint()
        ..color = curve.curveColor
        ..style = PaintingStyle.fill;

      for (final p in pixelPoints) {
        canvas.drawCircle(p, isHighlight ? 3.0 : 2.2, dotFillPaint);
      }

      // E. Draw active rating marker dot
      final activeProb = curve.probabilityAtRating(activeRating);
      if (activeProb != null) {
        final dotY = topPad + chartH * (1.0 - (activeProb.clamp(0.0, yMax) / yMax));
        final activeDotPos = Offset(activeX, dotY);
        canvas.drawCircle(activeDotPos, isHighlight ? 5.0 : 3.8, dotFillPaint);
        canvas.drawCircle(
          activeDotPos,
          isHighlight ? 5.0 : 3.8,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }

      // Collect end label info for collision-free painting
      final lastPt = pixelPoints.last;
      endLabels.add(_CurveEndLabel(
        san: curve.sanMove.isNotEmpty ? curve.sanMove : curve.uciMove,
        color: curve.curveColor,
        x: lastPt.dx + 4,
        y: lastPt.dy,
      ));
    }

    // 6. Draw Inline Move Labels at the end of each curve (with collision avoidance & boundary clamping)
    _paintEndLabels(canvas, endLabels, chartH, topPad);

    // 7. Interactive Hover / Touch Tooltip Overlay
    if (touchPosition != null) {
      _paintInteractiveTooltip(
        canvas: canvas,
        activeRating: activeRating,
        activeX: activeX,
        topPad: topPad,
        leftPad: leftPad,
        chartW: chartW,
        chartH: chartH,
      );
    }
  }

  void _paintEndLabels(
    Canvas canvas,
    List<_CurveEndLabel> labels,
    double chartH,
    double topPad,
  ) {
    if (labels.isEmpty) return;

    // Sort by Y position ascending (top of screen to bottom)
    labels.sort((a, b) => a.y.compareTo(b.y));

    // Collision avoidance: ensure min vertical separation of 11px
    const minDistance = 11.0;
    for (int i = 1; i < labels.length; i++) {
      final prev = labels[i - 1];
      final curr = labels[i];
      if (curr.y - prev.adjustedY < minDistance) {
        curr.adjustedY = prev.adjustedY + minDistance;
      }
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final lbl in labels) {
      // Strictly clamp label inside topPad and topPad + chartH bounds
      final clampedY = lbl.adjustedY.clamp(topPad + 4.0, topPad + chartH - 4.0);
      tp.text = TextSpan(
        text: lbl.san,
        style: TextStyle(
          color: lbl.color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(lbl.x, clampedY - tp.height / 2));
    }
  }

  void _paintInteractiveTooltip({
    required Canvas canvas,
    required int activeRating,
    required double activeX,
    required double topPad,
    required double leftPad,
    required double chartW,
    required double chartH,
  }) {
    final titleSpan = TextSpan(
      text: 'Rating $activeRating\n',
      style: const TextStyle(
        color: Color(0xFF80D4FF),
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );

    final lineSpans = <InlineSpan>[titleSpan];
    final sortedCurves = List<MoveRatingCurve>.from(dataset.curves)
      ..sort((a, b) {
        final pa = a.probabilityAtRating(activeRating) ?? 0.0;
        final pb = b.probabilityAtRating(activeRating) ?? 0.0;
        return pb.compareTo(pa);
      });

    for (final curve in sortedCurves) {
      final prob = curve.probabilityAtRating(activeRating) ?? 0.0;
      final san = curve.sanMove.isNotEmpty ? curve.sanMove : curve.uciMove;
      lineSpans.add(TextSpan(
        text: '$san: ',
        style: TextStyle(
          color: curve.curveColor,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ));
      lineSpans.add(TextSpan(
        text: '${prob.toStringAsFixed(1)}%\n',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.0,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ));
    }

    final tooltipPainter = TextPainter(
      text: TextSpan(children: lineSpans),
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 6.0;
    const paddingV = 4.0;
    final boxW = tooltipPainter.width + paddingH * 2;
    final boxH = tooltipPainter.height + paddingV * 2;

    // Anchor tooltip smartly to the left or right of the vertical guide line
    double boxX = activeX + 6.0;
    if (boxX + boxW > leftPad + chartW + 28.0) {
      boxX = activeX - boxW - 6.0;
    }
    if (boxX < leftPad) boxX = leftPad;

    final boxY = (topPad + 4.0).clamp(topPad, topPad + chartH - boxH);

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxX, boxY, boxW, boxH),
      const Radius.circular(4),
    );

    // Background fill
    canvas.drawRRect(
      bgRect,
      Paint()..color = const Color(0xE614141A),
    );

    // Subtle border
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = const Color(0xFF00D2BE).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    tooltipPainter.paint(canvas, Offset(boxX + paddingH, boxY + paddingV));
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    double dashWidth = 3.0,
    double dashSpace = 3.0,
  }) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= 0) return;

    final unitX = dx / distance;
    final unitY = dy / distance;

    double current = 0.0;
    while (current < distance) {
      final startX = p1.dx + unitX * current;
      final startY = p1.dy + unitY * current;
      final endDistance = math.min(current + dashWidth, distance);
      final endX = p1.dx + unitX * endDistance;
      final endY = p1.dy + unitY * endDistance;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      current += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _RatingChartPainter oldDelegate) {
    return oldDelegate.dataset != dataset ||
        oldDelegate.activeRating != activeRating ||
        oldDelegate.touchPosition != touchPosition ||
        oldDelegate.highlightedUciMove != highlightedUciMove;
  }
}

class _CurveEndLabel {
  final String san;
  final Color color;
  final double x;
  final double y;
  late double adjustedY;

  _CurveEndLabel({
    required this.san,
    required this.color,
    required this.x,
    required this.y,
  }) {
    adjustedY = y;
  }
}
