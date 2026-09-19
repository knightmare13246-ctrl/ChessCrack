import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/services/chess_sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  group('ChessSoundService Event Dispatch and Mapping Tests', () {
    late ChessSoundService soundService;

    setUp(() {
      soundService = ChessSoundService();
      soundService.isEnabled = true;
      soundService.activeTheme = 'standard';
      soundService.setVolume(1.0);
    });

    test('Default configuration is enabled with standard theme and 1.0 volume', () {
      expect(soundService.isEnabled, isTrue);
      expect(soundService.activeTheme, equals('standard'));
      expect(soundService.volume, equals(1.0));
    });

    test('Volume clamping works correctly between 0.0 and 1.0', () {
      soundService.setVolume(1.5);
      expect(soundService.volume, equals(1.0));

      soundService.setVolume(-0.5);
      expect(soundService.volume, equals(0.0));

      soundService.setVolume(0.75);
      expect(soundService.volume, equals(0.75));
    });

    test('Canonical Lichess sound filename mapping is authentic and complete', () {
      expect(soundService.getSoundFileName(ChessSoundEvent.move), equals('move.mp3'));
      expect(soundService.getSoundFileName(ChessSoundEvent.capture), equals('capture.mp3'));
      expect(soundService.getSoundFileName(ChessSoundEvent.check), equals('check.mp3'));
      expect(soundService.getSoundFileName(ChessSoundEvent.castle), equals('castle.mp3'));
      expect(soundService.getSoundFileName(ChessSoundEvent.promote), equals('promote.mp3'));
      expect(soundService.getSoundFileName(ChessSoundEvent.checkmate), equals('dong.mp3'));
      expect(soundService.getSoundFileName(ChessSoundEvent.gameEnd), equals('dong.mp3'));
      expect(soundService.getSoundFileName(ChessSoundEvent.stalemate), equals('dong.mp3'));
      expect(soundService.getSoundFileName(ChessSoundEvent.gameStart), equals('dong.mp3'));
      expect(soundService.getSoundFileName(ChessSoundEvent.illegalMove), equals('error.mp3'));
    });

    test('determineSoundEvent correctly resolves standard move', () {
      final pos = ChessPosition.initial();
      final move = pos.findLegalMoveByUci('e2e4')!;
      final nextPos = pos.applyMove(move);

      final event = soundService.determineSoundEvent(
        move: move,
        resultingPosition: nextPos,
      );
      expect(event, equals(ChessSoundEvent.move));
    });

    test('determineSoundEvent correctly resolves piece capture', () {
      const fen = 'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
      final pos = ChessPosition.fromFen(fen);
      final move = pos.findLegalMoveByUci('e4d5')!;
      expect(move.isCapture, isTrue);
      final nextPos = pos.applyMove(move);

      final event = soundService.determineSoundEvent(
        move: move,
        resultingPosition: nextPos,
      );
      expect(event, equals(ChessSoundEvent.capture));
    });

    test('determineSoundEvent correctly resolves checkmate', () {
      const fen = 'r1bqkb1r/pppp1ppp/2n5/4p3/2B1n3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 0 4';
      final pos = ChessPosition.fromFen(fen);
      final move = pos.findLegalMoveByUci('f3f7')!;
      final nextPos = pos.applyMove(move);
      expect(nextPos.isCheckmate(), isTrue);

      final event = soundService.determineSoundEvent(
        move: move,
        resultingPosition: nextPos,
      );
      expect(event, equals(ChessSoundEvent.checkmate));
    });

    test('determineSoundEvent correctly resolves check', () {
      const fen = 'rnbqkbnr/pppp1ppp/8/4p3/5PP1/8/PPPPP2P/RNBQKBNR b KQkq - 0 2';
      final pos = ChessPosition.fromFen(fen);
      final move = pos.findLegalMoveByUci('d8h4')!;
      final nextPos = pos.applyMove(move);
      expect(nextPos.isCheck(), isTrue);

      final event = soundService.determineSoundEvent(
        move: move,
        resultingPosition: nextPos,
      );
      expect(event, equals(ChessSoundEvent.checkmate)); // Scholar-style fool's mate is checkmate!
    });

    test('determineSoundEvent correctly resolves castling', () {
      const fen = 'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';
      final pos = ChessPosition.fromFen(fen);
      final move = pos.findLegalMoveByUci('e1g1')!;
      expect(move.isCastling, isTrue);
      final nextPos = pos.applyMove(move);

      final event = soundService.determineSoundEvent(
        move: move,
        resultingPosition: nextPos,
      );
      expect(event, equals(ChessSoundEvent.castle));
    });

    test('Disabled or silent sound service ignores playback without throwing', () async {
      soundService.isEnabled = false;
      await expectLater(soundService.playSound(ChessSoundEvent.move), completes);

      soundService.isEnabled = true;
      soundService.activeTheme = 'silent';
      await expectLater(soundService.playSound(ChessSoundEvent.move), completes);
    });
  });
}
