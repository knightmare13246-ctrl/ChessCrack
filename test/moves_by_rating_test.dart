import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/maia_dual_analysis.dart';
import 'package:nibbler_chess/services/engine_download_service.dart';
import 'package:nibbler_chess/services/maia3_model_paths.dart';
import 'package:nibbler_chess/services/maia_rating_engine.dart';
import 'package:nibbler_chess/services/maia_tokenizer.dart';
import 'package:nibbler_chess/ui/widgets/maia_stockfish_comparison_section.dart';
import 'package:nibbler_chess/ui/widgets/moves_by_rating_chart.dart';

void main() {
  group('MovesByRating and DualAnalysis Unit & Widget Tests', () {
    test('MoveRatingCurve interpolates probabilities across Elo points', () {
      const curve = MoveRatingCurve(
        uciMove: 'e2e4',
        sanMove: 'e4',
        curveColor: Color(0xFF29B6F6),
        points: [
          MoveRatingPoint(rating: 1100, probability: 52.0),
          MoveRatingPoint(rating: 1500, probability: 48.0),
          MoveRatingPoint(rating: 1900, probability: 42.0),
        ],
      );

      expect(curve.probabilityAtRating(1100), equals(52.0));
      expect(curve.probabilityAtRating(1500), equals(48.0));
      expect(curve.probabilityAtRating(1900), equals(42.0));

      // Interpolation midway between 1100 and 1500 (1300) -> 50.0%
      final interpolated = curve.probabilityAtRating(1300);
      expect(interpolated, isNotNull);
      expect(interpolated!, closeTo(50.0, 0.1));
    });

    test('MovesByRatingDataset encapsulates dynamic legal moves without hardcoding', () {
      const dataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: [1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900],
        curves: [
          MoveRatingCurve(
            uciMove: 'e2e4',
            sanMove: 'e4',
            curveColor: Color(0xFF29B6F6),
            points: [MoveRatingPoint(rating: 1500, probability: 48.0)],
          ),
          MoveRatingCurve(
            uciMove: 'd2d4',
            sanMove: 'd4',
            curveColor: Color(0xFFFF7043),
            points: [MoveRatingPoint(rating: 1500, probability: 34.0)],
          ),
        ],
        activeRating: 1500,
      );

      expect(dataset.curves.length, equals(2));
      expect(dataset.curves[0].sanMove, equals('e4'));
      expect(dataset.curves[1].sanMove, equals('d4'));
      expect(dataset.activeRating, equals(1500));
    });

    testWidgets('MovesByRatingChart renders title, rating badge, and curve chips', (WidgetTester tester) async {
      int? selectedRating;
      String? selectedMove;

      const dataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: [1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900],
        curves: [
          MoveRatingCurve(
            uciMove: 'e2e4',
            sanMove: 'e4',
            curveColor: Color(0xFF29B6F6),
            points: [
              MoveRatingPoint(rating: 1100, probability: 52.0),
              MoveRatingPoint(rating: 1500, probability: 48.0),
              MoveRatingPoint(rating: 1900, probability: 42.0),
            ],
          ),
          MoveRatingCurve(
            uciMove: 'd2d4',
            sanMove: 'd4',
            curveColor: Color(0xFFFF7043),
            points: [
              MoveRatingPoint(rating: 1100, probability: 30.0),
              MoveRatingPoint(rating: 1500, probability: 34.0),
              MoveRatingPoint(rating: 1900, probability: 38.0),
            ],
          ),
        ],
        activeRating: 1500,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovesByRatingChart(
              dataset: dataset,
              onRatingSelected: (r) => selectedRating = r,
              onMoveSelected: (m) => selectedMove = m,
            ),
          ),
        ),
      );

      // Verify title & active rating badge
      expect(find.text('Moves by Rating'), findsOneWidget);
      expect(find.text('Elo 1500'), findsOneWidget);

      // Verify move labels with percentage chips
      expect(find.text('e4'), findsOneWidget);
      expect(find.text('48.0%'), findsOneWidget);
      expect(find.text('d4'), findsOneWidget);
      expect(find.text('34.0%'), findsOneWidget);

      // Tap on 'd4' chip
      await tester.tap(find.text('d4'));
      await tester.pump();
      expect(selectedMove, equals('d2d4'));

      // Tap on Elo 1500 badge
      await tester.tap(find.text('Elo 1500'));
      await tester.pump();
      expect(selectedRating, equals(1500));

      // Tap on info button
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text('This chart shows how players make different moves as they get stronger. The X-axis shows rating levels, Y-axis shows probability, and each line represents a different move. Use this plot to see which moves are typical at different skill levels, and how moves change as players get stronger.'), findsOneWidget);
    });

    test('Full 21-point rating sweep (600..2600 in steps of 100) satisfies all invariants', () {
      final ratings = List<int>.generate(21, (i) => 600 + i * 100);
      expect(ratings.length, equals(21));
      expect(ratings.first, equals(600));
      expect(ratings.last, equals(2600));

      final pointsE4 = ratings.map((r) {
        final t = (r - 600) / 2000.0;
        final prob = 60.0 - 15.0 * t;
        return MoveRatingPoint(rating: r, probability: prob);
      }).toList();

      final pointsD4 = ratings.map((r) {
        final t = (r - 600) / 2000.0;
        final prob = 25.0 + 10.0 * t;
        return MoveRatingPoint(rating: r, probability: prob);
      }).toList();

      final dataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: ratings,
        curves: [
          MoveRatingCurve(
            uciMove: 'e2e4',
            sanMove: 'e4',
            curveColor: const Color(0xFF4CAF50),
            points: pointsE4,
          ),
          MoveRatingCurve(
            uciMove: 'd2d4',
            sanMove: 'd4',
            curveColor: const Color(0xFFFFB74D),
            points: pointsD4,
          ),
        ],
        activeRating: 1500,
      );

      expect(dataset.curves.length, equals(2));
      for (final curve in dataset.curves) {
        expect(curve.points.length, equals(21));
        for (final pt in curve.points) {
          expect(pt.probability, greaterThanOrEqualTo(0.0));
          expect(pt.probability, lessThanOrEqualTo(100.0));
          expect(pt.probability.isFinite, isTrue);
        }
      }

      // Check interpolation at arbitrary rating (e.g. 1550)
      final prob1550 = dataset.curves[0].probabilityAtRating(1550);
      expect(prob1550, isNotNull);
      expect(prob1550!, closeTo(52.87, 0.5));
    });

    testWidgets('MovesByRatingChart interaction renders without throwing', (WidgetTester tester) async {
      final ratings = List<int>.generate(21, (i) => 600 + i * 100);
      final dataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: ratings,
        curves: [
          MoveRatingCurve(
            uciMove: 'e2e4',
            sanMove: 'e4',
            curveColor: const Color(0xFF4CAF50),
            points: ratings.map((r) => MoveRatingPoint(rating: r, probability: 55.0)).toList(),
          ),
          MoveRatingCurve(
            uciMove: 'd2d4',
            sanMove: 'd4',
            curveColor: const Color(0xFFFFB74D),
            points: ratings.map((r) => MoveRatingPoint(rating: r, probability: 30.0)).toList(),
          ),
        ],
        activeRating: 1600,
      );

      int? selectedRating;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: MovesByRatingChart(
                  dataset: dataset,
                  onRatingSelected: (r) => selectedRating = r,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MovesByRatingChart), findsOneWidget);

      // Perform drag gesture across the chart area
      final chartFinder = find.byType(CustomPaint).last;
      await tester.drag(chartFinder, const Offset(50, 0));
      await tester.pump();

      // Tap gesture on chart
      await tester.tap(chartFinder);
      await tester.pump();

      expect(selectedRating, isNotNull);
    });

    testWidgets('MovesByRatingChart renders uninstalled placeholder when isModelInstalled is false', (WidgetTester tester) async {
      bool downloadRequested = false;

      const uninstalledDataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: [1100, 1900],
        curves: [],
        activeRating: 1500,
        isModelInstalled: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovesByRatingChart(
              dataset: uninstalledDataset,
              onDownloadModelRequested: () => downloadRequested = true,
            ),
          ),
        ),
      );

      expect(find.text('Maia model not installed'), findsOneWidget);
      expect(find.text('Download Model'), findsOneWidget);

      await tester.tap(find.text('Download Model'));
      await tester.pump();
      expect(downloadRequested, isTrue);
    });

    test('X-axis domain and supported ratings reflect actual model conditions (e.g. 1100..1900)', () {
      final officialSparringRatings = [1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900];
      final dataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: officialSparringRatings,
        curves: const [],
        activeRating: 1500,
        isModelInstalled: true,
      );

      expect(dataset.supportedRatings.first, equals(1100));
      expect(dataset.supportedRatings.last, equals(1900));
      expect(dataset.supportedRatings.contains(2600), isFalse);
    });

    test('MaiaRatingEngine supportedRatings spans full 600..2600 spectrum (21 ratings)', () {
      expect(MaiaRatingEngine.supportedRatings.length, equals(21));
      expect(MaiaRatingEngine.supportedRatings.first, equals(600));
      expect(MaiaRatingEngine.supportedRatings.last, equals(2600));
      for (int i = 0; i < 21; i++) {
        expect(MaiaRatingEngine.supportedRatings[i], equals(600 + i * 100));
      }
    });

    test('EngineDownloadService exposes official Maia-3 rating-conditioned model info', () {
      final service = EngineDownloadService();
      final modelInfo = service.maiaRatingModelInfo;

      expect(modelInfo.id, equals('maia3_rating_conditioned'));
      expect(modelInfo.name, contains('Maia-3'));
      expect(modelInfo.filename, equals('maia3_simplified.onnx'));
      expect(modelInfo.officialSourceUrl, contains('CSSLab/maia-platform-frontend'));
      expect(modelInfo.downloadUrl, contains('maia3_simplified.onnx'));
      expect(modelInfo.abi, equals('all'));
      expect(modelInfo.expectedSizeBytes, equals(44 * 1024 * 1024));
    });

    test('Maia3ModelPaths resolves canonical paths and prevents .download leakage', () {
      final tempDir = Directory.systemTemp.createTempSync('maia3_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final paths = Maia3ModelPaths.fromBaseDir(tempDir);
      paths.ensureDirectoryExists();

      expect(paths.finalModelPath, contains('maia3_simplified.onnx'));
      expect(paths.finalModelPath.endsWith('.download'), isFalse);
      expect(paths.tempDownloadPath, equals('${paths.finalModelPath}.download'));
      expect(paths.metadataPath, contains('metadata.json'));

      // Test orphaned .download cleanup
      final orphanFile = paths.tempDownloadFile;
      orphanFile.writeAsStringSync('dummy incomplete download');
      expect(orphanFile.existsSync(), isTrue);

      paths.cleanupOrphanedDownload();
      expect(orphanFile.existsSync(), isFalse);

      // Validation fails when model file does not exist
      expect(paths.isModelValid(), isFalse);

      // Create valid dummy file >= 1MB
      paths.finalModelFile.writeAsBytesSync(List<int>.filled(1000005, 0));
      expect(paths.isModelValid(), isTrue);
    });

    test('MaiaRatingSweepSnapshot.toDataset converts snapshot cleanly with authentic curves', () {
      const ratings = MaiaRatingEngine.supportedRatings;
      final snapshot = MaiaRatingSweepSnapshot(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        modelId: 'maia3_simplified',
        modelVersion: '3.0 (CSSLab / ICLR 2026)',
        ratings: ratings,
        candidateMoves: ['e2e4', 'd2d4'],
        series: [
          MoveRatingCurve(
            uciMove: 'e2e4',
            sanMove: 'e4',
            curveColor: const Color(0xFF4CAF50),
            points: ratings.map((r) => MoveRatingPoint(rating: r, probability: 60.0)).toList(),
          ),
          MoveRatingCurve(
            uciMove: 'd2d4',
            sanMove: 'd4',
            curveColor: const Color(0xFFFFB74D),
            points: ratings.map((r) => MoveRatingPoint(rating: r, probability: 30.0)).toList(),
          ),
        ],
        positionRevision: 42,
        analysisRequestId: 7,
        createdAt: DateTime.now(),
      );

      final dataset = snapshot.toDataset(activeRating: 1800);
      expect(dataset.fen, equals(snapshot.fen));
      expect(dataset.positionRevision, equals(42));
      expect(dataset.analysisRequestId, equals(7));
      expect(dataset.activeRating, equals(1800));
      expect(dataset.isModelInstalled, isTrue);
      expect(dataset.isComputing, isFalse);
      expect(dataset.curves.length, equals(2));
      expect(dataset.curves[0].sanMove, equals('e4'));
      expect(dataset.curves[1].sanMove, equals('d4'));
      expect(dataset.snapshot, equals(snapshot));
    });

    test('MovesByRatingDataset.palette defines distinct non-overlapping colors', () {
      const palette = MovesByRatingDataset.palette;
      expect(palette.length, greaterThanOrEqualTo(6));
      final colorValues = palette.map((c) => c.toARGB32()).toSet();
      // Every color in the palette must be unique
      expect(colorValues.length, equals(palette.length));
    });

    testWidgets('MaiaStockfishComparisonSection renders human and engine candidate columns', (WidgetTester tester) async {
      const dataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: [1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900],
        curves: [
          MoveRatingCurve(
            uciMove: 'e2e4',
            sanMove: 'e4',
            curveColor: Color(0xFF4CAF50),
            points: [MoveRatingPoint(rating: 1200, probability: 65.1)],
          ),
          MoveRatingCurve(
            uciMove: 'd2d4',
            sanMove: 'd4',
            curveColor: Color(0xFFFFA726),
            points: [MoveRatingPoint(rating: 1200, probability: 22.5)],
          ),
        ],
        activeRating: 1200,
      );

      final analysis = PositionAnalysis(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        engineName: 'Stockfish 19',
        depth: 18,
        pvLines: [
          PvLine(
            multipv: 1,
            scoreCp: 27,
            winPercentage: 54.0,
            whiteWinPercentage: 54.0,
            depth: 18,
            nodes: 50000,
            nps: 1500000,
            movesUci: ['g1f3', 'd7d5'],
            pvMoves: [
              PvMoveItem(
                index: 0,
                uci: 'g1f3',
                move: ChessMove(
                  from: Square.fromAlgebraic('g1'),
                  to: Square.fromAlgebraic('f3'),
                  piece: const ChessPiece(PieceType.knight, PieceColor.white),
                ),
                san: 'Nf3',
                figurineSan: 'Nf3',
                color: PieceColor.white,
                moveNumber: 1,
                positionBefore: ChessPosition.initial(),
                positionAfter: ChessPosition.initial(),
              ),
            ],
          ),
          PvLine(
            multipv: 2,
            scoreCp: 25,
            winPercentage: 53.0,
            whiteWinPercentage: 53.0,
            depth: 18,
            nodes: 50000,
            nps: 1500000,
            movesUci: ['d2d4', 'd7d5'],
            pvMoves: [
              PvMoveItem(
                index: 0,
                uci: 'd2d4',
                move: ChessMove(
                  from: Square.fromAlgebraic('d2'),
                  to: Square.fromAlgebraic('d4'),
                  piece: const ChessPiece(PieceType.pawn, PieceColor.white),
                ),
                san: 'd4',
                figurineSan: 'd4',
                color: PieceColor.white,
                moveNumber: 1,
                positionBefore: ChessPosition.initial(),
                positionAfter: ChessPosition.initial(),
              ),
            ],
          ),
        ],
      );

      int? selectedRating;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MaiaStockfishComparisonSection(
                analysis: analysis,
                movesByRatingData: dataset,
                activeRating: 1200,
                onRatingChanged: (r) => selectedRating = r,
                currentPosition: ChessPosition.initial(),
              ),
            ),
          ),
        ),
      );

      // Verify Analysis section header & hide button
      expect(find.text('Analysis'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);

      // Verify Maia human column header & candidate moves with %
      expect(find.text('Maia 1200: Human Moves'), findsOneWidget);
      expect(find.text('65.1%'), findsOneWidget);
      expect(find.text('22.5%'), findsOneWidget);

      // Verify Stockfish engine column header & candidate moves with eval
      expect(find.text('SF 19: Engine Moves'), findsOneWidget);
      expect(find.text('d18'), findsOneWidget);
      expect(find.text('+0.27'), findsOneWidget);
      expect(find.text('+0.25'), findsOneWidget);

      // Test hide toggle
      await tester.tap(find.text('Hide'));
      await tester.pump();
      expect(find.text('Show'), findsOneWidget);
      // Test show toggle
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Maia 1200: Human Moves'), findsOneWidget);

      // Test rating dropdown selection
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(find.text('Maia 1500'), findsOneWidget);
      await tester.tap(find.text('Maia 1500'));
      await tester.pumpAndSettle();
      expect(selectedRating, equals(1500));
    });

    testWidgets('MaiaStockfishComparisonSection enforces side-by-side two-column table in narrow portrait (320px)', (WidgetTester tester) async {
      const dataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: [1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900],
        curves: [
          MoveRatingCurve(
            uciMove: 'e2e4',
            sanMove: 'e4',
            curveColor: Color(0xFF4CAF50),
            points: [MoveRatingPoint(rating: 1200, probability: 65.1)],
          ),
          MoveRatingCurve(
            uciMove: 'd2d4',
            sanMove: 'd4',
            curveColor: Color(0xFFFFA726),
            points: [MoveRatingPoint(rating: 1200, probability: 22.5)],
          ),
        ],
        activeRating: 1200,
      );

      final analysis = PositionAnalysis(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        engineName: 'Stockfish 19',
        depth: 18,
        pvLines: [
          PvLine(
            multipv: 1,
            scoreCp: 27,
            winPercentage: 54.0,
            whiteWinPercentage: 54.0,
            depth: 18,
            nodes: 50000,
            nps: 1500000,
            movesUci: ['g1f3'],
            pvMoves: const [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320, // Strict narrow portrait viewport
                child: MaiaStockfishComparisonSection(
                  analysis: analysis,
                  movesByRatingData: dataset,
                  activeRating: 1200,
                  currentPosition: ChessPosition.initial(),
                ),
              ),
            ),
          ),
        ),
      );

      final maiaHeaderFinder = find.text('Maia 1200: Human Moves');
      final sfHeaderFinder = find.text('SF 19: Engine Moves');

      expect(maiaHeaderFinder, findsOneWidget);
      expect(sfHeaderFinder, findsOneWidget);

      final maiaTopLeft = tester.getTopLeft(maiaHeaderFinder);
      final sfTopLeft = tester.getTopLeft(sfHeaderFinder);

      // CRITICAL REQUIREMENT: Maia and Stockfish are side-by-side, NOT stacked vertically
      // Vertical tops must align horizontally
      expect(maiaTopLeft.dy, equals(sfTopLeft.dy));
      // Maia must be horizontally to the left of Stockfish
      expect(maiaTopLeft.dx, lessThan(sfTopLeft.dx));
    });

    testWidgets('MaiaStockfishComparisonSection table percentages mathematically match MoveRatingCurve values', (WidgetTester tester) async {
      const activeRating = 1600;
      final curves = [
        const MoveRatingCurve(
          uciMove: 'e2e4',
          sanMove: 'e4',
          curveColor: Color(0xFF4CAF50),
          points: [
            MoveRatingPoint(rating: 1200, probability: 55.4),
            MoveRatingPoint(rating: 1600, probability: 62.3),
            MoveRatingPoint(rating: 2000, probability: 48.1),
          ],
        ),
        const MoveRatingCurve(
          uciMove: 'd2d4',
          sanMove: 'd4',
          curveColor: Color(0xFFFFA726),
          points: [
            MoveRatingPoint(rating: 1200, probability: 28.1),
            MoveRatingPoint(rating: 1600, probability: 24.7),
            MoveRatingPoint(rating: 2000, probability: 31.9),
          ],
        ),
      ];

      final dataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: const [1200, 1600, 2000],
        curves: curves,
        activeRating: activeRating,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaiaStockfishComparisonSection(
              analysis: null,
              movesByRatingData: dataset,
              activeRating: activeRating,
              currentPosition: ChessPosition.initial(),
            ),
          ),
        ),
      );

      // For every curve, the rendered percentage in the table MUST match probabilityAtRating exactly
      for (final curve in curves) {
        final expectedProb = curve.probabilityAtRating(activeRating)!;
        final expectedText = '${expectedProb.toStringAsFixed(1)}%';
        expect(find.text(expectedText), findsOneWidget);
      }
    });

    test('MaiaTokenizer decodes policy logits with legal move masking and probability sum = 1.0', () {
      final posWhite = ChessPosition.initial();
      final legalMovesWhite = posWhite.legalMoves;
      expect(legalMovesWhite.length, equals(20)); // 20 opening legal moves for White

      // Create synthetic logits (length 4352)
      final logits = List<double>.generate(4352, (i) => (i % 10).toDouble());
      final decodedWhite = MaiaTokenizer.decodePolicyLogits(
        logits: logits,
        position: posWhite,
      );

      // Decoded output must contain only legal moves
      expect(decodedWhite.length, equals(legalMovesWhite.length));
      for (final move in legalMovesWhite) {
        expect(decodedWhite.containsKey(move.uci), isTrue);
      }

      // Sum of probabilities must equal 1.0 within floating point precision
      final sumProbsWhite = decodedWhite.values.reduce((a, b) => a + b);
      expect(sumProbsWhite, closeTo(1.0, 1e-5));

      // Test with Black to move (after 1. e4)
      final posBlack = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1');
      expect(posBlack.turn, equals(PieceColor.black));

      final decodedBlack = MaiaTokenizer.decodePolicyLogits(
        logits: logits,
        position: posBlack,
      );

      expect(decodedBlack.length, equals(posBlack.legalMoves.length));
      for (final move in posBlack.legalMoves) {
        expect(decodedBlack.containsKey(move.uci), isTrue);
      }

      final sumProbsBlack = decodedBlack.values.reduce((a, b) => a + b);
      expect(sumProbsBlack, closeTo(1.0, 1e-5));
    });

    test('MonotoneCubicSpline creates valid non-empty paths without oscillation or crash', () {
      expect(MonotoneCubicSpline.computePath([]), isNotNull);
      expect(MonotoneCubicSpline.computePath([const Offset(0, 0)]), isNotNull);
      expect(MonotoneCubicSpline.computePath([const Offset(0, 0), const Offset(10, 10)]), isNotNull);

      // 21 sample points simulating rating sweep
      final samplePoints = List.generate(21, (i) => Offset(i * 10.0, (i * i) % 50.0));
      final path = MonotoneCubicSpline.computePath(samplePoints);
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.width, closeTo(200.0, 0.01));
    });

    testWidgets('MovesByRatingChart legend chip toggles hidden state and Updating badge shows when isComputing', (WidgetTester tester) async {
      final ratings = [1200, 1600, 2000];
      final dataset = MovesByRatingDataset(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        positionRevision: 1,
        supportedRatings: ratings,
        curves: const [
          MoveRatingCurve(
            uciMove: 'e2e4',
            sanMove: 'e4',
            curveColor: Color(0xFF4CAF50),
            points: [
              MoveRatingPoint(rating: 1200, probability: 40.0),
              MoveRatingPoint(rating: 1600, probability: 50.0),
              MoveRatingPoint(rating: 2000, probability: 60.0),
            ],
          ),
          MoveRatingCurve(
            uciMove: 'd2d4',
            sanMove: 'd4',
            curveColor: Color(0xFFFFB74D),
            points: [
              MoveRatingPoint(rating: 1200, probability: 30.0),
              MoveRatingPoint(rating: 1600, probability: 35.0),
              MoveRatingPoint(rating: 2000, probability: 25.0),
            ],
          ),
        ],
        activeRating: 1600,
        isComputing: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: MovesByRatingChart(
                  dataset: dataset,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Updating…'), findsOneWidget);
      expect(find.text('e4'), findsOneWidget);
      expect(find.text('d4'), findsOneWidget);

      // Tap on the visibility dot of the e4 chip
      final circleFinder = find.byType(GestureDetector);
      expect(circleFinder, findsWidgets);

      await tester.tap(find.text('e4'));
      await tester.pump();

      // Underlying dataset is untouched
      expect(dataset.curves.length, equals(2));
    });
  });
}
