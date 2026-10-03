import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/services/theme_service.dart';
import 'package:nibbler_chess/services/uci_engine_service.dart';
import 'package:nibbler_chess/ui/widgets/nibbler_board.dart';
import 'package:nibbler_chess/ui/widgets/nibbler_arrow_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const squareE2 = Square(4, 1);
  const squareE4 = Square(4, 3);
  const squareE7 = Square(4, 6);
  const squareE5 = Square(4, 4);

  const defaultStyle = ArrowVisualStyle(
    shaftColor: Color(0xFF00D2BE),
    badgeColor: Color(0xFF004D40),
    textColor: Colors.white,
    borderColor: Color(0xFF00D2BE),
  );

  final testBoardTheme = ThemeService().activeBoard;

  group('UI Decoupling & AnalysisNotifier Performance Tests', () {
    test('UciEngineService exposes analysisNotifier initialized to null', () {
      final settings = EngineSettings(activeEngine: EngineType.stockfish);
      final service = UciEngineService(settings);

      expect(service.analysisNotifier.value, isNull);
      expect(service.evaluationNotifier.value, equals(NormalizedEvaluation.neutral));
      service.dispose();
    });

    testWidgets('NibblerBoard updates arrows via analysisListenable without full rebuild', (tester) async {
      final initialPos = ChessPosition.initial();
      final analysisNotifier = ValueNotifier<PositionAnalysis?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: NibblerBoard(
                position: initialPos,
                boardTheme: testBoardTheme,
                pieceSet: 'cburnett',
                analysisListenable: analysisNotifier,
                onMove: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify NibblerBoard renders
      expect(find.byType(NibblerBoard), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Emit new analysis via analysisNotifier
      const arrowE2E4 = CandidateArrow(
        from: squareE2,
        to: squareE4,
        uciMove: 'e2e4',
        rank: 1,
        winProbability: 52.0,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      final analysis = PositionAnalysis(
        fen: initialPos.toFen(),
        positionRevision: 1,
        analysisRequestId: 1,
        totalNodes: 100000,
        nodesPerSecond: 25000,
        depth: 18,
        pvLines: const [],
        candidateArrows: const [arrowE2E4],
        isAnalyzing: true,
        engineName: 'Stockfish 19',
        searchState: AnalysisDataState.searching,
      );

      analysisNotifier.value = analysis;
      await tester.pump();

      // Find the CustomPaint with NibblerArrowPainter
      final arrowCustomPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is NibblerArrowPainter,
        ),
      );

      final painter = arrowCustomPaint.painter as NibblerArrowPainter;
      expect(painter.candidateArrows.length, equals(1));
      expect(painter.candidateArrows.first.uciMove, equals('e2e4'));

      analysisNotifier.dispose();
    });

    testWidgets('NibblerBoard ignores candidate arrows when FEN does not match active position', (tester) async {
      final initialPos = ChessPosition.initial();
      final analysisNotifier = ValueNotifier<PositionAnalysis?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: NibblerBoard(
                position: initialPos,
                boardTheme: testBoardTheme,
                pieceSet: 'cburnett',
                analysisListenable: analysisNotifier,
                onMove: (_) {},
              ),
            ),
          ),
        ),
      );

      // Create analysis for a DIFFERENT position FEN
      const differentFen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
      const staleAnalysis = PositionAnalysis(
        fen: differentFen,
        positionRevision: 2,
        analysisRequestId: 2,
        candidateArrows: [
          CandidateArrow(
            from: squareE7,
            to: squareE5,
            uciMove: 'e7e5',
            rank: 1,
            winProbability: 50.0,
            positionRevision: 2,
            requestId: 2,
            style: defaultStyle,
          ),
        ],
        isAnalyzing: true,
        engineName: 'Stockfish 19',
        searchState: AnalysisDataState.searching,
      );

      analysisNotifier.value = staleAnalysis;
      await tester.pump();

      final arrowCustomPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is NibblerArrowPainter,
        ),
      );

      final painter = arrowCustomPaint.painter as NibblerArrowPainter;
      // Because FEN did not match initialPos.toFen(), the stale arrows are strictly suppressed
      expect(painter.candidateArrows.isEmpty, isTrue);

      analysisNotifier.dispose();
    });
  });
}
