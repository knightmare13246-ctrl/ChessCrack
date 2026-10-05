import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/candidate_arrow.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/utils/board_geometry.dart';
import 'package:nibbler_chess/utils/nibbler_badge_layout_engine.dart';

void main() {
  group('NibblerBadgeLayoutEngine Collision & Layout Suite', () {
    const boardSize = 400.0;
    final geo = BoardGeometry(boardSize: boardSize, isFlipped: false);
    final pos = ChessPosition.initial();

    CandidateArrow createCandidate({
      required int rank,
      required String uciMove,
      required Square from,
      required Square to,
      double winProbability = 0.50,
    }) {
      return CandidateArrow(
        rank: rank,
        uciMove: uciMove,
        from: from,
        to: to,
        winProbability: winProbability,
        positionRevision: 1,
        requestId: 1,
        style: const ArrowVisualStyle(
          shaftColor: Colors.amber,
          badgeColor: Colors.amber,
          textColor: Colors.black,
          borderColor: Colors.white,
        ),
      );
    }

    test('1 arrow produces valid placement within board bounds', () {
      final arrow = createCandidate(
        rank: 1,
        uciMove: 'e2e4',
        from: const Square(4, 1),
        to: const Square(4, 3),
      );

      final req = BadgeLayoutRequest(
        arrow: arrow,
        arrowStart: geo.getSquareCenter(const Square(4, 1)),
        arrowEnd: geo.getSquareCenter(const Square(4, 3)),
        arrowMid: geo.getSquareCenter(const Square(4, 2)),
        arrowAngle: -1.57,
        arrowHeadLength: 12.0,
        arrowHeadWidth: 14.0,
        badgeRadius: 16.0,
        width: 32.0,
        height: 32.0,
      );

      final result = NibblerBadgeLayoutEngine.layoutBadges(
        requests: [req],
        geometry: geo,
        position: pos,
      );

      expect(result.length, 1);
      final p = result.first;
      expect(geo.boardBounds.contains(p.center), isTrue);
      expect(geo.boardBounds.contains(p.boundingBox.topLeft), isTrue);
      expect(geo.boardBounds.contains(p.boundingBox.bottomRight), isTrue);
    });

    test('Multiple converging arrows NEVER overlap each other', () {
      // 4 arrows all converging or arriving near adjacent squares (d4, e4, f4, c4)
      final requests = <BadgeLayoutRequest>[
        BadgeLayoutRequest(
          arrow: createCandidate(
            rank: 1,
            uciMove: 'e2e4',
            from: const Square(4, 1),
            to: const Square(4, 3),
            winProbability: 0.55,
          ),
          arrowStart: geo.getSquareCenter(const Square(4, 1)),
          arrowEnd: geo.getSquareCenter(const Square(4, 3)),
          arrowMid: geo.getSquareCenter(const Square(4, 2)),
          arrowAngle: -1.57,
          arrowHeadLength: 12.0,
          arrowHeadWidth: 14.0,
          badgeRadius: 16.0,
          width: 34.0,
          height: 34.0,
        ),
        BadgeLayoutRequest(
          arrow: createCandidate(
            rank: 2,
            uciMove: 'd2d4',
            from: const Square(3, 1),
            to: const Square(3, 3),
            winProbability: 0.54,
          ),
          arrowStart: geo.getSquareCenter(const Square(3, 1)),
          arrowEnd: geo.getSquareCenter(const Square(3, 3)),
          arrowMid: geo.getSquareCenter(const Square(3, 2)),
          arrowAngle: -1.57,
          arrowHeadLength: 11.0,
          arrowHeadWidth: 13.0,
          badgeRadius: 15.0,
          width: 32.0,
          height: 32.0,
        ),
        BadgeLayoutRequest(
          arrow: createCandidate(
            rank: 3,
            uciMove: 'g1f3',
            from: const Square(6, 0),
            to: const Square(5, 2),
            winProbability: 0.53,
          ),
          arrowStart: geo.getSquareCenter(const Square(6, 0)),
          arrowEnd: geo.getSquareCenter(const Square(5, 2)),
          arrowMid: geo.getSquareCenter(const Square(6, 1)),
          arrowAngle: -2.0,
          arrowHeadLength: 10.0,
          arrowHeadWidth: 12.0,
          badgeRadius: 14.0,
          width: 30.0,
          height: 30.0,
        ),
        BadgeLayoutRequest(
          arrow: createCandidate(
            rank: 4,
            uciMove: 'c2c4',
            from: const Square(2, 1),
            to: const Square(2, 3),
            winProbability: 0.52,
          ),
          arrowStart: geo.getSquareCenter(const Square(2, 1)),
          arrowEnd: geo.getSquareCenter(const Square(2, 3)),
          arrowMid: geo.getSquareCenter(const Square(2, 2)),
          arrowAngle: -1.57,
          arrowHeadLength: 10.0,
          arrowHeadWidth: 12.0,
          badgeRadius: 14.0,
          width: 30.0,
          height: 30.0,
        ),
      ];

      final result = NibblerBadgeLayoutEngine.layoutBadges(
        requests: requests,
        geometry: geo,
        position: pos,
      );

      expect(result.length, 4);

      // Verify ZERO overlap between every single pair of badges
      for (int i = 0; i < result.length; i++) {
        for (int j = i + 1; j < result.length; j++) {
          final b1 = result[i].boundingBox;
          final b2 = result[j].boundingBox;
          final intersection = b1.intersect(b2);
          final hasOverlap = intersection.width > 0.001 && intersection.height > 0.001;
          expect(
            hasOverlap,
            isFalse,
            reason: 'Badge ${result[i].arrow.rank} (${result[i].arrow.uciMove}) overlapped Badge ${result[j].arrow.rank} (${result[j].arrow.uciMove})!\nb1: $b1\nb2: $b2\nintersect: $intersection',
          );
        }
      }

      // Verify board bounds containment
      for (final badge in result) {
        expect(badge.boundingBox.left >= 0, isTrue);
        expect(badge.boundingBox.right <= boardSize, isTrue);
        expect(badge.boundingBox.top >= 0, isTrue);
        expect(badge.boundingBox.bottom <= boardSize, isTrue);
      }
    });

    test('8 candidate arrows stress test produces zero overlaps and stays on board', () {
      final requests = <BadgeLayoutRequest>[];
      final moves = [
        ('e2e4', 1, const Square(4, 1), const Square(4, 3)),
        ('d2d4', 2, const Square(3, 1), const Square(3, 3)),
        ('g1f3', 3, const Square(6, 0), const Square(5, 2)),
        ('c2c4', 4, const Square(2, 1), const Square(2, 3)),
        ('b1c3', 5, const Square(1, 0), const Square(2, 2)),
        ('g2g3', 6, const Square(6, 1), const Square(6, 2)),
        ('b2b3', 7, const Square(1, 1), const Square(1, 2)),
        ('f2f4', 8, const Square(5, 1), const Square(5, 3)),
      ];

      for (final m in moves) {
        requests.add(BadgeLayoutRequest(
          arrow: createCandidate(
            rank: m.$2,
            uciMove: m.$1,
            from: m.$3,
            to: m.$4,
            winProbability: 0.50 + (9 - m.$2) * 0.01,
          ),
          arrowStart: geo.getSquareCenter(m.$3),
          arrowEnd: geo.getSquareCenter(m.$4),
          arrowMid: Offset(
            (geo.getSquareCenter(m.$3).dx + geo.getSquareCenter(m.$4).dx) / 2,
            (geo.getSquareCenter(m.$3).dy + geo.getSquareCenter(m.$4).dy) / 2,
          ),
          arrowAngle: -1.57,
          arrowHeadLength: 10.0,
          arrowHeadWidth: 12.0,
          badgeRadius: 14.0,
          width: 32.0,
          height: 32.0,
        ));
      }

      final result = NibblerBadgeLayoutEngine.layoutBadges(
        requests: requests,
        geometry: geo,
        position: pos,
      );

      expect(result.length, 8);

      // Verify every pair does not overlap
      for (int i = 0; i < result.length; i++) {
        for (int j = i + 1; j < result.length; j++) {
          final b1 = result[i].boundingBox;
          final b2 = result[j].boundingBox;
          final intersection = b1.intersect(b2);
          final hasOverlap = intersection.width > 0.001 && intersection.height > 0.001;
          expect(
            hasOverlap,
            isFalse,
            reason: 'Badge ${result[i].arrow.rank} overlapped Badge ${result[j].arrow.rank}',
          );
        }
      }

      // Verify board bounds containment
      for (final badge in result) {
        expect(badge.boundingBox.left >= 0, isTrue);
        expect(badge.boundingBox.right <= boardSize, isTrue);
        expect(badge.boundingBox.top >= 0, isTrue);
        expect(badge.boundingBox.bottom <= boardSize, isTrue);
      }
    });

    test('Flipped board (Black perspective) maintains boundary containment and zero overlaps', () {
      final flippedGeo = BoardGeometry(boardSize: boardSize, isFlipped: true);
      final requests = <BadgeLayoutRequest>[
        BadgeLayoutRequest(
          arrow: createCandidate(
            rank: 1,
            uciMove: 'e7e5',
            from: const Square(4, 6),
            to: const Square(4, 4),
            winProbability: 0.52,
          ),
          arrowStart: flippedGeo.getSquareCenter(const Square(4, 6)),
          arrowEnd: flippedGeo.getSquareCenter(const Square(4, 4)),
          arrowMid: flippedGeo.getSquareCenter(const Square(4, 5)),
          arrowAngle: 1.57,
          arrowHeadLength: 12.0,
          arrowHeadWidth: 14.0,
          badgeRadius: 16.0,
          width: 34.0,
          height: 34.0,
        ),
        BadgeLayoutRequest(
          arrow: createCandidate(
            rank: 2,
            uciMove: 'c7c5',
            from: const Square(2, 6),
            to: const Square(2, 4),
            winProbability: 0.51,
          ),
          arrowStart: flippedGeo.getSquareCenter(const Square(2, 6)),
          arrowEnd: flippedGeo.getSquareCenter(const Square(2, 4)),
          arrowMid: flippedGeo.getSquareCenter(const Square(2, 5)),
          arrowAngle: 1.57,
          arrowHeadLength: 11.0,
          arrowHeadWidth: 13.0,
          badgeRadius: 15.0,
          width: 32.0,
          height: 32.0,
        ),
      ];

      final result = NibblerBadgeLayoutEngine.layoutBadges(
        requests: requests,
        geometry: flippedGeo,
        position: pos,
      );

      expect(result.length, 2);
      expect(result[0].boundingBox.overlaps(result[1].boundingBox), isFalse);
      expect(result[0].boundingBox.left >= 0, isTrue);
      expect(result[0].boundingBox.right <= boardSize, isTrue);
      expect(result[1].boundingBox.left >= 0, isTrue);
      expect(result[1].boundingBox.right <= boardSize, isTrue);
    });
  });
}
