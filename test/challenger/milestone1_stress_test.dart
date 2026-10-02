import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/services/uci_engine_service.dart';

void main() {
  final mockExePath = File('test/helpers/mock_uci_engine.exe').absolute.path;

  group('EMPIRICAL CHALLENGER: Milestone 1 Adversarial Stress Test', () {
    test('1. disableEngine() MUST strictly terminate process, reset eval to 50%, and clean all data', () async {
      final settings = EngineSettings(activeEngine: EngineType.stockfish);
      final service = UciEngineService(settings);

      // Initialize engine with real mock executable
      await service.initializeEngine(mockExePath);
      expect(service.isProcessAlive, isTrue, reason: 'Engine process must be alive after initializeEngine');
      expect(service.activeProcessCount, equals(1));

      // Start search so data is populated
      service.startAnalysis(ChessPosition.initial());
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Call disableEngine()
      await service.disableEngine();

      // Check eval reset
      expect(service.evaluationNotifier.value, equals(NormalizedEvaluation.neutral),
          reason: 'disableEngine must reset evaluation to neutral (50.0%)');
      expect(service.evaluationNotifier.value.whiteExpectedScore, equals(50.0));

      // Check state cleaned
      expect(service.currentNodes, isNull);
      expect(service.currentNps, isNull);
      expect(service.currentDepth, isNull);
      expect(service.lifecycleState, equals(EngineLifecycleState.disposed));
      expect(service.activationState, equals(EngineActivationState.disabled));

      // Check process termination:
      expect(service.isProcessAlive, isFalse,
          reason: 'disableEngine() MUST terminate the process, but isProcessAlive was true!');
      expect(service.activeProcessCount, equals(0),
          reason: 'disableEngine() MUST reduce activeProcessCount to 0!');

      service.dispose();
    });

    test('2. pauseAnalysis() and resumeAnalysis() under rapid successive calls retain lines and eval', () async {
      final settings = EngineSettings(activeEngine: EngineType.stockfish);
      final service = UciEngineService(settings);

      await service.initializeEngine(mockExePath);
      expect(service.isProcessAlive, isTrue);

      service.startAnalysis(ChessPosition.initial());
      // Wait for engine output
      PositionAnalysis? lastAnalysis;
      final sub = service.analysisStream.listen((a) {
        lastAnalysis = a;
      });

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(lastAnalysis, isNotNull);
      expect(lastAnalysis!.pvLines, isNotEmpty, reason: 'Engine must produce PV lines');
      expect(lastAnalysis!.candidateArrows, isNotEmpty, reason: 'Engine must produce candidate arrows');
      expect(service.evaluationNotifier.value.whiteExpectedScore, isNot(equals(50.0)),
          reason: 'Evaluation should reflect engine score, not neutral');

      final initialScore = service.evaluationNotifier.value.whiteExpectedScore;
      final initialArrowCount = lastAnalysis!.candidateArrows.length;

      // Single pause
      service.pauseAnalysis();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.isAnalyzing, isFalse);
      expect(service.searchState, isIn([AnalysisDataState.paused, AnalysisDataState.stopping]));
      expect(service.evaluationNotifier.value.whiteExpectedScore, equals(initialScore),
          reason: 'pauseAnalysis MUST strictly retain evaluation');
      expect(lastAnalysis!.candidateArrows.length, equals(initialArrowCount),
          reason: 'pauseAnalysis MUST strictly retain candidate arrows');

      // Single resume
      service.resumeAnalysis();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.isAnalyzing, isTrue);
      expect(service.searchState, equals(AnalysisDataState.searching));
      expect(service.evaluationNotifier.value.whiteExpectedScore, equals(initialScore),
          reason: 'resumeAnalysis MUST strictly retain evaluation');
      expect(lastAnalysis!.candidateArrows.length, equals(initialArrowCount),
          reason: 'resumeAnalysis MUST strictly retain candidate arrows');

      // Stress test: 50 rapid successive pause/resume toggles
      for (int i = 0; i < 50; i++) {
        service.pauseAnalysis();
        expect(service.evaluationNotifier.value.whiteExpectedScore, equals(initialScore),
            reason: 'Rapid pause cycle #$i must NOT reset eval to neutral!');
        expect(lastAnalysis!.candidateArrows.length, equals(initialArrowCount),
            reason: 'Rapid pause cycle #$i must NOT wipe candidate arrows!');

        service.resumeAnalysis();
        expect(service.evaluationNotifier.value.whiteExpectedScore, equals(initialScore),
            reason: 'Rapid resume cycle #$i must NOT reset eval to neutral!');
        expect(lastAnalysis!.candidateArrows.length, equals(initialArrowCount),
            reason: 'Rapid resume cycle #$i must NOT wipe candidate arrows!');
      }

      await sub.cancel();
      service.dispose();
    });

    test('3. AnalysisGeneration tuple filtering under simulated out-of-order MultiPV lines', () async {
      final settings = EngineSettings(
        activeEngine: EngineType.stockfish,
        customUciOptions: {'CustomScenario': 'out_of_order_multipv'},
      );
      final service = UciEngineService(settings);

      await service.initializeEngine(mockExePath);
      expect(service.isProcessAlive, isTrue);

      PositionAnalysis? capturedAnalysis;
      final sub = service.analysisStream.listen((a) {
        capturedAnalysis = a;
      });

      service.startAnalysis(ChessPosition.initial());
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(capturedAnalysis, isNotNull);
      expect(capturedAnalysis!.pvLines.length, equals(3));

      // MultiPV 3 arrived first, but sortedLines MUST sort multipv 1, 2, 3
      expect(capturedAnalysis!.pvLines[0].multipv, equals(1));
      expect(capturedAnalysis!.pvLines[1].multipv, equals(2));
      expect(capturedAnalysis!.pvLines[2].multipv, equals(3));

      // All lines must strictly match the current generation tuple
      for (final line in capturedAnalysis!.pvLines) {
        expect(line.positionRevision, equals(service.positionRevision));
        expect(line.analysisRequestId, equals(service.analysisRequestId));
        expect(line.engineSessionId, equals(service.engineSessionId));
      }

      for (final arrow in capturedAnalysis!.candidateArrows) {
        expect(arrow.positionRevision, equals(service.positionRevision));
        expect(arrow.requestId, equals(service.analysisRequestId));
        expect(arrow.engineSessionId, equals(service.engineSessionId));
      }

      await sub.cancel();
      service.dispose();
    });

    test('4. Zero-bypass protection: Illegal move injection in UCI line is dropped', () async {
      final settings = EngineSettings(
        activeEngine: EngineType.stockfish,
        customUciOptions: {'CustomScenario': 'illegal_move_injection'},
      );
      final service = UciEngineService(settings);

      await service.initializeEngine(mockExePath);

      PositionAnalysis? capturedAnalysis;
      final sub = service.analysisStream.listen((a) {
        capturedAnalysis = a;
      });

      service.startAnalysis(ChessPosition.initial());
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(capturedAnalysis, isNotNull);
      // Illegal move e2e5 must be rejected, only legal move e2e4 retained
      expect(capturedAnalysis!.pvLines.any((l) => l.movesUci.first == 'e2e5'), isFalse,
          reason: 'Illegal move e2e5 must be rejected by findLegalMoveByUci');
      expect(capturedAnalysis!.pvLines.any((l) => l.movesUci.first == 'e2e4'), isTrue,
          reason: 'Legal move e2e4 must be accepted');

      await sub.cancel();
      service.dispose();
    });
  });
}
