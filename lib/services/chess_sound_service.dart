import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/chess_position.dart';
import '../models/chess_move.dart';

/// Semantic chess audio events adhering to authentic chess UI conventions.
enum ChessSoundEvent {
  move,
  capture,
  check,
  castle,
  promote,
  checkmate,
  gameEnd,
  stalemate,
  gameStart,
  illegalMove,
}

/// Centralized sound service strictly utilizing canonical Lichess public audio resources.
/// Audio assets are sourced directly from upstream Lichess repositories (lichess-org/lila and lichess-org/mobile).
class ChessSoundService {
  static final ChessSoundService _instance = ChessSoundService._internal();
  factory ChessSoundService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  String activeTheme = 'standard';
  bool isEnabled = true;
  double volume = 1.0;

  ChessSoundService._internal() {
    _initAudio();
  }

  void _initAudio() {
    try {
      _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
    } catch (_) {}
  }

  /// Sets audio volume between 0.0 (silent) and 1.0 (full).
  void setVolume(double val) {
    volume = val.clamp(0.0, 1.0);
    try {
      _player.setVolume(volume);
    } catch (_) {}
  }

  /// Evaluates move semantics and resulting board position to determine the authentic chess sound event.
  ChessSoundEvent determineSoundEvent({
    required ChessMove move,
    required ChessPosition resultingPosition,
    bool isCheckmate = false,
    bool isStalemate = false,
  }) {
    if (isCheckmate || resultingPosition.isCheckmate() || (move.san != null && move.san!.contains('#'))) {
      return ChessSoundEvent.checkmate;
    } else if (isStalemate || resultingPosition.isStalemate()) {
      return ChessSoundEvent.stalemate;
    } else if (resultingPosition.isCheck() || (move.san != null && move.san!.contains('+'))) {
      return ChessSoundEvent.check;
    } else if (move.isCastling) {
      return ChessSoundEvent.castle;
    } else if (move.promotion != null) {
      return ChessSoundEvent.promote;
    } else if (move.isCapture || (move.san != null && move.san!.contains('x'))) {
      return ChessSoundEvent.capture;
    } else {
      return ChessSoundEvent.move;
    }
  }

  /// Evaluates move semantics and resulting board position to play the authentic chess audio cue.
  /// Follows canonical Lichess sound logic:
  /// - Checkmate: Game end alert / checkmate cue
  /// - Stalemate: Game end cue
  /// - Check: Check alert cue
  /// - Castling: Castling acoustic cue
  /// - Promotion: Piece promotion cue
  /// - Capture: Capture piece hit cue
  /// - Normal move: Standard piece placement cue
  Future<void> playMoveSound({
    required ChessMove move,
    required ChessPosition resultingPosition,
    bool isCheckmate = false,
    bool isStalemate = false,
  }) async {
    if (!isEnabled || activeTheme == 'silent') return;

    final event = determineSoundEvent(
      move: move,
      resultingPosition: resultingPosition,
      isCheckmate: isCheckmate,
      isStalemate: isStalemate,
    );
    await playSound(event);
  }

  /// Plays the canonical Lichess sound asset for the specified chess event.
  Future<void> playSound(ChessSoundEvent event) async {
    if (!isEnabled || activeTheme == 'silent') return;

    // Haptic feedback matching event severity
    try {
      if (event == ChessSoundEvent.capture ||
          event == ChessSoundEvent.check ||
          event == ChessSoundEvent.checkmate) {
        HapticFeedback.mediumImpact();
      } else if (event == ChessSoundEvent.illegalMove) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}

    final soundFileName = getSoundFileName(event);

    try {
      await _player.stop();
      await _player.setVolume(volume);
      // Attempt to load from active sound theme, fallback to standard if not present
      try {
        await _player.play(AssetSource('sounds/$activeTheme/$soundFileName'));
      } catch (_) {
        await _player.play(AssetSource('sounds/standard/$soundFileName'));
      }
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Strict mapping to official Lichess audio filenames in assets/sounds/
  String getSoundFileName(ChessSoundEvent event) {
    switch (event) {
      case ChessSoundEvent.move:
        return 'move.mp3';
      case ChessSoundEvent.capture:
        return 'capture.mp3';
      case ChessSoundEvent.check:
        return 'check.mp3';
      case ChessSoundEvent.castle:
        return 'castle.mp3';
      case ChessSoundEvent.promote:
        return 'promote.mp3';
      case ChessSoundEvent.checkmate:
      case ChessSoundEvent.gameEnd:
      case ChessSoundEvent.stalemate:
      case ChessSoundEvent.gameStart:
        return 'dong.mp3';
      case ChessSoundEvent.illegalMove:
        return 'error.mp3';
    }
  }

  void dispose() {
    try {
      _player.dispose();
    } catch (_) {}
  }
}

/// Backward compatibility alias
typedef SoundService = ChessSoundService;
