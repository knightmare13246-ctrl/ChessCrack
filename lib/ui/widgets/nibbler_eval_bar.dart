import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../controllers/evaluation_controller.dart';
import '../../models/engine_analysis.dart';
import '../../models/normalized_evaluation.dart';

/// Accurate, stable, Lichess-style chess evaluation bar.
///
/// Isolated via RepaintBoundary and backed by EvaluationController for:
/// - Exact mathematical expected score (50% equality, 100% White win, 0% Black win)
/// - Symmetrical perspective handling
/// - Adaptive smoothing (micro-jitter deadband, rapid tactical swing response)
/// - Explicit mate handling (M<N> / -M<N> anchored to rails)
/// - Position revision safety (no animation bleeding between moves)
/// - Hard reset on Engine OFF
class NibblerEvalBar extends StatefulWidget {
  final NormalizedEvaluation? evaluation;
  final ValueListenable<NormalizedEvaluation>? evaluationNotifier;
  final double? whiteWinPercentage;
  final bool isFlipped;
  final double width;
  final double height;

  const NibblerEvalBar({
    super.key,
    this.evaluation,
    this.evaluationNotifier,
    this.whiteWinPercentage,
    this.isFlipped = false,
    this.width = 20.0,
    required this.height,
  });

  @override
  State<NibblerEvalBar> createState() => _NibblerEvalBarState();
}

class _NibblerEvalBarState extends State<NibblerEvalBar>
    with SingleTickerProviderStateMixin {
  late final EvaluationController _controller;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controller = EvaluationController(animController: _animController);
    _controller.addListener(_onControllerTick);

    if (widget.evaluationNotifier != null) {
      widget.evaluationNotifier!.addListener(_onNotifierUpdate);
      _controller.updateEvaluation(widget.evaluationNotifier!.value);
    } else if (widget.evaluation != null) {
      _controller.updateEvaluation(widget.evaluation!);
    } else if (widget.whiteWinPercentage != null) {
      _controller.updateEvaluation(NormalizedEvaluation.neutral.copyWith(
        whiteExpectedScore: widget.whiteWinPercentage!,
        isEngineEnabled: true,
      ));
    }
  }

  @override
  void didUpdateWidget(covariant NibblerEvalBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.evaluationNotifier != oldWidget.evaluationNotifier) {
      oldWidget.evaluationNotifier?.removeListener(_onNotifierUpdate);
      widget.evaluationNotifier?.addListener(_onNotifierUpdate);
      if (widget.evaluationNotifier != null) {
        _controller.updateEvaluation(widget.evaluationNotifier!.value);
      }
    } else if (widget.evaluation != oldWidget.evaluation) {
      if (widget.evaluation != null) {
        _controller.updateEvaluation(widget.evaluation!);
      }
    } else if (widget.whiteWinPercentage != oldWidget.whiteWinPercentage &&
        widget.whiteWinPercentage != null) {
      _controller.updateEvaluation(NormalizedEvaluation.neutral.copyWith(
        whiteExpectedScore: widget.whiteWinPercentage!,
        isEngineEnabled: true,
      ));
    }
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  void _onNotifierUpdate() {
    if (widget.evaluationNotifier != null) {
      _controller.updateEvaluation(widget.evaluationNotifier!.value);
    }
  }

  @override
  void dispose() {
    widget.evaluationNotifier?.removeListener(_onNotifierUpdate);
    _controller.removeListener(_onControllerTick);
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double whiteFactor = _controller.displayFactor;
    final bool isFlipped = widget.isFlipped;
    final String label = _controller.barLabel;

    // In chess convention:
    // When unflipped: White is at bottom, Black is at top.
    // When flipped: Black is at bottom, White is at top.
    final Alignment whiteAlignment =
        isFlipped ? Alignment.topCenter : Alignment.bottomCenter;

    // Determine label placement based on which player has the advantage
    // (Lichess places the evaluation text on the winning side's territory)
    final bool whiteAdvantage = whiteFactor >= 0.50;
    final bool placeLabelOnWhite = whiteAdvantage
        ? (whiteFactor >= 0.12)
        : (whiteFactor >= 0.88);

    final Alignment labelAlignment;
    final Color labelColor;

    if (placeLabelOnWhite) {
      // Label sits on the light White portion
      labelAlignment = isFlipped ? Alignment.topCenter : Alignment.bottomCenter;
      labelColor = const Color(0xFF1E1E1E);
    } else {
      // Label sits on the dark Black portion
      labelAlignment = isFlipped ? Alignment.bottomCenter : Alignment.topCenter;
      labelColor = const Color(0xFFF0F0F0);
    }

    return RepaintBoundary(
      child: IgnorePointer(
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B), // Black's territory
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white12, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                // White's territory (fills proportionally)
                Align(
                  alignment: whiteAlignment,
                  child: FractionallySizedBox(
                    widthFactor: 1.0,
                    heightFactor: whiteFactor,
                    child: Container(color: const Color(0xFFECECEC)),
                  ),
                ),
                // Lichess-style numeric evaluation / mate label
                Positioned.fill(
                  child: Align(
                    alignment: labelAlignment,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 3.0,
                        horizontal: 1.0,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: labelAlignment,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: -0.4,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
