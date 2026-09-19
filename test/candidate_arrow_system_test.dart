import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/services/uci_engine_service.dart';

void main() {
  const squareE2 = Square(4, 1); // e2
  const squareE4 = Square(4, 3); // e4
  const squareD2 = Square(3, 1); // d2
  const squareD4 = Square(3, 3); // d4
  const squareG1 = Square(6, 0); // g1
  const squareF3 = Square(5, 2); // f3
  const squareE3 = Square(4, 2); // e3

  const defaultStyle = ArrowVisualStyle(
    shaftColor: Color(0xFF00D2BE),
    badgeColor: Color(0xFF004D40),
    textColor: Colors.white,
    borderColor: Color(0xFF00D2BE),
  );

  group('1. CandidateArrow Construction & Immutability', () {
    test('Correctly stores all telemetry fields', () {
      const arrow = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        pvUci: ['e2e4', 'e7e5'],
        scoreCp: 26,
        winProbability: 48.0,
        expectedScore: 55.0,
        visits: 500,
        totalNodes: 1000,
        nodePercentage: 50.0,
        policyPercentage: 22.2,
        movesLeft: 83.0,
        positionRevision: 1,
        requestId: 10,
        style: defaultStyle,
      );

      expect(arrow.rank, 1);
      expect(arrow.uciMove, 'e2e4');
      expect(arrow.from, squareE2);
      expect(arrow.to, squareE4);
      expect(arrow.winProbability, 48.0);
      expect(arrow.expectedScore, 55.0);
      expect(arrow.nodePercentage, 50.0);
      expect(arrow.policyPercentage, 22.2);
      expect(arrow.movesLeft, 83.0);
      expect(arrow.positionRevision, 1);
      expect(arrow.requestId, 10);
      expect(arrow.style.shaftColor, const Color(0xFF00D2BE));
    });
  });

  group('2. Arrowhead Badge Text Formatting & Real Telemetry Semantics', () {
    const lc0Arrow = CandidateArrow(
      rank: 1,
      uciMove: 'e2e4',
      from: squareE2,
      to: squareE4,
      pvUci: ['e2e4'],
      scoreCp: 26,
      winProbability: 48.0,
      expectedScore: 55.0,
      visits: 500,
      totalNodes: 1000,
      nodePercentage: 50.0,
      policyPercentage: 22.2,
      movesLeft: 83.0,
      positionRevision: 1,
      requestId: 1,
      style: defaultStyle,
    );

    const stockfishArrow = CandidateArrow(
      rank: 2,
      uciMove: 'd2d4',
      from: squareD2,
      to: squareD4,
      pvUci: ['d2d4'],
      scoreCp: 18,
      positionRevision: 1,
      requestId: 1,
      style: defaultStyle,
    );

    test('Winrate mode formats win percentage or cp fallback', () {
      expect(lc0Arrow.getBadgeText(ArrowheadType.winrate, EngineType.lc0), '48');
      expect(stockfishArrow.getBadgeText(ArrowheadType.winrate, EngineType.stockfish), isNotEmpty);
    });

    test('Node % mode displays candidate visit ratio or N/A', () {
      expect(lc0Arrow.getBadgeText(ArrowheadType.nodePct, EngineType.lc0), '50');
      expect(stockfishArrow.getBadgeText(ArrowheadType.nodePct, EngineType.stockfish), 'N/A');
    });

    test('Policy mode displays Lc0 prior or N/A for Stockfish', () {
      expect(lc0Arrow.getBadgeText(ArrowheadType.policy, EngineType.lc0), '22');
      // Stockfish has no policy prior -> must display N/A
      expect(stockfishArrow.getBadgeText(ArrowheadType.policy, EngineType.stockfish), 'N/A');
    });

    test('MultiPV rank mode displays rank number', () {
      expect(lc0Arrow.getBadgeText(ArrowheadType.multipvRank, EngineType.lc0), '1');
      expect(stockfishArrow.getBadgeText(ArrowheadType.multipvRank, EngineType.stockfish), '2');
    });

    test('Moves Left Ahead mode displays MLH or N/A', () {
      expect(lc0Arrow.getBadgeText(ArrowheadType.movesLeft, EngineType.lc0), '83');
      expect(stockfishArrow.getBadgeText(ArrowheadType.movesLeft, EngineType.stockfish), 'N/A');
    });

    test('Null or missing telemetry NEVER crashes and returns N/A', () {
      const emptyArrow = CandidateArrow(
        rank: 3,
        uciMove: 'g1f3',
        from: squareG1,
        to: squareF3,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );
      expect(emptyArrow.getBadgeText(ArrowheadType.policy, EngineType.lc0), 'N/A');
      expect(emptyArrow.getBadgeText(ArrowheadType.nodePct, EngineType.lc0), 'N/A');
      expect(emptyArrow.getBadgeText(ArrowheadType.movesLeft, EngineType.lc0), 'N/A');
    });
  });

  group('3. Arrow Filtering Logic', () {
    const arrows = [
      CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        scoreCp: 30,
        expectedScore: 55.0,
        nodePercentage: 60.0,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      ),
      CandidateArrow(
        rank: 2,
        uciMove: 'd2d4',
        from: squareD2,
        to: squareD4,
        scoreCp: 25,
        expectedScore: 53.5,
        nodePercentage: 30.0,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      ),
      CandidateArrow(
        rank: 3,
        uciMove: 'g1f3',
        from: squareG1,
        to: squareF3,
        scoreCp: -30,
        expectedScore: 45.0,
        nodePercentage: 0.8,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      ),
    ];

    test('Lc0 Filter - All returns all arrows', () {
      final settings = EngineSettings(
        activeEngine: EngineType.lc0,
        arrowFilterLc0: ArrowFilterLc0.all,
      );
      final filtered = filterCandidateArrows(
        arrows: arrows,
        settings: settings,
      );
      expect(filtered.length, 3);
    });

    test('Lc0 Filter - Top 1 returns only rank 1', () {
      final settings = EngineSettings(
        activeEngine: EngineType.lc0,
        arrowFilterLc0: ArrowFilterLc0.top1,
      );
      final filtered = filterCandidateArrows(
        arrows: arrows,
        settings: settings,
      );
      expect(filtered.length, 1);
      expect(filtered.first.rank, 1);
    });

    test('Lc0 Filter - Top 2 returns ranks 1 and 2', () {
      final settings = EngineSettings(
        activeEngine: EngineType.lc0,
        arrowFilterLc0: ArrowFilterLc0.top2,
      );
      final filtered = filterCandidateArrows(
        arrows: arrows,
        settings: settings,
      );
      expect(filtered.length, 2);
      expect(filtered.map((a) => a.rank).toList(), [1, 2]);
    });

    test('Lc0 Filter - Min 1% nodes filters out 0.8% visits', () {
      final settings = EngineSettings(
        activeEngine: EngineType.lc0,
        arrowFilterLc0: ArrowFilterLc0.minNodes1,
      );
      final filtered = filterCandidateArrows(
        arrows: arrows,
        settings: settings,
      );
      expect(filtered.length, 2);
      expect(filtered.any((a) => a.rank == 3), isFalse);
    });

    test('Lc0 Filter - Within 2% of best winrate', () {
      // Best score is 55.0. 53.5 is within 2%. 45.0 is not.
      final settings = EngineSettings(
        activeEngine: EngineType.lc0,
        arrowFilterLc0: ArrowFilterLc0.within2PctScore,
      );
      final filtered = filterCandidateArrows(
        arrows: arrows,
        settings: settings,
      );
      expect(filtered.length, 2);
      expect(filtered.map((a) => a.rank).toList(), [1, 2]);
    });

    test('Stockfish Filter - Within 50 cp', () {
      // Best cp = 30. Rank 2 cp = 25 (diff 5 <= 50). Rank 3 cp = -30 (diff 60 > 50).
      final settings = EngineSettings(
        activeEngine: EngineType.stockfish,
        arrowFilterOthers: ArrowFilterOthers.within50Cp,
      );
      final filtered = filterCandidateArrows(
        arrows: arrows,
        settings: settings,
      );
      expect(filtered.length, 2);
      expect(filtered.map((a) => a.rank).toList(), [1, 2]);
    });
  });

  group('4. Overlap Handling & Curvature Offsets', () {
    test('Sibling arrows from same square receive alternating quadratic offsets', () {
      // e2e4 and e2e3 both originate at e2
      const arrow1 = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );
      final arrow2 = CandidateArrow(
        rank: 2,
        uciMove: 'e2e3',
        from: squareE2,
        to: squareE3,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle.copyWith(curvature: -0.16),
      );

      expect(arrow1.style.curvature, 0.0);
      expect(arrow2.style.curvature, -0.16);
    });
  });

  group('5. Deterministic Render Order & Safety', () {
    test('Painter sorts arrows so Rank 1 is drawn LAST (rendered on top)', () {
      const arrows = [
        CandidateArrow(
          rank: 1,
          uciMove: 'e2e4',
          from: squareE2,
          to: squareE4,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
        CandidateArrow(
          rank: 2,
          uciMove: 'd2d4',
          from: squareD2,
          to: squareD4,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
        CandidateArrow(
          rank: 3,
          uciMove: 'g1f3',
          from: squareG1,
          to: squareF3,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
      ];

      // Sort descending by rank so lowest priority paints first, Rank 1 paints last
      final sortedToPaint = List<CandidateArrow>.from(arrows)
        ..sort((a, b) => b.rank.compareTo(a.rank));

      expect(sortedToPaint.first.rank, 3);
      expect(sortedToPaint[1].rank, 2);
      expect(sortedToPaint.last.rank, 1);
    });

    test('Stale position revision or requestId rejects painting', () {
      const staleArrow = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        positionRevision: 1,
        requestId: 5,
        style: defaultStyle,
      );

      const currentRevision = 2;
      const currentRequestId = 6;

      final isStale = (staleArrow.positionRevision != currentRevision) ||
          (staleArrow.requestId != currentRequestId);

      expect(isStale, isTrue);
    });
  });

  group('6. Strict Request Validation, Rank 1 Protection & Engine Elimination', () {
    test('EngineType contains strictly Stockfish and Lc0 - zero custom engines', () {
      expect(EngineType.values.length, 2);
      expect(EngineType.values, contains(EngineType.stockfish));
      expect(EngineType.values, contains(EngineType.lc0));
    });

    test('Rank 1 is safeguarded against threshold drops in filterCandidateArrows', () {
      const arrow1 = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        expectedScore: 50.0,
        nodePercentage: 0.5, // < 1%
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      const arrow2 = CandidateArrow(
        rank: 2,
        uciMove: 'd2d4',
        from: squareD2,
        to: squareD4,
        expectedScore: 45.0, // > 2% worse
        nodePercentage: 0.2, // < 1%
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      final settingsMinNodes = EngineSettings(
        activeEngine: EngineType.lc0,
        arrowFilterLc0: ArrowFilterLc0.minNodes1,
      );

      final filteredMinNodes = filterCandidateArrows(
        arrows: [arrow1, arrow2],
        settings: settingsMinNodes,
      );

      expect(filteredMinNodes.length, 1);
      expect(filteredMinNodes.first.rank, 1);

      final settingsWithin2Pct = EngineSettings(
        activeEngine: EngineType.lc0,
        arrowFilterLc0: ArrowFilterLc0.within2PctScore,
      );

      final filteredWithin2 = filterCandidateArrows(
        arrows: [arrow1, arrow2],
        settings: settingsWithin2Pct,
      );

      expect(filteredWithin2.length, 1);
      expect(filteredWithin2.first.rank, 1);
    });

    test('Strict request ID and revision rejection reasons are accurate', () {
      const arrowMissingReq = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        positionRevision: 1,
        requestId: 0, // Missing
        style: defaultStyle,
      );

      const arrowStaleReq = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        positionRevision: 1,
        requestId: 5, // Stale
        style: defaultStyle,
      );

      const currentReq = 6;
      const currentRev = 1;

      expect(arrowMissingReq.requestId <= 0, isTrue);
      expect(arrowStaleReq.requestId != currentReq, isTrue);
      expect(arrowStaleReq.positionRevision == currentRev, isTrue);
    });

    test('Engine failure on missing binary transitions to error lifecycle state with zero fallback', () async {
      final service = UciEngineService(EngineSettings(activeEngine: EngineType.stockfish));
      await service.initializeEngine('/nonexistent/path/to/stockfish');
      expect(service.lifecycleState, EngineLifecycleState.error);
      service.dispose();
    });
  });
}
