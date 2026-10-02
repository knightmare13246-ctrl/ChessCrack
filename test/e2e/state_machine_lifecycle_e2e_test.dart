import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/services/uci_engine_service.dart';
import 'package:nibbler_chess/ui/widgets/engine_analysis_panel.dart';

void main() {
  group('E2E State Machine & Lifecycle Suite', () {
    test('1. Engine activation transitions cleanly between enabled and disabled', () async {
      final settings = EngineSettings(activeEngine: EngineType.stockfish);
      final service = UciEngineService(settings);

      expect(service.isEngineEnabled, isTrue);
      expect(service.activationState, EngineActivationState.enabled);

      await service.disableEngine();
      expect(service.isEngineEnabled, isFalse);
      expect(service.activationState, EngineActivationState.disabled);

      // Enabling without binary in test harness safely transitions to error without crashing
      await service.enableEngine();
      expect(service.lifecycleState, EngineLifecycleState.error);
      expect(service.activationState, EngineActivationState.disabled);

      service.dispose();
    });

    test('2. Single Process Invariant: activeProcessCount is strictly bounded to [0, 1]', () async {
      final settings = EngineSettings(activeEngine: EngineType.stockfish);
      final service = UciEngineService(settings);

      expect(service.activeProcessCount, inInclusiveRange(0, 1));

      // Multiple rapid toggle calls
      await service.enableEngine();
      expect(service.activeProcessCount, inInclusiveRange(0, 1));
      await service.disableEngine();
      expect(service.activeProcessCount, inInclusiveRange(0, 1));
      await service.enableEngine();
      expect(service.activeProcessCount, inInclusiveRange(0, 1));

      service.dispose();
    });

    test('3. Non-destructive pause vs destructive disable semantics', () async {
      final settings = EngineSettings(activeEngine: EngineType.stockfish);
      final service = UciEngineService(settings);

      // Initial state
      expect(service.isPausedForBackground, isFalse);
      final initialReqId = service.analysisRequestId;
      final initialRev = service.positionRevision;

      // Non-destructive pause
      service.pauseForBackground();
      expect(service.isPausedForBackground, isTrue);

      // Resuming from non-destructive pause
      service.resumeFromBackground();
      expect(service.isPausedForBackground, isFalse);
      expect(service.analysisRequestId, equals(initialReqId + 1),
          reason: 'Resuming must increment analysisRequestId monotonically');
      expect(service.positionRevision, equals(initialRev),
          reason: 'Position revision must remain unchanged on pause/resume');

      // Destructive disable
      await service.disableEngine();
      expect(service.isEngineEnabled, isFalse);
      expect(service.evaluationNotifier.value, equals(NormalizedEvaluation.neutral),
          reason: 'disableEngine must reset evaluation to neutral');

      service.dispose();
    });

    test('4. Presentation settings update does NOT thrash or restart search', () {
      final initialSettings = EngineSettings(
        activeEngine: EngineType.stockfish,
        arrowheadType: ArrowheadType.winrate,
        arrowFilterOthers: ArrowFilterOthers.all,
      );
      final service = UciEngineService(initialSettings);
      final initialReqId = service.analysisRequestId;

      final updatedSettings = initialSettings.copyWith(
        arrowheadType: ArrowheadType.multipvRank,
        arrowFilterOthers: ArrowFilterOthers.top1,
      );

      service.updatePresentationSettings(updatedSettings);

      expect(service.settings.arrowheadType, ArrowheadType.multipvRank);
      expect(service.settings.arrowFilterOthers, ArrowFilterOthers.top1);
      expect(service.analysisRequestId, equals(initialReqId),
          reason: 'Presentation update must never invalidate or increment analysisRequestId');

      service.dispose();
    });

    testWidgets('5. UI EngineAnalysisPanel reflects search state and button semantics strictly', (WidgetTester tester) async {
      final position = ChessPosition.initial();
      bool toggleCalled = false;

      // 5A: Searching state -> shows Pause button with Icons.pause
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EngineAnalysisPanel(
              analysis: PositionAnalysis(
                fen: position.toFen(),
                totalNodes: 500000,
                nodesPerSecond: 250000,
                depth: 18,
                isAnalyzing: true,
                engineName: 'Stockfish 19',
              ),
              isAnalyzing: true,
              onToggleAnalysis: () {
                toggleCalled = true;
              },
              onPlayMove: (_) {},
              currentPosition: position,
              settings: EngineSettings(activeEngine: EngineType.stockfish),
            ),
          ),
        ),
      );

      expect(find.text('Pause'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.text('Analyze'), findsNothing);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(toggleCalled, isTrue);

      // 5B: Paused state -> shows Analyze button with Icons.play_arrow
      toggleCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EngineAnalysisPanel(
              analysis: PositionAnalysis(
                fen: position.toFen(),
                totalNodes: 500000,
                nodesPerSecond: 250000,
                depth: 18,
                isAnalyzing: false,
                engineName: 'Stockfish 19',
              ),
              isAnalyzing: false,
              onToggleAnalysis: () {
                toggleCalled = true;
              },
              onPlayMove: (_) {},
              currentPosition: position,
              settings: EngineSettings(activeEngine: EngineType.stockfish),
            ),
          ),
        ),
      );

      expect(find.text('Analyze'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('Pause'), findsNothing);

      await tester.tap(find.text('Analyze'));
      await tester.pump();
      expect(toggleCalled, isTrue);
    });

    test('6. Monotonic Request ID ordering across rapid start/stop cycles', () {
      final service = UciEngineService(EngineSettings());
      int lastReqId = service.analysisRequestId;

      for (int i = 0; i < 5; i++) {
        service.pauseForBackground();
        service.resumeFromBackground();
        expect(service.analysisRequestId, greaterThan(lastReqId));
        lastReqId = service.analysisRequestId;
      }

      service.dispose();
    });
  });
}
