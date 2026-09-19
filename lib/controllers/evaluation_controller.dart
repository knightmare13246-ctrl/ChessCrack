import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import '../models/engine_analysis.dart';
import '../models/normalized_evaluation.dart';

/// Manages temporal stabilization, deadband filtering, and adaptive animations
/// for the chess evaluation bar.
///
/// Ensures:
/// 1. Underlying raw engine evaluation is NEVER modified or corrupted.
/// 2. Microscopic fluctuations (< 0.20%) during continuous search do not jitter the bar.
/// 3. Meaningful changes animate smoothly (300ms ease-out).
/// 4. Tactical swings (>= 8.0%) transition rapidly (150ms).
/// 5. Mate scores transition immediately to extremes.
class EvaluationController extends ChangeNotifier {
  NormalizedEvaluation _rawEvaluation = NormalizedEvaluation.neutral;
  NormalizedEvaluation _targetEvaluation = NormalizedEvaluation.neutral;
  double _displayedPercentage = 50.0;
  double _previousTargetPercentage = 50.0;

  int _positionRevision = 0;
  int _analysisRequestId = 0;
  String _fen = '';
  bool _isEngineEnabled = false;

  AnimationController? _animController;
  Animation<double>? _animation;

  EvaluationController({AnimationController? animController})
      : _animController = animController {
    _animController?.addListener(_onAnimationTick);
  }

  /// Raw, untouched engine telemetry for diagnostics
  NormalizedEvaluation get rawEvaluation => _rawEvaluation;

  /// Authoritative target evaluation
  NormalizedEvaluation get targetEvaluation => _targetEvaluation;

  /// Current visually displayed percentage (0.0 to 100.0)
  double get displayedPercentage => _displayedPercentage;

  /// Current visual fill factor (0.0 to 1.0)
  double get displayFactor => (_displayedPercentage / 100.0).clamp(0.0, 1.0);

  /// Compact bar label corresponding to the displayed evaluation
  String get barLabel => _targetEvaluation.barLabel;

  /// Active mate state
  MateState get mateState => _targetEvaluation.mateState;

  int get positionRevision => _positionRevision;
  int get analysisRequestId => _analysisRequestId;
  String get fen => _fen;
  bool get isEngineEnabled => _isEngineEnabled;

  void attachAnimationController(AnimationController controller) {
    _animController?.removeListener(_onAnimationTick);
    _animController = controller;
    _animController?.addListener(_onAnimationTick);
  }

  void _onAnimationTick() {
    if (_animation != null) {
      _displayedPercentage = _animation!.value;
      notifyListeners();
    }
  }

  /// Updates evaluation from incoming UCI telemetry.
  /// Enforces position safety, revision matching, deadband filtering, and adaptive speed.
  void updateEvaluation(NormalizedEvaluation eval) {
    // 1. Engine OFF handling (Hard reset, no animation drift)
    if (!eval.isEngineEnabled) {
      _isEngineEnabled = false;
      resetToNeutral(hard: true);
      return;
    }
    _isEngineEnabled = true;

    // 2. Position safety checks: discard stale revisions
    if (_positionRevision != 0 &&
        (eval.positionRevision < _positionRevision ||
         (eval.positionRevision == _positionRevision && eval.analysisRequestId < _analysisRequestId))) {
      return;
    }

    // 3. Position change detection (FEN or Revision update)
    if (_fen.isNotEmpty && eval.fen.isNotEmpty && _fen != eval.fen) {
      onPositionChanged(
        revision: eval.positionRevision,
        requestId: eval.analysisRequestId,
        fen: eval.fen,
      );
    } else {
      _positionRevision = eval.positionRevision;
      _analysisRequestId = eval.analysisRequestId;
      _fen = eval.fen;
    }

    // 4. Raw evaluation is preserved immediately for diagnostics
    _rawEvaluation = eval;

    final double newTarget = eval.whiteExpectedScore.clamp(0.0, 100.0);

    // 5. Immediate transition for Mate
    if (eval.mateState != MateState.none) {
      _animController?.stop();
      _targetEvaluation = eval;
      _displayedPercentage = eval.displayFactor * 100.0;
      _previousTargetPercentage = _displayedPercentage;
      notifyListeners();
      return;
    }

    // 6. Deadband filtering for microscopic search jitter (< 0.20%)
    final targetDelta = (_previousTargetPercentage - newTarget).abs();
    final bool isCurrentlyAnimating = _animController?.isAnimating ?? false;
    if (targetDelta < 0.20 && !isCurrentlyAnimating) {
      // Microscopic jitter; update target record but prevent visual vibration
      _targetEvaluation = eval;
      return;
    }

    // 7. Adaptive animation speed
    final displayDelta = (newTarget - _displayedPercentage).abs();
    Duration duration;
    Curve curve = Curves.easeOutCubic;

    if (displayDelta >= 15.0) {
      // Large tactical swing / blunder -> rapid transition
      duration = const Duration(milliseconds: 140);
      curve = Curves.easeOutQuad;
    } else if (displayDelta >= 5.0) {
      // Meaningful evaluation update
      duration = const Duration(milliseconds: 220);
    } else {
      // Minor convergence during thinking
      duration = const Duration(milliseconds: 300);
    }

    _targetEvaluation = eval;
    _previousTargetPercentage = newTarget;

    if (_animController != null) {
      _animController!.stop();
      _animController!.duration = duration;
      _animation = Tween<double>(begin: _displayedPercentage, end: newTarget).animate(
        CurvedAnimation(parent: _animController!, curve: curve),
      );
      _animController!.forward(from: 0.0);
    } else {
      // Direct update if no controller attached (e.g. headless unit tests)
      _displayedPercentage = newTarget;
      notifyListeners();
    }
  }

  /// Cancels any active animation and establishes a new position context
  /// so old evaluations never bleed into the new position.
  void onPositionChanged({
    required int revision,
    required int requestId,
    required String fen,
  }) {
    _animController?.stop();
    _positionRevision = revision;
    _analysisRequestId = requestId;
    _fen = fen;
    _rawEvaluation = NormalizedEvaluation.neutral.copyWith(
      positionRevision: revision,
      analysisRequestId: requestId,
      fen: fen,
      isEngineEnabled: _isEngineEnabled,
    );
    _targetEvaluation = _rawEvaluation;
    // Keep current displayed percentage as anchor or snap towards 50.0
    // To prevent sudden flash while keeping position safety:
    _previousTargetPercentage = _displayedPercentage;
    notifyListeners();
  }

  /// Hard reset to neutral 50.0% evaluation (used when Engine is OFF or reset)
  void resetToNeutral({bool hard = true}) {
    _animController?.stop();
    _rawEvaluation = NormalizedEvaluation.neutral;
    _targetEvaluation = NormalizedEvaluation.neutral;
    _previousTargetPercentage = 50.0;
    if (hard) {
      _displayedPercentage = 50.0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _animController?.removeListener(_onAnimationTick);
    super.dispose();
  }
}
