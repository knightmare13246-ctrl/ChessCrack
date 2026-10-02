import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/ui/widgets/engine_analysis_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Challenge 1: Null Telemetry Boundary Combinations', () {
    test('1.1 All telemetry fields explicitly null during active search', () {
      const analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: null,
        nodesPerSecond: null,
        depth: null,
        seldepth: null,
        timeMs: null,
        isAnalyzing: true,
        searchState: AnalysisDataState.searching,
        engineName: 'Stockfish 19',
      );

      final header = analysis.formattedHeader;
      expect(header, 'Nodes: —, N/s: —');
      expect(header.contains('null'), isFalse);
      expect(header.contains('Depth'), isFalse);
      expect(header.contains('0'), isFalse);
    });

    test('1.2 All telemetry fields null during paused state', () {
      const analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: null,
        nodesPerSecond: null,
        depth: null,
        seldepth: null,
        timeMs: null,
        isAnalyzing: false,
        searchState: AnalysisDataState.paused,
        engineName: 'Stockfish 19',
      );

      final header = analysis.formattedHeader;
      expect(header, 'Paused · Nodes: —, N/s: —');
      expect(header.contains('null'), isFalse);
    });

    test('1.3 Boundary: totalNodes is 0 vs null', () {
      const analysisZero = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 0,
        nodesPerSecond: null,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(analysisZero.formattedHeader, 'Nodes: 0, N/s: —');

      const analysisNull = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: null,
        nodesPerSecond: null,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(analysisNull.formattedHeader, 'Nodes: —, N/s: —');
    });

    test('1.4 Boundary: depth and seldepth combinations', () {
      // depth only
      const aDepthOnly = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1000,
        nodesPerSecond: 500,
        depth: 18,
        seldepth: null,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(aDepthOnly.formattedHeader, 'Nodes: 1,000, N/s: 500, Depth: 18');

      // depth and seldepth where seldepth > depth
      const aDepthSeldepth = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1000,
        nodesPerSecond: 500,
        depth: 18,
        seldepth: 27,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(aDepthSeldepth.formattedHeader, 'Nodes: 1,000, N/s: 500, Depth: 18/27');

      // depth == seldepth (should format as Depth: 18, NOT 18/18)
      const aDepthEqual = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1000,
        nodesPerSecond: 500,
        depth: 18,
        seldepth: 18,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(aDepthEqual.formattedHeader, 'Nodes: 1,000, N/s: 500, Depth: 18');

      // seldepth < depth (inverted - should format as Depth: 18, NOT 18/12)
      const aDepthInverted = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1000,
        nodesPerSecond: 500,
        depth: 18,
        seldepth: 12,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(aDepthInverted.formattedHeader, 'Nodes: 1,000, N/s: 500, Depth: 18');

      // seldepth present but depth is null
      const aSeldepthNoDepth = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1000,
        nodesPerSecond: 500,
        depth: null,
        seldepth: 25,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(aSeldepthNoDepth.formattedHeader, 'Nodes: 1,000, N/s: 500');

      // depth is 0
      const aDepthZero = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1000,
        nodesPerSecond: 500,
        depth: 0,
        seldepth: 10,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(aDepthZero.formattedHeader, 'Nodes: 1,000, N/s: 500');

      // depth is negative
      const aDepthNegative = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1000,
        nodesPerSecond: 500,
        depth: -1,
        seldepth: 10,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(aDepthNegative.formattedHeader, 'Nodes: 1,000, N/s: 500');
    });

    test('1.5 EngineDiagnostics handles null telemetry fields safely', () {
      final diag = EngineDiagnostics(
        totalNodes: null,
        nps: null,
        depth: null,
        seldepth: null,
        timeMs: null,
        lastUpdate: DateTime.now(),
      );

      expect(diag.totalNodes, isNull);
      expect(diag.nps, isNull);
      expect(diag.depth, isNull);
      expect(diag.seldepth, isNull);
      expect(diag.timeMs, isNull);

      final updated = diag.copyWith(
        totalNodes: 100,
        nps: 50,
      );
      expect(updated.totalNodes, 100);
      expect(updated.nps, 50);
      expect(updated.depth, isNull);
      expect(updated.seldepth, isNull);
      expect(updated.timeMs, isNull);
    });

    test('1.6 PvLine formattedMetrics handles null telemetry without fake zeros', () {
      final lineNull = PvLine(
        multipv: 1,
        movesUci: ['e2e4'],
        winPercentage: 50.0,
        whiteWinPercentage: 50.0,
        depth: null,
        seldepth: null,
        nodes: null,
        nps: null,
      );
      expect(lineNull.formattedMetrics, '()');

      final lineZeros = PvLine(
        multipv: 1,
        movesUci: ['e2e4'],
        winPercentage: 50.0,
        whiteWinPercentage: 50.0,
        depth: 0,
        nodes: 0,
        nps: 0,
      );
      expect(lineZeros.formattedMetrics, '()');

      final linePartial = PvLine(
        multipv: 1,
        movesUci: ['e2e4'],
        winPercentage: 50.0,
        whiteWinPercentage: 50.0,
        depth: 15,
        nodes: null,
        nps: null,
      );
      expect(linePartial.formattedMetrics, '(d: 15)');
    });
  });

  group('Adversarial Challenge 2: Lc0 Missing NPS Invariants', () {
    final lc0Names = [
      'Lc0 (Leela)',
      'lc0',
      'Leela Chess Zero',
      'LC0 v0.32.1',
      'Leela',
    ];

    for (final name in lc0Names) {
      test('2.1 Lc0 engine naming variation "$name" with null NPS outputs N/s: N/A', () {
        final analysis = PositionAnalysis(
          fen: ChessPosition.initialFen,
          totalNodes: 4500,
          nodesPerSecond: null,
          depth: 15,
          isAnalyzing: true,
          engineName: name,
        );

        final header = analysis.formattedHeader;
        expect(header, contains('N/s: N/A'),
            reason: 'Engine named "$name" with null NPS must output N/s: N/A');
        expect(header.contains('N/s: 0'), isFalse);
        expect(header.contains('N/s: —'), isFalse);
      });

      test('2.2 Lc0 engine naming variation "$name" with 0 NPS outputs N/s: N/A', () {
        final analysis = PositionAnalysis(
          fen: ChessPosition.initialFen,
          totalNodes: 4500,
          nodesPerSecond: 0,
          depth: 15,
          isAnalyzing: true,
          engineName: name,
        );

        final header = analysis.formattedHeader;
        expect(header, contains('N/s: N/A'),
            reason: 'Engine named "$name" with 0 NPS must output N/s: N/A, never synthetic 0');
        expect(header.contains('N/s: 0'), isFalse);
      });
    }

    test('2.3 Lc0 with actual positive NPS formats real number', () {
      const analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 4500,
        nodesPerSecond: 1850,
        depth: 15,
        isAnalyzing: true,
        engineName: 'Lc0 (Leela)',
      );

      final header = analysis.formattedHeader;
      expect(header, contains('N/s: 1,850'));
      expect(header.contains('N/A'), isFalse);
    });

    test('2.4 Non-Lc0 engine (Stockfish) with null or 0 NPS formats as N/s: —', () {
      const sfNull = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 100,
        nodesPerSecond: null,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(sfNull.formattedHeader, contains('N/s: —'));
      expect(sfNull.formattedHeader.contains('N/A'), isFalse);

      const sfZero = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 100,
        nodesPerSecond: 0,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(sfZero.formattedHeader, contains('N/s: —'));
      expect(sfZero.formattedHeader.contains('N/A'), isFalse);
    });

    test('2.5 Maia human sparring mode never injects synthetic N/s: 0 or false depth', () {
      const maiaAnalyzing = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1,
        nodesPerSecond: 0,
        depth: 1,
        isAnalyzing: true,
        engineName: 'Maia 1500',
        isMaia: true,
        maiaElo: 1500,
      );

      final header = maiaAnalyzing.formattedHeader;
      expect(header, 'Maia 1500 · Evaluating Human Moves...');
      expect(header.contains('N/s'), isFalse);
      expect(header.contains('Depth'), isFalse);
      expect(header.contains('Nodes:'), isFalse);

      const maiaCompleted = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1,
        nodesPerSecond: 0,
        depth: 1,
        isAnalyzing: false,
        searchState: AnalysisDataState.completed,
        engineName: 'Maia 1500',
        isMaia: true,
        maiaElo: 1500,
      );
      expect(maiaCompleted.formattedHeader, 'Maia 1500 · Evaluation Complete (1-ply Policy)');

      const maiaPaused = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1,
        nodesPerSecond: 0,
        depth: 1,
        isAnalyzing: false,
        searchState: AnalysisDataState.paused,
        engineName: 'Maia 1500',
        isMaia: true,
        maiaElo: 1500,
      );
      expect(maiaPaused.formattedHeader, 'Paused · Maia 1500 · Evaluation Paused');
    });
  });

  group('Adversarial Challenge 3: Stockfish Live Nodes Comma Grouping', () {
    final testCases = <int, String>{
      0: '0',
      1: '1',
      7: '7',
      9: '9',
      10: '10',
      99: '99',
      100: '100',
      999: '999',
      1000: '1,000',
      1001: '1,001',
      9999: '9,999',
      10000: '10,000',
      99999: '99,999',
      100000: '100,000',
      999999: '999,999',
      1000000: '1,000,000',
      1000001: '1,000,001',
      1234567: '1,234,567',
      10000000: '10,000,000',
      99999999: '99,999,999',
      100000000: '100,000,000',
      999999999: '999,999,999',
      1000000000: '1,000,000,000',
      1234567890: '1,234,567,890',
      9876543210123: '9,876,543,210,123',
    };

    for (final entry in testCases.entries) {
      test('3.1 Comma grouping for nodes = ${entry.key}', () {
        final analysis = PositionAnalysis(
          fen: ChessPosition.initialFen,
          totalNodes: entry.key,
          nodesPerSecond: entry.key,
          isAnalyzing: true,
          engineName: 'Stockfish 19',
        );

        expect(analysis.formattedHeader, contains('Nodes: ${entry.value}'));
        if (entry.key > 0) {
          expect(analysis.formattedHeader, contains('N/s: ${entry.value}'));
        }
      });
    }

    test('3.2 Rapid monotonic nodes and NPS progression preserves exact formatting', () {
      final progression = [
        12,
        995,
        1000,
        1542,
        45000,
        123456,
        1234567,
        25000000,
        150000000,
      ];

      for (int i = 0; i < progression.length; i++) {
        final nodes = progression[i];
        final nps = (nodes * 0.4).round();
        final analysis = PositionAnalysis(
          fen: ChessPosition.initialFen,
          totalNodes: nodes,
          nodesPerSecond: nps,
          depth: 10 + i,
          seldepth: 15 + i,
          isAnalyzing: true,
          engineName: 'Stockfish 19',
        );

        final header = analysis.formattedHeader;
        expect(header.contains('null'), isFalse);
        expect(header, contains('Depth: ${10 + i}/${15 + i}'));
        expect(header.startsWith('Nodes: '), isTrue);
      }
    });
  });

  group('Adversarial Challenge 4: EngineAnalysisPanel Widget Rendering with Null Telemetry', () {
    testWidgets('4.1 Panel renders without crashing when all analysis fields are null', (tester) async {
      const nullAnalysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: null,
        nodesPerSecond: null,
        depth: null,
        seldepth: null,
        timeMs: null,
        pvLines: [],
        candidateArrows: [],
        isAnalyzing: false,
        engineName: 'Stockfish 19',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 400,
              child: EngineAnalysisPanel(
                analysis: nullAnalysis,
                isAnalyzing: false,
                onToggleAnalysis: () {},
                onPlayMove: (_) {},
                currentPosition: ChessPosition.initial(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(EngineAnalysisPanel), findsOneWidget);
      expect(find.text('Tap Analyze to start engine evaluation'), findsOneWidget);
    });

    testWidgets('4.2 Panel renders Lc0 telemetry with N/s: N/A in widget tree', (tester) async {
      const lc0Analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 890,
        nodesPerSecond: null,
        depth: 12,
        seldepth: 18,
        pvLines: [],
        candidateArrows: [],
        isAnalyzing: true,
        searchState: AnalysisDataState.searching,
        engineName: 'Lc0 (Leela)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 400,
              child: EngineAnalysisPanel(
                analysis: lc0Analysis,
                isAnalyzing: true,
                onToggleAnalysis: () {},
                onPlayMove: (_) {},
                currentPosition: ChessPosition.initial(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Nodes: 890, N/s: N/A, Depth: 12/18'), findsOneWidget);
    });
  });
}
