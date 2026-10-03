import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
  final Set<String> _hiddenMoves = {};

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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFE7F6D).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFE7F6D).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFE7F6D)),
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Updating…',
                              style: TextStyle(
                                color: Color(0xFFFE7F6D),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                  final isHidden = _hiddenMoves.contains(curve.uciMove);
                  final isSelected = widget.highlightedUciMove == curve.uciMove && !isHidden;
                  final prob = curve.probabilityAtRating(activeRating) ?? 0.0;
                  return Opacity(
                    opacity: isHidden ? 0.45 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? curve.curveColor.withValues(alpha: 0.25)
                            : const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isHidden
                              ? const Color(0xFF383848)
                              : isSelected
                                  ? curve.curveColor
                                  : curve.curveColor.withValues(alpha: 0.45),
                          width: isSelected ? 1.4 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                if (isHidden) {
                                  _hiddenMoves.remove(curve.uciMove);
                                } else {
                                  _hiddenMoves.add(curve.uciMove);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: isHidden
                                  ? Icon(
                                      Icons.visibility_off_outlined,
                                      size: 11,
                                      color: curve.curveColor.withValues(alpha: 0.6),
                                    )
                                  : Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: curve.curveColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (isHidden) {
                                setState(() => _hiddenMoves.remove(curve.uciMove));
                              }
                              widget.onMoveSelected?.call(curve.uciMove);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  curve.sanMove.isNotEmpty ? curve.sanMove : curve.uciMove,
                                  style: TextStyle(
                                    color: isHidden ? Colors.white38 : curve.curveColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    decoration: isHidden ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${prob.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: isHidden ? Colors.white24 : Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
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
                          hiddenMoves: _hiddenMoves,
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
  final Set<String> hiddenMoves;

  _RatingChartPainter({
    required this.dataset,
    required this.activeRating,
    this.touchPosition,
    this.highlightedUciMove,
    this.hiddenMoves = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 48.0;
    const rightPad = 42.0;
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
      if (hiddenMoves.contains(curve.uciMove)) continue;
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
      if (curve.points.isEmpty || hiddenMoves.contains(curve.uciMove)) continue;

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

      // A. Build Cubic Path using Fritsch-Carlson Monotone Cubic Spline
      final linePath = MonotoneCubicSpline.computePath(pixelPoints);

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
        originX: lastPt.dx,
        originY: lastPt.dy,
        x: lastPt.dx + 6,
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

    // Collision avoidance: ensure min vertical separation of 13px
    const minDistance = 13.0;
    for (int i = 1; i < labels.length; i++) {
      final prev = labels[i - 1];
      final curr = labels[i];
      if (curr.y - prev.adjustedY < minDistance) {
        curr.adjustedY = prev.adjustedY + minDistance;
      }
    }

    // Boundary relaxation: if bottom overflowed, shift upward
    final maxAllowedY = topPad + chartH - 4.0;
    if (labels.last.adjustedY > maxAllowedY) {
      final excess = labels.last.adjustedY - maxAllowedY;
      for (final lbl in labels) {
        lbl.adjustedY = (lbl.adjustedY - excess).clamp(topPad + 4.0, maxAllowedY);
      }
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);
    final leaderPaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final lbl in labels) {
      final clampedY = lbl.adjustedY.clamp(topPad + 4.0, maxAllowedY);

      // Draw subtle connecting leader line if label shifted by more than 2px
      if ((clampedY - lbl.originY).abs() > 2.0) {
        leaderPaint.color = lbl.color.withValues(alpha: 0.5);
        canvas.drawLine(
          Offset(lbl.originX + 1.0, lbl.originY),
          Offset(lbl.x - 1.0, clampedY),
          leaderPaint,
        );
      }

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

      // Background pill for pristine legibility against gridlines
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(lbl.x - 1, clampedY - tp.height / 2 - 1, tp.width + 2, tp.height + 2),
        const Radius.circular(2),
      );
      canvas.drawRRect(bgRect, Paint()..color = const Color(0xE616161B));

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
      if (hiddenMoves.contains(curve.uciMove)) continue;
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
        oldDelegate.highlightedUciMove != highlightedUciMove ||
        !setEquals(oldDelegate.hiddenMoves, hiddenMoves);
  }
}

class _CurveEndLabel {
  final String san;
  final Color color;
  final double originX;
  final double originY;
  final double x;
  final double y;
  late double adjustedY;

  _CurveEndLabel({
    required this.san,
    required this.color,
    required this.originX,
    required this.originY,
    required this.x,
    required this.y,
  }) {
    adjustedY = y;
  }
}

/// Mathematically rigorous Fritsch-Carlson Monotone Cubic Spline interpolation.
///
/// Guarantees:
/// 1. Passes exactly through each sample point (C0 continuity).
/// 2. Smooth tangent transitions between segments (C1 continuity).
/// 3. Monotonicity-preserving: eliminates overshoot, undershoot, and unphysical
///    oscillations between discrete probability samples.
class MonotoneCubicSpline {
  static Path computePath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points[0].dx, points[0].dy);
    if (points.length == 1) return path;

    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    final n = points.length;
    // Step 1: Compute secant slopes
    final dx = List<double>.filled(n - 1, 0.0);
    final dy = List<double>.filled(n - 1, 0.0);
    final slopes = List<double>.filled(n - 1, 0.0);

    for (int i = 0; i < n - 1; i++) {
      dx[i] = points[i + 1].dx - points[i].dx;
      dy[i] = points[i + 1].dy - points[i].dy;
      slopes[i] = dx[i] == 0.0 ? 0.0 : dy[i] / dx[i];
    }

    // Step 2: Initialize tangents
    final m = List<double>.filled(n, 0.0);
    m[0] = slopes[0];
    m[n - 1] = slopes[n - 2];

    for (int i = 1; i < n - 1; i++) {
      if (slopes[i - 1] * slopes[i] <= 0.0) {
        m[i] = 0.0;
      } else {
        final h0 = dx[i - 1];
        final h1 = dx[i];
        if (h0 + h1 != 0.0) {
          m[i] = (h0 * slopes[i] + h1 * slopes[i - 1]) / (h0 + h1);
        } else {
          m[i] = (slopes[i - 1] + slopes[i]) / 2.0;
        }
      }
    }

    // Step 3: Fritsch-Carlson monotonicity check & adjustment
    for (int i = 0; i < n - 1; i++) {
      if (slopes[i] == 0.0) {
        m[i] = 0.0;
        m[i + 1] = 0.0;
      } else {
        final alpha = m[i] / slopes[i];
        final beta = m[i + 1] / slopes[i];
        if (alpha < 0.0) m[i] = 0.0;
        if (beta < 0.0) m[i + 1] = 0.0;

        final sumSquares = alpha * alpha + beta * beta;
        if (sumSquares > 9.0) {
          final tau = 3.0 / math.sqrt(sumSquares);
          m[i] = tau * alpha * slopes[i];
          m[i + 1] = tau * beta * slopes[i];
        }
      }
    }

    // Step 4: Construct cubic Bézier segments
    for (int i = 0; i < n - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final segmentDx = dx[i];
      final cp1x = p0.dx + segmentDx / 3.0;
      final cp1y = p0.dy + m[i] * segmentDx / 3.0;
      final cp2x = p1.dx - segmentDx / 3.0;
      final cp2y = p1.dy - m[i + 1] * segmentDx / 3.0;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p1.dx, p1.dy);
    }

    return path;
  }
}
