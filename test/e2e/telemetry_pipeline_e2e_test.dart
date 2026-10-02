import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Telemetry Pipeline Suite', () {
    test('1. Stockfish continuous search telemetry formatting with comma-grouped nodes and live NPS', () {
      const analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1360000,
        nodesPerSecond: 450000,
        depth: 22,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );

      final header = analysis.formattedHeader;
      expect(header, contains('Nodes: 1,360,000'));
      expect(header, contains('N/s: 450,000'));
      expect(header, contains('Depth: 22'));
      expect(header.startsWith('Paused · '), isFalse);
    });

    test('2. Comma grouping boundary values: 0, 999, 1000, 1000000, 1234567890', () {
      const analysis0 = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 0,
        nodesPerSecond: 0,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(analysis0.formattedHeader, contains('Nodes: 0'));

      const analysis999 = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 999,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(analysis999.formattedHeader, contains('Nodes: 999'));

      const analysis1k = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1000,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(analysis1k.formattedHeader, contains('Nodes: 1,000'));

      const analysis1m = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1000000,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(analysis1m.formattedHeader, contains('Nodes: 1,000,000'));

      const analysisBig = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1234567890,
        isAnalyzing: true,
        engineName: 'Stockfish 19',
      );
      expect(analysisBig.formattedHeader, contains('Nodes: 1,234,567,890'));
    });

    test('3. Lc0 0.32.1 missing NPS formats as N/s: N/A instead of fake 0', () {
      const lc0AnalyzingNoNps = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 850,
        nodesPerSecond: 0, // Lc0 omitted NPS from UCI line
        depth: 14,
        isAnalyzing: true,
        engineName: 'Lc0 (Leela)',
      );

      final header = lc0AnalyzingNoNps.formattedHeader;
      expect(header, contains('N/s: N/A'),
          reason: 'Lc0 with 0 or omitted NPS must format as N/s: N/A, never N/s: 0');
      expect(header, contains('Nodes: 850'));
      expect(header, contains('Depth: 14'));
    });

    test('4. Lc0 with live NPS formats with real number', () {
      const lc0AnalyzingWithNps = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 5000,
        nodesPerSecond: 1250,
        depth: 15,
        isAnalyzing: true,
        engineName: 'Lc0 (Leela)',
      );

      final header = lc0AnalyzingWithNps.formattedHeader;
      expect(header, contains('N/s: 1,250'));
    });

    test('5. Non-Maia paused telemetry formats with Paused · prefix and N/s: —', () {
      const pausedAnalysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 2500000,
        nodesPerSecond: 500000,
        depth: 25,
        isAnalyzing: false, // Paused
        engineName: 'Stockfish 19',
      );

      final header = pausedAnalysis.formattedHeader;
      expect(header.startsWith('Paused · '), isTrue);
      expect(header, contains('Nodes: 2,500,000'));
      expect(header, contains('N/s: —'),
          reason: 'Paused non-Maia search must display N/s: —');
      expect(header, contains('Depth: 25'));
    });

    test('6. Seldepth, depth, timeMs, and hashfull tracking in EngineDiagnostics', () {
      final diag = EngineDiagnostics(
        engineName: 'Stockfish 19',
        depth: 24,
        seldepth: 35,
        timeMs: 4200,
        hashfull: 125,
        tbhits: 15,
        lastUpdate: DateTime.now(),
      );

      expect(diag.depth, 24);
      expect(diag.seldepth, 35);
      expect(diag.timeMs, 4200);
      expect(diag.hashfull, 125);
      expect(diag.tbhits, 15);
    });

    test('7. Stream protection & MultiPV snapshot generation synchronization', () {
      const activeRevision = 3;
      const activeRequestId = 12;

      final pv1 = PvLine(
        multipv: 1,
        movesUci: ['e2e4', 'e7e5'],
        winPercentage: 54.0,
        whiteWinPercentage: 54.0,
        depth: 20,
        seldepth: 28,
        nodes: 500000,
        nps: 250000,
        positionRevision: activeRevision,
        analysisRequestId: activeRequestId,
      );

      final pv2 = PvLine(
        multipv: 2,
        movesUci: ['d2d4', 'd7d5'],
        winPercentage: 52.5,
        whiteWinPercentage: 52.5,
        depth: 20,
        seldepth: 28,
        nodes: 450000,
        nps: 250000,
        positionRevision: activeRevision,
        analysisRequestId: activeRequestId,
      );

      final analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        positionRevision: activeRevision,
        analysisRequestId: activeRequestId,
        totalNodes: 950000,
        nodesPerSecond: 250000,
        depth: 20,
        pvLines: [pv1, pv2],
        isAnalyzing: true,
      );

      expect(analysis.bestLine, isNotNull);
      expect(analysis.bestLine!.primaryMoveUci, 'e2e4');
      expect(analysis.pvLines.length, 2);
      expect(analysis.pvLines.every((l) => l.positionRevision == activeRevision), isTrue);
      expect(analysis.pvLines.every((l) => l.analysisRequestId == activeRequestId), isTrue);
    });

    test('8. PvLine formatted metrics accurately presents neural vs alpha-beta fields', () {
      // Neural line with visit %, policy %, utility
      final neuralLine = PvLine(
        multipv: 1,
        movesUci: ['e2e4'],
        winPercentage: 55.0,
        whiteWinPercentage: 55.0,
        visitPercentage: 42.50,
        policyPercentage: 34.20,
        utility: 0.123,
      );
      final neuralMetrics = neuralLine.formattedMetrics;
      expect(neuralMetrics, contains('N: 42.50%'));
      expect(neuralMetrics, contains('P: 34.20%'));
      expect(neuralMetrics, contains('U: 0.123'));

      // Alpha-beta line fallback
      final abLine = PvLine(
        multipv: 1,
        movesUci: ['d2d4'],
        winPercentage: 53.0,
        whiteWinPercentage: 53.0,
        depth: 24,
        nodes: 1200000,
        nps: 600000,
      );
      final abMetrics = abLine.formattedMetrics;
      expect(abMetrics, contains('d: 24'));
      expect(abMetrics, contains('nodes: 1200000'));
      expect(abMetrics, contains('600k nps'));
    });
  });
}
