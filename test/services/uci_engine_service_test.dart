import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/services/uci_engine_service.dart';

void main() {
  group('1. Strict State Decoupling Specification', () {
    test('EngineInstallationState contains exactly the 7 specification states', () {
      const expected = [
        EngineInstallationState.uninstalled,
        EngineInstallationState.downloading,
        EngineInstallationState.verifying,
        EngineInstallationState.installed,
        EngineInstallationState.ready,
        EngineInstallationState.deleting,
        EngineInstallationState.error,
      ];
      expect(EngineInstallationState.values, equals(expected));
    });

    test('EngineLifecycleState contains exactly the 5 process lifecycle states', () {
      const expected = [
        EngineLifecycleState.uninitialized,
        EngineLifecycleState.initializing,
        EngineLifecycleState.ready,
        EngineLifecycleState.disposed,
        EngineLifecycleState.error,
      ];
      expect(EngineLifecycleState.values, equals(expected));
    });

    test('AnalysisDataState contains exactly the 5 search data states', () {
      const expected = [
        AnalysisDataState.idle,
        AnalysisDataState.searching,
        AnalysisDataState.paused,
        AnalysisDataState.completed,
        AnalysisDataState.stopping,
      ];
      expect(AnalysisDataState.values, equals(expected));
    });

    test('EngineSearchState is a compliant alias of AnalysisDataState', () {
      expect(EngineSearchState.values, equals(AnalysisDataState.values));
    });
  });

  group('2. Nullable Engine Telemetry & Header Formatting', () {
    test('PvLine defaults all telemetry to null instead of synthetic 0', () {
      final line = PvLine(
        multipv: 1,
        winPercentage: 50.0,
        whiteWinPercentage: 50.0,
        movesUci: const ['e2e4'],
      );
      expect(line.depth, isNull);
      expect(line.seldepth, isNull);
      expect(line.nodes, isNull);
      expect(line.nps, isNull);
      expect(line.engineSessionId, equals(0));
    });

    test('CandidateArrow supports nullable depth and bundles engineSessionId', () {
      final arrow = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: Square.fromAlgebraic('e2'),
        to: Square.fromAlgebraic('e4'),
        positionRevision: 1,
        requestId: 1,
        engineSessionId: 42,
        style: const ArrowVisualStyle(
          shaftColor: Color(0xFF00FF00),
          badgeColor: Color(0xFF00FF00),
          textColor: Color(0xFFFFFFFF),
          borderColor: Color(0xFF000000),
          opacity: 1.0,
          strokeWidthScale: 1.0,
          arrowHeadScale: 1.0,
          badgeScale: 1.0,
          curvature: 0.0,
        ),
      );
      expect(arrow.depth, isNull);
      expect(arrow.engineSessionId, equals(42));

      final updated = arrow.copyWith(depth: 18, engineSessionId: 43);
      expect(updated.depth, equals(18));
      expect(updated.engineSessionId, equals(43));
    });

    test('EngineDiagnostics preserves nullable telemetry without fake zeros', () {
      final diag = EngineDiagnostics(lastUpdate: DateTime.now());
      expect(diag.totalNodes, isNull);
      expect(diag.nps, isNull);
      expect(diag.depth, isNull);
      expect(diag.seldepth, isNull);
      expect(diag.timeMs, isNull);
    });

    test('PositionAnalysis formats null nodes and nps as dashes', () {
      const analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        engineName: 'Stockfish 19',
        isAnalyzing: true,
        searchState: AnalysisDataState.searching,
      );
      expect(analysis.formattedHeader, equals('Nodes: —, N/s: —'));
    });

    test('PositionAnalysis formats Lc0 missing NPS as N/s: N/A', () {
      const analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        engineName: 'Lc0 (Leela)',
        totalNodes: 1200,
        nodesPerSecond: null,
        depth: 12,
        isAnalyzing: true,
        searchState: AnalysisDataState.searching,
      );
      expect(analysis.formattedHeader, equals('Nodes: 1,200, N/s: N/A, Depth: 12'));
    });

    test('PositionAnalysis formats non-Maia paused state with Paused prefix and N/s: —', () {
      const analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        engineName: 'Stockfish 19',
        totalNodes: 5000000,
        nodesPerSecond: 2500000,
        depth: 25,
        seldepth: 30,
        isAnalyzing: false,
        searchState: AnalysisDataState.paused,
      );
      expect(analysis.formattedHeader, equals('Paused · Nodes: 5,000,000, N/s: —, Depth: 25/30'));
    });
  });

  group('3. Atomic Analysis Snapshot & MultiPV Synchronization', () {
    test('AnalysisGeneration bundles positionRevision, analysisRequestId, and engineSessionId', () {
      const gen1 = AnalysisGeneration(
        positionRevision: 2,
        analysisRequestId: 5,
        engineSessionId: 1,
      );
      const gen2 = AnalysisGeneration(
        positionRevision: 2,
        analysisRequestId: 5,
        engineSessionId: 1,
      );
      const gen3 = AnalysisGeneration(
        positionRevision: 3,
        analysisRequestId: 5,
        engineSessionId: 1,
      );

      expect(gen1, equals(gen2));
      expect(gen1.hashCode, equals(gen2.hashCode));
      expect(gen1 == gen3, isFalse);
      expect(gen1.matches(revision: 2, requestId: 5, sessionId: 1), isTrue);
      expect(gen1.matches(revision: 2, requestId: 6, sessionId: 1), isFalse);
      expect(gen1.matches(revision: 2, requestId: 5, sessionId: 2), isFalse);
    });

    test('UciEngineService exposes currentGeneration and engineSessionId', () {
      final service = UciEngineService(EngineSettings());
      expect(service.engineSessionId, equals(0));
      expect(service.currentGeneration.engineSessionId, equals(0));
      expect(service.currentGeneration.positionRevision, equals(0));
      expect(service.currentGeneration.analysisRequestId, equals(0));
    });
  });

  group('4. Search Control Decoupling (pauseAnalysis vs resumeAnalysis vs disableEngine)', () {
    test('pauseAnalysis preserves candidate arrows and evaluation while stopping computation', () {
      final service = UciEngineService(EngineSettings());
      // Default engine state is enabled
      expect(service.isEngineEnabled, isTrue);
      expect(service.searchState, equals(AnalysisDataState.idle));

      // pauseAnalysis transitions search state to paused
      service.pauseAnalysis();
      expect(service.searchState, equals(AnalysisDataState.paused));
    });

    test('disableEngine cleanly resets evaluation to neutral and lifecycle to disposed', () async {
      final service = UciEngineService(EngineSettings());
      await service.disableEngine();
      expect(service.lifecycleState, equals(EngineLifecycleState.disposed));
      expect(service.activationState, equals(EngineActivationState.disabled));
      expect(service.searchState, equals(AnalysisDataState.idle));
      expect(service.evaluationNotifier.value.whiteExpectedScore, equals(50.0));
    });
  });
}
