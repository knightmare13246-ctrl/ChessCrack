import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/pv_continuation.dart';
import 'package:nibbler_chess/services/pv_continuation_simulator.dart';

void main() {
  group('PvContinuationSimulator Tests', () {
    const testColor = Color(0xFF4CAF50);

    test('Simulate Knight Maneuver: Ng1-f3-g5-f7', () {
      final pos = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      // PV: Nf3 Nc6 Ng5 h6 Nxf7
      final pvMoves = ['g1f3', 'b8c6', 'f3g5', 'h7h6', 'g5f7'];

      final planAll = PvContinuationSimulator.simulate(
        initialPosition: pos,
        pvUciMoves: pvMoves,
        maxPlies: 6,
        baseColor: testColor,
        filter: PvContinuationFilter.all,
      );

      expect(planAll.isNotEmpty, isTrue);
      // Entire plan has 5 moves (ply 0 candidate + 4 continuation moves)
      expect(planAll.arrows.length, equals(5));

      // Root candidate move (ply 0)
      expect(planAll.arrows[0].plyIndex, equals(0));
      expect(planAll.arrows[0].from.algebraic, equals('g1'));
      expect(planAll.arrows[0].to.algebraic, equals('f3'));

      // Continuation plies (ply > 0)
      final continuationOnly = planAll.continuationOnly;
      expect(continuationOnly.length, equals(4));

      // Check first continuation move (ply 1: Nc6)
      final step1 = continuationOnly[0];
      expect(step1.plyIndex, equals(1));
      expect(step1.from.algebraic, equals('b8'));
      expect(step1.to.algebraic, equals('c6'));
      expect(step1.isOpponent, isTrue);

      // Check second continuation move (ply 2: Ng5)
      final step2 = continuationOnly[1];
      expect(step2.plyIndex, equals(2));
      expect(step2.from.algebraic, equals('f3'));
      expect(step2.to.algebraic, equals('g5'));
      expect(step2.isOpponent, isFalse);

      // Check third continuation move (ply 3: h6)
      final step3 = continuationOnly[2];
      expect(step3.plyIndex, equals(3));
      expect(step3.from.algebraic, equals('h7'));
      expect(step3.to.algebraic, equals('h6'));
      expect(step3.isOpponent, isTrue);

      // Check fourth continuation move (ply 4: Nxf7)
      final step4 = continuationOnly[3];
      expect(step4.plyIndex, equals(4));
      expect(step4.from.algebraic, equals('g5'));
      expect(step4.to.algebraic, equals('f7'));
      expect(step4.isOpponent, isFalse);
    });

    test('Friendly only filter isolates friendly continuation moves', () {
      final pos = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      final pvMoves = ['g1f3', 'b8c6', 'f3g5', 'h7h6', 'g5f7'];

      final planFriendly = PvContinuationSimulator.simulate(
        initialPosition: pos,
        pvUciMoves: pvMoves,
        maxPlies: 6,
        baseColor: testColor,
        filter: PvContinuationFilter.friendlyOnly,
      );

      expect(planFriendly.isNotEmpty, isTrue);
      // Entire plan has 3 moves (ply 0: Nf3, ply 2: Ng5, ply 4: Nxf7)
      expect(planFriendly.arrows.length, equals(3));
      expect(planFriendly.arrows.every((a) => !a.isOpponent), isTrue);

      final continuationOnly = planFriendly.continuationOnly;
      expect(continuationOnly.length, equals(2));
      expect(continuationOnly[0].from.algebraic, equals('f3'));
      expect(continuationOnly[0].to.algebraic, equals('g5'));
      expect(continuationOnly[1].from.algebraic, equals('g5'));
      expect(continuationOnly[1].to.algebraic, equals('f7'));
    });

    test('Simulate Queen Maneuver: Qd1-h5-e5', () {
      // 1. e4 e5 2. Qh5 Nc6 3. Qxe5+
      final pos = ChessPosition.fromFen('rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2');
      final pvMoves = ['d1h5', 'b8c6', 'h5e5'];

      final plan = PvContinuationSimulator.simulate(
        initialPosition: pos,
        pvUciMoves: pvMoves,
        maxPlies: 4,
        baseColor: testColor,
        filter: PvContinuationFilter.all,
      );

      expect(plan.isNotEmpty, isTrue);
      // Entire plan has 3 moves
      expect(plan.arrows.length, equals(3));
      final continuationOnly = plan.continuationOnly;
      expect(continuationOnly.length, equals(2));
      expect(continuationOnly[0].from.algebraic, equals('b8'));
      expect(continuationOnly[0].to.algebraic, equals('c6'));
      expect(continuationOnly[1].from.algebraic, equals('h5'));
      expect(continuationOnly[1].to.algebraic, equals('e5'));
    });

    test('Castling and promotion simulation works accurately', () {
      // White can castle kingside, black plays d6, white castles O-O (e1g1)
      final pos = ChessPosition.fromFen('rnbqk2r/pppp1ppp/5n2/4p3/1b2P3/3B1N2/PPPP1PPP/RNBQK2R w KQkq - 4 4');
      final pvMoves = ['e1g1', 'd7d6', 'c2c3'];

      final plan = PvContinuationSimulator.simulate(
        initialPosition: pos,
        pvUciMoves: pvMoves,
        maxPlies: 4,
        baseColor: testColor,
        filter: PvContinuationFilter.all,
      );

      expect(plan.isNotEmpty, isTrue);
      expect(plan.arrows.length, equals(3));
      final continuationOnly = plan.continuationOnly;
      expect(continuationOnly.length, equals(2));
      expect(continuationOnly[0].from.algebraic, equals('d7'));
      expect(continuationOnly[0].to.algebraic, equals('d6'));
      expect(continuationOnly[1].from.algebraic, equals('c2'));
      expect(continuationOnly[1].to.algebraic, equals('c3'));
    });

    test('Chain gracefully terminates if engine provides illegal move in continuation', () {
      final pos = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      // e2e4 is legal, e7e5 is legal, e4e6 is illegal!
      final pvMoves = ['e2e4', 'e7e5', 'e4e6', 'd7d5'];

      final plan = PvContinuationSimulator.simulate(
        initialPosition: pos,
        pvUciMoves: pvMoves,
        maxPlies: 6,
        baseColor: testColor,
        filter: PvContinuationFilter.all,
      );

      expect(plan.isNotEmpty, isTrue);
      // Entire plan: e2e4 (ply 0), e7e5 (ply 1). At ply 2, e4e6 is illegal, so chain terminates cleanly
      expect(plan.arrows.length, equals(2));
      final continuationOnly = plan.continuationOnly;
      expect(continuationOnly.length, equals(1));
      expect(continuationOnly[0].from.algebraic, equals('e7'));
      expect(continuationOnly[0].to.algebraic, equals('e5'));
    });

    test('Black to move correctly differentiates friendly and opponent', () {
      // 1. e4 (Black to move)
      final pos = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1');
      // Black plays c7c5, white plays g1f3, black plays d7d6
      final pvMoves = ['c7c5', 'g1f3', 'd7d6'];

      final plan = PvContinuationSimulator.simulate(
        initialPosition: pos,
        pvUciMoves: pvMoves,
        maxPlies: 4,
        baseColor: testColor,
        filter: PvContinuationFilter.all,
      );

      expect(plan.isNotEmpty, isTrue);
      expect(plan.arrows.length, equals(3));
      final continuationOnly = plan.continuationOnly;
      expect(continuationOnly.length, equals(2));

      // Ply 1: White moves (Nf3). For Black-to-move root, White is opponent!
      expect(continuationOnly[0].isOpponent, isTrue);
      expect(continuationOnly[0].from.algebraic, equals('g1'));
      expect(continuationOnly[0].to.algebraic, equals('f3'));

      // Ply 2: Black moves (d6). For Black-to-move root, Black is friendly!
      expect(continuationOnly[1].isOpponent, isFalse);
      expect(continuationOnly[1].from.algebraic, equals('d7'));
      expect(continuationOnly[1].to.algebraic, equals('d6'));
    });
  });
}
