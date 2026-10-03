import 'dart:async';
import 'dart:math' as math;
import '../models/engine_settings.dart';

/// Pacing controller for Maia moves to simulate human thought rhythm
/// without modifying or tampering with the move itself.
class MaiaThinkingController {
  final math.Random _random = math.Random();

  /// Calculates the human-like delay based on profile, move number, and complexity.
  Duration calculateThinkingDelay({
    required MaiaThinkingProfile profile,
    required int moveNumber,
    bool isCheck = false,
    bool isCapture = false,
  }) {
    switch (profile) {
      case MaiaThinkingProfile.instant:
        return Duration.zero;

      case MaiaThinkingProfile.natural:
        // 350ms to 900ms jitter
        final baseMs = 350 + _random.nextInt(550);
        return Duration(milliseconds: baseMs);

      case MaiaThinkingProfile.humanLike:
        // Base delay between 1200ms and 2800ms
        int delayMs = 1200 + _random.nextInt(1600);

        // Opening moves (first 5 moves) are often played faster
        if (moveNumber <= 5) {
          delayMs = (delayMs * 0.6).round();
        } else if (isCheck || isCapture) {
          // Tactical moments get a slight extra consideration
          delayMs += 300 + _random.nextInt(500);
        }

        // Clamp between 400ms and 4500ms
        return Duration(milliseconds: delayMs.clamp(400, 4500));
    }
  }

  /// Delays execution for the computed thinking duration, respecting cancellation.
  Future<void> paceMove({
    required MaiaThinkingProfile profile,
    required int moveNumber,
    bool isCheck = false,
    bool isCapture = false,
    CancellationToken? cancellationToken,
  }) async {
    final delay = calculateThinkingDelay(
      profile: profile,
      moveNumber: moveNumber,
      isCheck: isCheck,
      isCapture: isCapture,
    );

    if (delay == Duration.zero) return;

    final completer = Completer<void>();
    Timer? timer;

    void onCancel() {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    cancellationToken?.addListener(onCancel);

    timer = Timer(delay, () {
      cancellationToken?.removeListener(onCancel);
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    return completer.future;
  }
}

/// Simple listener-based token for instant cancellation of delays.
class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }
}
