import 'dart:convert';
import 'dart:io';
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

    test('Tokens match Python reference for after 1.e4', () {
      final posAfterE4 = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1');
      final tokens = MaiaTokenizer.tokenizePosition(posAfterE4);

      final nonZero = <int, int>{};
      for (int sq = 0; sq < 64; sq++) {
        for (int p = 0; p < 12; p++) {
          if (tokens[sq * 12 + p] > 0) {
            nonZero[sq] = p;
          }
        }
      }

      // Check e5 square (sq 36) has piece 6 (opponent pawn)
      expect(nonZero[36], equals(6));
      // Check rank 1 (sq 0..7) has active player back rank (pieces 3, 1, 2, 4, 5, 2, 1, 3)
      expect(nonZero[0], equals(3)); // R
      expect(nonZero[1], equals(1)); // N
      expect(nonZero[2], equals(2)); // B
      expect(nonZero[3], equals(4)); // Q
      expect(nonZero[4], equals(5)); // K
      // Check rank 2 (sq 8..15) has active player pawns (piece 0)
      for (int f = 0; f < 8; f++) {
        expect(nonZero[8 + f], equals(0));
      }
    });

    test('Decode real ONNX logits for after 1.e4', () {
      final posAfterE4 = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1');
      final jsonStr = File('test_logits.json').readAsStringSync();
      final List<dynamic> raw = jsonDecode(jsonStr);
      final logits = raw.cast<double>();

      final probs = MaiaTokenizer.decodePolicyLogitsFromUciList(
        logits: logits,
        legalMovesUci: posAfterE4.legalMoves.map((m) => m.uci).toList(),
        isBlack: true,
      );

      final sorted = probs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      print('Dart Top 5 after 1.e4: ${sorted.take(5).map((e) => "${e.key}: ${(e.value * 100).toStringAsFixed(2)}%").join(", ")}');

      expect(sorted.first.key, equals('e7e5'));
      expect(sorted.first.value, greaterThan(0.50));
    });
  });
}
