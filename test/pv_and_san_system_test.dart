import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/draft_variation.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/game_tree.dart';

void main() {
  group('SANFormatter - Standard FIDE SAN Generation', () {
    test('Pawn moves: no piece letter, proper captures and promotions', () {
      final initial = ChessPosition.initial();
      final e4Move = initial.findLegalMoveByUci('e2e4')!;
      expect(SANFormatter.formatSan(initial, e4Move), equals('e4'));

      final posAfterE4 = initial.applyMove(e4Move);
      final d5Move = posAfterE4.findLegalMoveByUci('d7d5')!;
      expect(SANFormatter.formatSan(posAfterE4, d5Move), equals('d5'));

      final posAfterD5 = posAfterE4.applyMove(d5Move);
      final exd5Move = posAfterD5.findLegalMoveByUci('e4d5')!;
      expect(SANFormatter.formatSan(posAfterD5, exd5Move), equals('exd5'));
    });

    test('Knights: always uppercase N, not k', () {
      final initial = ChessPosition.initial();
      final nf3 = initial.findLegalMoveByUci('g1f3')!;
      expect(SANFormatter.formatSan(initial, nf3), equals('Nf3'));

      final nc3 = initial.findLegalMoveByUci('b1c3')!;
      expect(SANFormatter.formatSan(initial, nc3), equals('Nc3'));
    });

    test('Castling: O-O and O-O-O', () {
      // Position where White can castle kingside: 1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5
      final castlePos = ChessPosition.fromFen(
        'r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
      );
      final kingside = castlePos.findLegalMoveByUci('e1g1')!;
      expect(SANFormatter.formatSan(castlePos, kingside), equals('O-O'));
    });

    test('Checks (+) and Checkmates (#)', () {
      // Scholar's mate position: Qxf7#
      final scholarsMatePos = ChessPosition.fromFen(
        'r1bqkb1r/pppp1ppp/2n5/4p3/2B1n3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 0 5',
      );
      final qxf7 = scholarsMatePos.findLegalMoveByUci('f3f7')!;
      expect(SANFormatter.formatSan(scholarsMatePos, qxf7), equals('Qxf7#'));

      // Check position: e4 e5 Qh5 Nc6 Bc4 Nf6 Qxf7+ (with King escaping)
      final checkPos = ChessPosition.fromFen(
        'r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 2 3',
      );
      final qxf7Check = checkPos.findLegalMoveByUci('h5f7')!;
      expect(SANFormatter.formatSan(checkPos, qxf7Check), equals('Qxf7#'));
    });

    test('Disambiguation: file disambiguation when two knights can move to same square', () {
      // Both knights on b1 and f3 can reach empty d2: Nbd2 or Nfd2
      final twoKnightsPos = ChessPosition.fromFen(
        'rnbqkb1r/pppppppp/5n2/8/3P4/5N2/PPP1PPPP/RNBQKB1R w KQkq - 1 3',
      );
      final nbd2 = twoKnightsPos.findLegalMoveByUci('b1d2')!;
      expect(SANFormatter.formatSan(twoKnightsPos, nbd2), equals('Nbd2'));

      final nfd2 = twoKnightsPos.findLegalMoveByUci('f3d2')!;
      expect(SANFormatter.formatSan(twoKnightsPos, nfd2), equals('Nfd2'));
    });
  });

  group('SANFormatter - Unicode Figurine Formatting', () {
    test('White pieces get White Unicode figurines', () {
      expect(
        SANFormatter.toFigurine('Nf3', PieceColor.white, PieceType.knight),
        equals('♘f3'),
      );
      expect(
        SANFormatter.toFigurine('Qh5+', PieceColor.white, PieceType.queen),
        equals('♕h5+'),
      );
      expect(
        SANFormatter.toFigurine('Bc4', PieceColor.white, PieceType.bishop),
        equals('♗c4'),
      );
      expect(
        SANFormatter.toFigurine('Ra1', PieceColor.white, PieceType.rook),
        equals('♖a1'),
      );
      expect(
        SANFormatter.toFigurine('Ke2', PieceColor.white, PieceType.king),
        equals('♔e2'),
      );
    });

    test('Black pieces get Black Unicode figurines', () {
      expect(
        SANFormatter.toFigurine('Nf6', PieceColor.black, PieceType.knight),
        equals('♞f6'),
      );
      expect(
        SANFormatter.toFigurine('Kh7', PieceColor.black, PieceType.king),
        equals('♚h7'),
      );
      expect(
        SANFormatter.toFigurine('Qd7', PieceColor.black, PieceType.queen),
        equals('♛d7'),
      );
      expect(
        SANFormatter.toFigurine('Bg7', PieceColor.black, PieceType.bishop),
        equals('♝g7'),
      );
    });

    test('Pawns and Castling do NOT have piece figurines at start', () {
      expect(
        SANFormatter.toFigurine('e4', PieceColor.white, PieceType.pawn),
        equals('e4'),
      );
      expect(
        SANFormatter.toFigurine('exd5', PieceColor.white, PieceType.pawn),
        equals('exd5'),
      );
      expect(
        SANFormatter.toFigurine('a7', PieceColor.black, PieceType.pawn),
        equals('a7'),
      );
      expect(
        SANFormatter.toFigurine('O-O', PieceColor.white, PieceType.king),
        equals('O-O'),
      );
    });

    test('Pawn promotions convert =Q to =♕ or =♛', () {
      expect(
        SANFormatter.toFigurine(
          'e8=Q#',
          PieceColor.white,
          PieceType.pawn,
          promotion: PieceType.queen,
        ),
        equals('e8=♕#'),
      );
      expect(
        SANFormatter.toFigurine(
          'd1=Q',
          PieceColor.black,
          PieceType.pawn,
          promotion: PieceType.queen,
        ),
        equals('d1=♛'),
      );
    });
  });

  group('SANFormatter - Move Prefix Formatting', () {
    test(r'White move always receives "$N. "', () {
      expect(SANFormatter.formatMovePrefix(1, true), equals('1. '));
      expect(SANFormatter.formatMovePrefix(38, true), equals('38. '));
    });

    test(r'Black starting move receives "$N... "', () {
      expect(
        SANFormatter.formatMovePrefix(37, false, isFirstMoveInVariation: true),
        equals('37... '),
      );
    });

    test('Black continuation move receives empty prefix', () {
      expect(
        SANFormatter.formatMovePrefix(38, false, isFirstMoveInVariation: false),
        equals(''),
      );
    });
  });

  group('SANFormatter - PV Line Parsing & Snapshots', () {
    test('parsePvLine generates sequential snapshots with O(1) navigation', () {
      final initial = ChessPosition.initial();
      final uciMoves = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'];

      final pvItems = SANFormatter.parsePvLine(initial, uciMoves);

      expect(pvItems.length, equals(6));

      // Move 0: 1. e4
      expect(pvItems[0].moveNumber, equals(1));
      expect(pvItems[0].san, equals('e4'));
      expect(pvItems[0].figurineSan, equals('e4'));
      expect(pvItems[0].color, equals(PieceColor.white));
      expect(pvItems[0].positionBefore.toFen(), equals(initial.toFen()));
      expect(pvItems[0].positionAfter.pieceAt(Square.fromAlgebraic('e4'))?.type, equals(PieceType.pawn));

      // Move 1: 1... e5
      expect(pvItems[1].moveNumber, equals(1));
      expect(pvItems[1].san, equals('e5'));
      expect(pvItems[1].figurineSan, equals('e5'));
      expect(pvItems[1].color, equals(PieceColor.black));

      // Move 2: 2. Nf3
      expect(pvItems[2].moveNumber, equals(2));
      expect(pvItems[2].san, equals('Nf3'));
      expect(pvItems[2].figurineSan, equals('♘f3'));
      expect(pvItems[2].color, equals(PieceColor.white));

      // Move 3: 2... Nc6
      expect(pvItems[3].moveNumber, equals(2));
      expect(pvItems[3].san, equals('Nc6'));
      expect(pvItems[3].figurineSan, equals('♞c6'));
      expect(pvItems[3].color, equals(PieceColor.black));

      // Move 4: 3. Bc4
      expect(pvItems[4].san, equals('Bc4'));
      expect(pvItems[4].figurineSan, equals('♗c4'));

      // Move 5: 3... Nf6
      expect(pvItems[5].san, equals('Nf6'));
      expect(pvItems[5].figurineSan, equals('♞f6'));
    });

    test('parsePvLine stops gracefully on invalid or illegal UCI move', () {
      final initial = ChessPosition.initial();
      final uciMoves = ['e2e4', 'e7e5', 'a1a8', 'g1f3']; // a1a8 is illegal for rook through pawns

      final pvItems = SANFormatter.parsePvLine(initial, uciMoves);
      expect(pvItems.length, equals(2));
    });
  });

  group('DraftVariation Architecture & State Separation', () {
    test('DraftVariation provides instant O(1) position access and navigation', () {
      final initial = ChessPosition.initial();
      final uciMoves = ['e2e4', 'e7e5', 'g1f3', 'b8c6'];
      final pvItems = SANFormatter.parsePvLine(initial, uciMoves);

      final pvLine = PvLine(
        multipv: 1,
        winPercentage: 52.0,
        whiteWinPercentage: 52.0,
        movesUci: uciMoves,
        pvMoves: pvItems,
        startFen: initial.toFen(),
      );

      final draft = DraftVariation(
        startFen: initial.toFen(),
        rootPosition: initial,
        pvLine: pvLine,
        selectedMoveIndex: 2, // 2. Nf3
      );

      // Current position is position after 2. Nf3
      expect(draft.currentMove?.san, equals('Nf3'));
      expect(draft.currentPosition.pieceAt(Square.fromAlgebraic('f3'))?.type, equals(PieceType.knight));

      // Jump to root: selectedMoveIndex = -1
      final atRoot = draft.goToStart();
      expect(atRoot.selectedMoveIndex, equals(-1));
      expect(atRoot.currentPosition.toFen(), equals(initial.toFen()));
      expect(atRoot.currentMove, isNull);

      // Step forward to move 0 (e4)
      final step0 = atRoot.stepForward();
      expect(step0.selectedMoveIndex, equals(0));
      expect(step0.currentMove?.san, equals('e4'));

      // Step to end: move 3 (Nc6)
      final atEnd = draft.goToEnd();
      expect(atEnd.selectedMoveIndex, equals(3));
      expect(atEnd.currentMove?.san, equals('Nc6'));
      expect(atEnd.canStepForward, isFalse);
    });

    test('DraftVariation does NOT mutate GameTree until committed', () {
      final tree = GameTree.initial();
      final initialFen = tree.currentNode.position.toFen();

      final uciMoves = ['e2e4', 'e7e5', 'g1f3'];
      final pvItems = SANFormatter.parsePvLine(tree.currentNode.position, uciMoves);

      final pvLine = PvLine(
        multipv: 1,
        winPercentage: 53.0,
        whiteWinPercentage: 53.0,
        movesUci: uciMoves,
        pvMoves: pvItems,
        startFen: initialFen,
      );

      // User browses to move 2 (Nf3)
      final draft = DraftVariation(
        startFen: initialFen,
        rootPosition: tree.currentNode.position,
        pvLine: pvLine,
        selectedMoveIndex: 2,
      );

      // Verify draft position is after Nf3
      expect(draft.currentPosition.toFen(), isNot(equals(initialFen)));

      // CRITICAL: Verify GameTree is completely unchanged!
      expect(tree.currentNode.position.toFen(), equals(initialFen));
      expect(tree.currentNode.hasChildren, isFalse);

      // User exits variation (discards draft): tree is still untouched
      expect(tree.root.children.isEmpty, isTrue);

      // User commits variation up to move 1 (e4, e5):
      final movesToCommit = draft.pvLine.pvMoves.take(2);
      for (final pvItem in movesToCommit) {
        tree.addMove(pvItem.move);
      }

      // Now tree has the committed variation
      expect(tree.currentNode.move?.san, equals('e5'));
      expect(tree.root.children.length, equals(1));
      expect(tree.root.children.first.move?.san, equals('e4'));
    });
  });
}
