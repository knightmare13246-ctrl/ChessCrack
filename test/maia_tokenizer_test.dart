import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/services/maia_tokenizer.dart';

void main() {
  group('MaiaTokenizer Tests', () {
    test('Vocabulary has exactly 4352 moves', () {
      expect(MaiaTokenizer.totalMoves, equals(4352));
      expect(MaiaTokenizer.allMoves.length, equals(4352));
      expect(MaiaTokenizer.allMovesDict.length, equals(4352));
    });

    test('Mirror square and move logic', () {
      expect(MaiaTokenizer.mirrorSquare('e2'), equals('e7'));
      expect(MaiaTokenizer.mirrorSquare('e7'), equals('e2'));
      expect(MaiaTokenizer.mirrorSquare('a1'), equals('a8'));
      expect(MaiaTokenizer.mirrorSquare('h8'), equals('h1'));

      expect(MaiaTokenizer.mirrorMove('e2e4'), equals('e7e5'));
      expect(MaiaTokenizer.mirrorMove('g1f3'), equals('g8f6'));
      expect(MaiaTokenizer.mirrorMove('a7a8q'), equals('a2a1q'));
    });

    test('Initial position legal move count', () {
      final pos = ChessPosition.initial();
      final mask = MaiaTokenizer.getLegalMoveMask(pos);
      final legalCount = mask.where((m) => m).length;
      expect(legalCount, equals(20)); // 16 pawn moves + 4 knight moves

      final tokens = MaiaTokenizer.tokenizePosition(pos);
      expect(tokens.length, equals(64 * 12));
    });

    test('Policy decoding produces valid probability distribution', () {
      final pos = ChessPosition.initial();
      final dummyLogits = List<double>.filled(4352, 0.0);
      dummyLogits[MaiaTokenizer.allMovesDict['e2e4']!] = 2.0;
      dummyLogits[MaiaTokenizer.allMovesDict['d2d4']!] = 1.0;

      final probs = MaiaTokenizer.decodePolicyLogits(
        logits: dummyLogits,
        position: pos,
      );

      expect(probs.length, equals(20));
      double sum = probs.values.reduce((a, b) => a + b);
      expect((sum - 1.0).abs(), lessThan(1e-5));
      expect(probs['e2e4']! > probs['d2d4']!, isTrue);
    });

    test('Black to move mirroring in policy decoding', () {
      // 1. e4 e5
      final posAfterE4 = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1');
      final mask = MaiaTokenizer.getLegalMoveMask(posAfterE4);
      final legalCount = mask.where((m) => m).length;
      expect(legalCount, equals(20));

      final dummyLogits = List<double>.filled(4352, 0.0);
      // If black plays e7e5, from model perspective it's e2e4!
      dummyLogits[MaiaTokenizer.allMovesDict['e2e4']!] = 3.0;

      final probs = MaiaTokenizer.decodePolicyLogits(
        logits: dummyLogits,
        position: posAfterE4,
      );

      expect(probs.containsKey('e7e5'), isTrue);
      expect(probs['e7e5']!, greaterThan(0.5));
    });
  });
}
