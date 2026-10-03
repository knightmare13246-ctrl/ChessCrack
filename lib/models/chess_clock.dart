import 'dart:async';
import 'package:flutter/foundation.dart';
import 'chess_time_control.dart';

enum ClockSide {
  white,
  black,
}

class ChessClockState {
  final int whiteRemainingMs;
  final int blackRemainingMs;
  final ClockSide activeSide;
  final bool isTicking;
  final bool isFlagged;
  final ClockSide? flaggedSide;

  const ChessClockState({
    required this.whiteRemainingMs,
    required this.blackRemainingMs,
    required this.activeSide,
    required this.isTicking,
    required this.isFlagged,
    this.flaggedSide,
  });

  String formatTime(ClockSide side) {
    final ms = side == ClockSide.white ? whiteRemainingMs : blackRemainingMs;
    if (ms <= 0) return '0:00';
    // Sub-second precision for low time (< 10 seconds)
    if (ms < 10000) {
      final wholeSecs = ms ~/ 1000;
      final tenths = ((ms % 1000) / 100).floor();
      return '$wholeSecs.$tenths';
    }
    final totalSecs = (ms / 1000).ceil();
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    final secStr = secs.toString().padLeft(2, '0');
    if (mins >= 60) {
      final hours = mins ~/ 60;
      final remMins = (mins % 60).toString().padLeft(2, '0');
      return '$hours:$remMins:$secStr';
    }
    return '$mins:$secStr';
  }

  ChessClockState copyWith({
    int? whiteRemainingMs,
    int? blackRemainingMs,
    ClockSide? activeSide,
    bool? isTicking,
    bool? isFlagged,
    ClockSide? flaggedSide,
  }) {
    return ChessClockState(
      whiteRemainingMs: whiteRemainingMs ?? this.whiteRemainingMs,
      blackRemainingMs: blackRemainingMs ?? this.blackRemainingMs,
      activeSide: activeSide ?? this.activeSide,
      isTicking: isTicking ?? this.isTicking,
      isFlagged: isFlagged ?? this.isFlagged,
      flaggedSide: flaggedSide ?? this.flaggedSide,
    );
  }
}

class ChessClock {
  final ChessTimeControl timeControl;
  final void Function(ClockSide flaggedSide)? onFlagged;

  late int _whiteMs;
  late int _blackMs;
  ClockSide _activeSide = ClockSide.white;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  late final ValueNotifier<ChessClockState> notifier;

  bool _isFlagged = false;
  ClockSide? _flaggedSide;

  ChessClock({
    required this.timeControl,
    this.onFlagged,
  }) {
    _whiteMs = timeControl.baseSeconds * 1000;
    _blackMs = timeControl.baseSeconds * 1000;
    notifier = ValueNotifier<ChessClockState>(_buildState(isTicking: false));
  }

  ChessClockState get currentState => notifier.value;

  ChessClockState _buildState({required bool isTicking}) {
    int w = _whiteMs;
    int b = _blackMs;

    if (isTicking && !timeControl.isUnlimited) {
      final elapsed = _stopwatch.elapsedMilliseconds;
      if (_activeSide == ClockSide.white) {
        w = (_whiteMs - elapsed).clamp(0, 999999999);
      } else {
        b = (_blackMs - elapsed).clamp(0, 999999999);
      }
    }

    return ChessClockState(
      whiteRemainingMs: w,
      blackRemainingMs: b,
      activeSide: _activeSide,
      isTicking: isTicking,
      isFlagged: _isFlagged,
      flaggedSide: _flaggedSide,
    );
  }

  void start(ClockSide side) {
    if (timeControl.isUnlimited || _isFlagged) return;
    _activeSide = side;
    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    notifier.value = _buildState(isTicking: true);
  }

  void switchTurn({required ClockSide newActiveSide}) {
    if (timeControl.isUnlimited || _isFlagged) {
      _activeSide = newActiveSide;
      notifier.value = _buildState(isTicking: false);
      return;
    }

    // Capture elapsed time on current side
    final elapsed = _stopwatch.elapsedMilliseconds;
    _stopwatch.reset();

    if (_activeSide == ClockSide.white) {
      _whiteMs = (_whiteMs - elapsed).clamp(0, 999999999);
      if (_whiteMs > 0) {
        _whiteMs += timeControl.incrementSeconds * 1000;
      }
    } else {
      _blackMs = (_blackMs - elapsed).clamp(0, 999999999);
      if (_blackMs > 0) {
        _blackMs += timeControl.incrementSeconds * 1000;
      }
    }

    _activeSide = newActiveSide;
    _stopwatch.start();
    notifier.value = _buildState(isTicking: true);
  }

  void pause() {
    if (!_stopwatch.isRunning) return;
    final elapsed = _stopwatch.elapsedMilliseconds;
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;

    if (_activeSide == ClockSide.white) {
      _whiteMs = (_whiteMs - elapsed).clamp(0, 999999999);
    } else {
      _blackMs = (_blackMs - elapsed).clamp(0, 999999999);
    }

    notifier.value = _buildState(isTicking: false);
  }

  void resume() {
    if (timeControl.isUnlimited || _isFlagged || _stopwatch.isRunning) return;
    _stopwatch.reset();
    _stopwatch.start();
    _startTicker();
    notifier.value = _buildState(isTicking: true);
  }

  void stop() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    notifier.value = _buildState(isTicking: false);
  }

  void reset() {
    _stopwatch.stop();
    _stopwatch.reset();
    _ticker?.cancel();
    _ticker = null;
    _isFlagged = false;
    _flaggedSide = null;
    _whiteMs = timeControl.baseSeconds * 1000;
    _blackMs = timeControl.baseSeconds * 1000;
    _activeSide = ClockSide.white;
    notifier.value = _buildState(isTicking: false);
  }

  void _startTicker() {
    _ticker?.cancel();
    // 100ms UI ticker interval to keep clock responsive without burdening the event loop
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
  }

  void _onTick() {
    if (timeControl.isUnlimited || !_stopwatch.isRunning) return;

    final elapsed = _stopwatch.elapsedMilliseconds;
    int currentMs;
    if (_activeSide == ClockSide.white) {
      currentMs = _whiteMs - elapsed;
    } else {
      currentMs = _blackMs - elapsed;
    }

    if (currentMs <= 0) {
      _isFlagged = true;
      _flaggedSide = _activeSide;
      stop();
      if (_activeSide == ClockSide.white) {
        _whiteMs = 0;
      } else {
        _blackMs = 0;
      }
      notifier.value = _buildState(isTicking: false);
      onFlagged?.call(_activeSide);
      return;
    }

    notifier.value = _buildState(isTicking: true);
  }

  void dispose() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    notifier.dispose();
  }
}
