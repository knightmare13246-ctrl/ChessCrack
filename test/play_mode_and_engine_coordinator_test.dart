import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/controllers/maia_thinking_controller.dart';
import 'package:nibbler_chess/models/chess_clock.dart';
import 'package:nibbler_chess/models/chess_game_record.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/chess_time_control.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/models/uci_option.dart';
import 'package:nibbler_chess/services/engine_coordinator.dart';
import 'package:nibbler_chess/services/pgn_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. EngineCoordinator Exclusive Lease Arbitration', () {
    test('Ensures mutual exclusion and single owner at any time', () async {
      final coordinator = EngineCoordinator();

      // Acquire Analysis lease
      final lease1 = await coordinator.acquireLease(EngineLeaseType.analysis);
      expect(coordinator.activeLeaseType, equals(EngineLeaseType.analysis));
      expect(coordinator.isLeaseValid(lease1), isTrue);

      // Acquire Play lease - transitions cleanly
      final lease2 = await coordinator.acquireLease(EngineLeaseType.play);
      expect(coordinator.activeLeaseType, equals(EngineLeaseType.play));
      expect(coordinator.isLeaseValid(lease1), isFalse);
      expect(coordinator.isLeaseValid(lease2), isTrue);

      // Ephemeral Hint lease
      final lease3 = await coordinator.acquireLease(EngineLeaseType.hint);
      expect(coordinator.activeLeaseType, equals(EngineLeaseType.hint));
      expect(coordinator.isLeaseValid(lease2), isFalse);
      expect(coordinator.isLeaseValid(lease3), isTrue);

      // Release hint lease
      await coordinator.releaseLease(lease3);
      expect(coordinator.activeLeaseType, equals(EngineLeaseType.none));

      // Re-acquire analysis
      final lease4 = await coordinator.acquireLease(EngineLeaseType.analysis);
      expect(coordinator.activeLeaseType, equals(EngineLeaseType.analysis));
      expect(coordinator.isLeaseValid(lease4), isTrue);

      await coordinator.releaseLease(lease4);
      expect(coordinator.activeLeaseType, equals(EngineLeaseType.none));
    });
  });

  group('2. UciOption Parsing & Verification', () {
    test('Parses UCI_LimitStrength check option', () {
      const line = 'option name UCI_LimitStrength type check default false';
      final opt = UciOption.parse(line);
      expect(opt, isNotNull);
      expect(opt!.name, equals('UCI_LimitStrength'));
      expect(opt.type, equals(UciOptionType.check));
      expect(opt.defaultValue, equals('false'));
    });

    test('Parses UCI_Elo spin option with min and max bounds', () {
      const line = 'option name UCI_Elo type spin default 1320 min 1320 max 3190';
      final opt = UciOption.parse(line);
      expect(opt, isNotNull);
      expect(opt!.name, equals('UCI_Elo'));
      expect(opt.type, equals(UciOptionType.spin));
      expect(opt.defaultValue, equals('1320'));
      expect(opt.min, equals(1320));
      expect(opt.max, equals(3190));
    });

    test('Parses Move Overhead with spaces in name', () {
      const line = 'option name Move Overhead type spin default 10 min 0 max 5000';
      final opt = UciOption.parse(line);
      expect(opt, isNotNull);
      expect(opt!.name, equals('Move Overhead'));
      expect(opt.type, equals(UciOptionType.spin));
      expect(opt.min, equals(0));
      expect(opt.max, equals(5000));
    });
  });

  group('3. ChessTimeControl Model & Presets', () {
    test('Provides standard presets with accurate base and increment', () {
      expect(ChessTimeControl.hyperbullet30s.baseSeconds, equals(30));
      expect(ChessTimeControl.hyperbullet30s.incrementSeconds, equals(0));

      expect(ChessTimeControl.blitz3_2.baseSeconds, equals(180));
      expect(ChessTimeControl.blitz3_2.incrementSeconds, equals(2));

      expect(ChessTimeControl.rapid15_10.baseSeconds, equals(900));
      expect(ChessTimeControl.rapid15_10.incrementSeconds, equals(10));

      expect(ChessTimeControl.unlimitedPreset.isUnlimited, isTrue);
    });

    test('Custom time control generation and JSON serialization', () {
      final custom = ChessTimeControl.custom(baseMinutes: 7, incrementSeconds: 5);
      expect(custom.baseSeconds, equals(420));
      expect(custom.incrementSeconds, equals(5));

      final json = custom.toJson();
      final revived = ChessTimeControl.fromJson(json);
      expect(revived, equals(custom));
    });
  });

  group('4. Monotonic ChessClock Logic', () {
    test('Monotonic remaining time calculation and turn switching', () async {
      final tc = ChessTimeControl.custom(baseMinutes: 1, incrementSeconds: 2);
      bool flagged = false;
      final clock = ChessClock(
        timeControl: tc,
        onFlagged: (_) => flagged = true,
      );

      expect(clock.currentState.whiteRemainingMs, equals(60000));
      expect(clock.currentState.blackRemainingMs, equals(60000));
      expect(clock.currentState.isTicking, isFalse);

      // Start White's clock
      clock.start(ClockSide.white);
      expect(clock.currentState.isTicking, isTrue);
      expect(clock.currentState.activeSide, equals(ClockSide.white));

      await Future.delayed(const Duration(milliseconds: 150));

      // Switch to Black: White gains 2000ms increment
      clock.switchTurn(newActiveSide: ClockSide.black);
      expect(clock.currentState.activeSide, equals(ClockSide.black));
      expect(clock.currentState.whiteRemainingMs, greaterThan(60000 - 300));
      expect(clock.currentState.whiteRemainingMs, lessThanOrEqualTo(62000));

      clock.stop();
      expect(clock.currentState.isTicking, isFalse);
      expect(flagged, isFalse);
      clock.dispose();
    });

    test('Clock formatting produces sub-second precision under 10 seconds', () {
      const state = ChessClockState(
        whiteRemainingMs: 5400,
        blackRemainingMs: 125000,
        activeSide: ClockSide.white,
        isTicking: true,
        isFlagged: false,
      );

      expect(state.formatTime(ClockSide.white), equals('5.4'));
      expect(state.formatTime(ClockSide.black), equals('2:05'));
    });
  });

  group('5. Maia Thinking Controller', () {
    test('Calculates zero delay for instant profile', () {
      final controller = MaiaThinkingController();
      final delay = controller.calculateThinkingDelay(
        profile: MaiaThinkingProfile.instant,
        moveNumber: 10,
      );
      expect(delay, equals(Duration.zero));
    });

    test('Calculates natural delay bounded between 350ms and 900ms', () {
      final controller = MaiaThinkingController();
      for (int i = 0; i < 20; i++) {
        final delay = controller.calculateThinkingDelay(
          profile: MaiaThinkingProfile.natural,
          moveNumber: i + 1,
        );
        expect(delay.inMilliseconds, greaterThanOrEqualTo(350));
        expect(delay.inMilliseconds, lessThanOrEqualTo(900));
      }
    });

    test('Respects cancellation token immediately', () async {
      final controller = MaiaThinkingController();
      final cancelToken = CancellationToken();

      final stopwatch = Stopwatch()..start();
      final future = controller.paceMove(
        profile: MaiaThinkingProfile.humanLike,
        moveNumber: 15,
        cancellationToken: cancelToken,
      );

      // Cancel after 20ms
      await Future.delayed(const Duration(milliseconds: 20));
      cancelToken.cancel();
      await future;
      stopwatch.stop();

      // Ensure cancelled without waiting full human-like duration (>1200ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(400));
    });
  });

  group('6. ChessPosition Insufficient Material Detection', () {
    test('Detects King vs King as insufficient material', () {
      final pos = ChessPosition.fromFen('8/8/8/4k3/8/8/8/4K3 w - - 0 1');
      expect(pos.isInsufficientMaterial(), isTrue);
    });

    test('Detects King + Knight vs King as insufficient material', () {
      final pos = ChessPosition.fromFen('8/8/8/4k3/8/5N2/8/4K3 w - - 0 1');
      expect(pos.isInsufficientMaterial(), isTrue);
    });

    test('Detects King + Bishop vs King as insufficient material', () {
      final pos = ChessPosition.fromFen('8/8/8/4k3/8/5B2/8/4K3 w - - 0 1');
      expect(pos.isInsufficientMaterial(), isTrue);
    });

    test('Position with Pawns is NOT insufficient material', () {
      final pos = ChessPosition.fromFen('8/8/8/4k3/4P3/8/8/4K3 b - - 0 1');
      expect(pos.isInsufficientMaterial(), isFalse);
    });
  });

  group('7. ChessGameRecord & PGN Serialization', () {
    test('Serializes and deserializes game metadata cleanly', () {
      final record = ChessGameRecord(
        id: 'game_123456',
        date: DateTime(2026, 10, 3, 11, 30),
        whitePlayer: 'User',
        blackPlayer: 'Stockfish (Elo 1600)',
        userSide: 'white',
        result: '1-0',
        terminationReason: GameTerminationReason.checkmate,
        timeControl: ChessTimeControl.blitz5_3,
        moveCount: 42,
        finalFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        pgn: '[Event "Test"]\n\n1. e4 e5 1-0',
      );

      final json = record.toJson();
      final revived = ChessGameRecord.fromJson(json);

      expect(revived.id, equals(record.id));
      expect(revived.whitePlayer, equals(record.whitePlayer));
      expect(revived.blackPlayer, equals(record.blackPlayer));
      expect(revived.result, equals('1-0'));
      expect(revived.terminationReason, equals(GameTerminationReason.checkmate));
      expect(revived.readableTermination, equals('Checkmate'));
      expect(revived.timeControl.name, equals(record.timeControl.name));
    });

    test('Parses game record PGN into navigable GameTree with children', () {
      final record = ChessGameRecord(
        id: 'game_123456',
        date: DateTime(2026, 10, 3, 11, 30),
        whitePlayer: 'User',
        blackPlayer: 'Stockfish (Elo 1600)',
        userSide: 'white',
        result: '0-1',
        terminationReason: GameTerminationReason.resignation,
        timeControl: ChessTimeControl.blitz5_3,
        moveCount: 2,
        finalFen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        pgn: '''[Event "ChessCrack Play"]
[Site "ChessCrack Android"]
[Date "2026.10.03"]
[Round "1"]
[White "User"]
[Black "Stockfish (Elo limit 1500)"]
[Result "0-1"]
[TimeControl "5 min"]
[Termination "resignation"]

1. e4 e5 0-1''',
      );

      final tree = PgnParser.parse(record.pgn);
      expect(tree.root.children, isNotEmpty);
      expect(tree.root.children.first.move?.san, equals('e4'));
      expect(tree.root.children.first.children.first.move?.san, equals('e5'));
    });
  });
}
