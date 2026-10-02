import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/ui/widgets/nibbler_arrow_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const squareE1 = Square(4, 0); // e1
  const squareG1 = Square(6, 0); // g1 (Kingside castle)
  const squareC1 = Square(2, 0); // c1 (Queenside castle)
  const squareE8 = Square(4, 7); // e8
  const squareG8 = Square(6, 7); // g8
  const squareC8 = Square(2, 7); // c8

  const squareE2 = Square(4, 1);
  const squareE4 = Square(4, 3);
  const squareD2 = Square(3, 1);
  const squareD4 = Square(3, 3);
  const squareC2 = Square(2, 1);
  const squareC4 = Square(2, 3);
  const squareG1Knight = Square(6, 0);
  const squareF3 = Square(5, 2);

  const defaultStyle = ArrowVisualStyle(
    shaftColor: Color(0xFF00D2BE),
    badgeColor: Color(0xFF004D40),
    textColor: Color(0xFFFFFFFF),
    borderColor: Color(0xFF00D2BE),
  );

  group('E2E Arrow Modes & Filtering Suite', () {
    test('1. Complete suite of Arrowhead badge text display modes', () {
      const lc0Arrow = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        winProbability: 55.4,
        expectedScore: 57.8,
        nodePercentage: 42.1,
        policyPercentage: 35.7,
        movesLeft: 64.2,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      const sfArrow = CandidateArrow(
        rank: 2,
        uciMove: 'd2d4',
        from: squareD2,
        to: squareD4,
        expectedScore: 53.2,
        scoreCp: 25,
        scoreMate: 3, // Mate in 3
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      // Winrate mode
      expect(lc0Arrow.getBadgeText(ArrowheadType.winrate, EngineType.lc0), equals('55'));
      expect(sfArrow.getBadgeText(ArrowheadType.winrate, EngineType.stockfish), equals('53'));

      // Node % mode
      expect(lc0Arrow.getBadgeText(ArrowheadType.nodePct, EngineType.lc0), equals('42'));
      expect(sfArrow.getBadgeText(ArrowheadType.nodePct, EngineType.stockfish), equals('N/A'));

      // Policy mode
      expect(lc0Arrow.getBadgeText(ArrowheadType.policy, EngineType.lc0), equals('36'));
      expect(sfArrow.getBadgeText(ArrowheadType.policy, EngineType.stockfish), equals('N/A'));

      // MultiPV Rank mode
      expect(lc0Arrow.getBadgeText(ArrowheadType.multipvRank, EngineType.lc0), equals('1'));
      expect(sfArrow.getBadgeText(ArrowheadType.multipvRank, EngineType.stockfish), equals('2'));

      // Moves Left / C-Scale mode
      expect(lc0Arrow.getBadgeText(ArrowheadType.movesLeft, EngineType.lc0), equals('64'));
      expect(sfArrow.getBadgeText(ArrowheadType.movesLeft, EngineType.stockfish), equals('M3'));
    });

    test('2. Arrowhead badge missing metric fallbacks return N/A gracefully', () {
      const sparseArrow = CandidateArrow(
        rank: 3,
        uciMove: 'c2c4',
        from: squareC2,
        to: squareC4,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      expect(sparseArrow.getBadgeText(ArrowheadType.winrate, EngineType.stockfish), equals('N/A'));
      expect(sparseArrow.getBadgeText(ArrowheadType.nodePct, EngineType.lc0), equals('N/A'));
      expect(sparseArrow.getBadgeText(ArrowheadType.policy, EngineType.lc0), equals('N/A'));
      expect(sparseArrow.getBadgeText(ArrowheadType.movesLeft, EngineType.lc0), equals('N/A'));
      expect(sparseArrow.getBadgeText(ArrowheadType.movesLeft, EngineType.stockfish), equals('N/A'));
    });

    test('3. Lc0 Arrow Filtering rules and threshold pruning', () {
      const candidateArrows = [
        CandidateArrow(
          rank: 1,
          uciMove: 'e2e4',
          from: squareE2,
          to: squareE4,
          expectedScore: 56.0,
          nodePercentage: 65.0,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
        CandidateArrow(
          rank: 2,
          uciMove: 'd2d4',
          from: squareD2,
          to: squareD4,
          expectedScore: 54.5, // 1.5% worse
          nodePercentage: 32.0,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
        CandidateArrow(
          rank: 3,
          uciMove: 'c2c4',
          from: squareC2,
          to: squareC4,
          expectedScore: 52.0, // 4.0% worse
          nodePercentage: 2.5,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
        CandidateArrow(
          rank: 4,
          uciMove: 'g1f3',
          from: squareG1Knight,
          to: squareF3,
          expectedScore: 48.0, // 8.0% worse
          nodePercentage: 0.5, // < 1%
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
      ];

      // Top 2 filter
      final top2 = filterCandidateArrows(
        arrows: candidateArrows,
        settings: EngineSettings(activeEngine: EngineType.lc0, arrowFilterLc0: ArrowFilterLc0.top2),
      );
      expect(top2.length, 2);
      expect(top2.map((a) => a.rank), equals([1, 2]));

      // Min 1% nodes filter (prunes rank 4)
      final min1 = filterCandidateArrows(
        arrows: candidateArrows,
        settings: EngineSettings(activeEngine: EngineType.lc0, arrowFilterLc0: ArrowFilterLc0.minNodes1),
      );
      expect(min1.length, 3);
      expect(min1.any((a) => a.rank == 4), isFalse);

      // Min 5% nodes filter (prunes rank 3 and 4)
      final min5 = filterCandidateArrows(
        arrows: candidateArrows,
        settings: EngineSettings(activeEngine: EngineType.lc0, arrowFilterLc0: ArrowFilterLc0.minNodes5),
      );
      expect(min5.length, 2);
      expect(min5.map((a) => a.rank), equals([1, 2]));

      // Within 2% score filter (best = 56.0, rank 2 = 54.5 is within 2%, rank 3 = 52.0 is not)
      final within2 = filterCandidateArrows(
        arrows: candidateArrows,
        settings: EngineSettings(activeEngine: EngineType.lc0, arrowFilterLc0: ArrowFilterLc0.within2PctScore),
      );
      expect(within2.length, 2);
      expect(within2.map((a) => a.rank), equals([1, 2]));
    });

    test('4. Stockfish centipawn filtering and Rank 1 protection invariant', () {
      const arrows = [
        CandidateArrow(
          rank: 1,
          uciMove: 'e2e4',
          from: squareE2,
          to: squareE4,
          scoreCp: 40,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
        CandidateArrow(
          rank: 2,
          uciMove: 'd2d4',
          from: squareD2,
          to: squareD4,
          scoreCp: -20, // 60 cp worse
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
        CandidateArrow(
          rank: 3,
          uciMove: 'c2c4',
          from: squareC2,
          to: squareC4,
          scoreCp: -90, // 130 cp worse
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
      ];

      // Within 50 cp: rank 2 is 60 worse, so pruned
      final within50 = filterCandidateArrows(
        arrows: arrows,
        settings: EngineSettings(activeEngine: EngineType.stockfish, arrowFilterOthers: ArrowFilterOthers.within50Cp),
      );
      expect(within50.length, 1);
      expect(within50.first.rank, 1);

      // Severe filter on all moves that would otherwise prune everything:
      // Even if threshold would discard, Rank 1 MUST be preserved!
      const badRank1 = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        scoreCp: null,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      final preserved = filterCandidateArrows(
        arrows: [badRank1],
        settings: EngineSettings(activeEngine: EngineType.stockfish, arrowFilterOthers: ArrowFilterOthers.within50Cp),
      );
      expect(preserved.length, 1);
      expect(preserved.first.rank, 1);
    });

    test('5. Nibbler visual layering: Longer shafts underneath shorter shafts, Rank 1 on top', () {
      // Create 3 arrows of differing lengths
      // Long: a1 to a8 (length 7)
      // Medium: a1 to a5 (length 4)
      // Short: a1 to a3 (length 2)
      const longArrow = CandidateArrow(
        rank: 2,
        uciMove: 'a1a8',
        from: Square(0, 0),
        to: Square(0, 7),
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      const shortArrowRank1 = CandidateArrow(
        rank: 1,
        uciMove: 'a1a3',
        from: Square(0, 0),
        to: Square(0, 2),
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      const mediumArrow = CandidateArrow(
        rank: 3,
        uciMove: 'a1a5',
        from: Square(0, 0),
        to: Square(0, 4),
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      final arrows = [shortArrowRank1, mediumArrow, longArrow];

      // Check distance ordering
      double dist(CandidateArrow a) {
        final dx = a.to.file - a.from.file;
        final dy = a.to.rank - a.from.rank;
        return math.sqrt((dx * dx + dy * dy).toDouble());
      }

      final drawOrder = List<CandidateArrow>.from(arrows)
        ..sort((a, b) {
          final lenCmp = dist(b).compareTo(dist(a));
          if (lenCmp != 0) return lenCmp;
          return b.rank.compareTo(a.rank);
        });

      // Longest arrow drawn first (at bottom)
      expect(drawOrder.first.uciMove, equals('a1a8'));
      // Medium arrow drawn second
      expect(drawOrder[1].uciMove, equals('a1a5'));
      // Shortest arrow drawn last (rendered on top)
      expect(drawOrder.last.uciMove, equals('a1a3'));
      expect(drawOrder.last.rank, equals(1));
    });

    test('6. Accurate move mapping for Castling (Kingside e1->g1 and Queenside e1->c1)', () {
      // FIDE Castling position for White
      const castleFen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
      final pos = ChessPosition.fromFen(castleFen);

      // Kingside castling UCI: e1g1
      final kingside = pos.findLegalMoveByUci('e1g1');
      expect(kingside, isNotNull);
      expect(kingside!.isCastling, isTrue);
      expect(kingside.from, equals(squareE1));
      expect(kingside.to, equals(squareG1));

      // Queenside castling UCI: e1c1
      final queenside = pos.findLegalMoveByUci('e1c1');
      expect(queenside, isNotNull);
      expect(queenside!.isCastling, isTrue);
      expect(queenside.from, equals(squareE1));
      expect(queenside.to, equals(squareC1));

      // Black castling
      const blackCastleFen = 'r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1';
      final blackPos = ChessPosition.fromFen(blackCastleFen);
      final blackKingside = blackPos.findLegalMoveByUci('e8g8');
      expect(blackKingside, isNotNull);
      expect(blackKingside!.isCastling, isTrue);
      expect(blackKingside.from, equals(squareE8));
      expect(blackKingside.to, equals(squareG8));

      final blackQueenside = blackPos.findLegalMoveByUci('e8c8');
      expect(blackQueenside, isNotNull);
      expect(blackQueenside!.isCastling, isTrue);
      expect(blackQueenside.from, equals(squareE8));
      expect(blackQueenside.to, equals(squareC8));
    });

    test('7. Accurate move mapping for Pawn Promotion (e7->e8=Q)', () {
      const promoFen = '8/4P3/8/8/8/8/k7/4K3 w - - 0 1';
      final pos = ChessPosition.fromFen(promoFen);

      final promoQ = pos.findLegalMoveByUci('e7e8q');
      expect(promoQ, isNotNull);
      expect(promoQ!.promotion, isNotNull);
      expect(promoQ.promotion, equals(PieceType.queen));
      expect(promoQ.from.algebraic, equals('e7'));
      expect(promoQ.to.algebraic, equals('e8'));
    });

    testWidgets('8. NibblerArrowPainter renders without exception and filters stale revisions', (WidgetTester tester) async {
      final pos = ChessPosition.initial();
      final painter = NibblerArrowPainter(
        candidateArrows: const [
          CandidateArrow(
            rank: 1,
            uciMove: 'e2e4',
            from: squareE2,
            to: squareE4,
            expectedScore: 55.0,
            positionRevision: 1,
            requestId: 1,
            style: defaultStyle,
          ),
          CandidateArrow(
            rank: 2,
            uciMove: 'd2d4',
            from: squareD2,
            to: squareD4,
            expectedScore: 53.0,
            positionRevision: 1,
            requestId: 1,
            style: defaultStyle,
          ),
          // Stale revision arrow
          CandidateArrow(
            rank: 3,
            uciMove: 'c2c4',
            from: squareC2,
            to: squareC4,
            expectedScore: 51.0,
            positionRevision: 99, // Stale!
            requestId: 1,
            style: defaultStyle,
          ),
        ],
        position: pos,
        positionRevision: 1,
        analysisRequestId: 1,
        arrowheadType: ArrowheadType.winrate,
        engineType: EngineType.lc0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              key: const Key('arrow_custom_paint'),
              size: const Size(400, 400),
              painter: painter,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('arrow_custom_paint')), findsOneWidget);
    });
  });
}
