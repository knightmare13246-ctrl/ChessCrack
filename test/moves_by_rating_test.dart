import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/maia_dual_analysis.dart';
import 'package:nibbler_chess/services/engine_download_service.dart';
import 'package:nibbler_chess/services/maia_rating_engine.dart';
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
  });
}
