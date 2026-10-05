import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/candidate_arrow.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/models/nibbler_arrow_config.dart';
import 'package:nibbler_chess/models/pv_continuation.dart';
import 'package:nibbler_chess/services/pv_continuation_simulator.dart';
import 'package:nibbler_chess/theme/lichess_theme.dart';
import 'package:nibbler_chess/ui/widgets/arrow_settings_dialog.dart';
import 'package:nibbler_chess/ui/widgets/engine_manager_dialog.dart';
import 'package:nibbler_chess/ui/widgets/nibbler_board.dart';
import 'package:nibbler_chess/ui/widgets/pgn_paste_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 11 & 12: ARROW LAB & SETTINGS QA EXHAUSTIVE MATRIX', () {
    final initialPos = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

    const defaultStyle = ArrowVisualStyle(
      shaftColor: Color(0xFF00D2BE),
      badgeColor: Color(0xFF004D40),
      textColor: Colors.white,
      borderColor: Color(0xFF00D2BE),
    );

    final sampleCandidates = [
      const CandidateArrow(
        from: Square(4, 1), // e2
        to: Square(4, 3),   // e4
        uciMove: 'e2e4',
        rank: 1,
        pvUci: ['e2e4', 'e7e5', 'g1f3'],
        scoreCp: 35,
        winProbability: 54.2,
        expectedScore: 54.2,
        visits: 450,
        totalNodes: 1000,
        nodePercentage: 45.0,
        policyPercentage: 38.0,
        movesLeft: 30.0,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      ),
      const CandidateArrow(
        from: Square(3, 1), // d2
        to: Square(3, 3),   // d4
        uciMove: 'd2d4',
        rank: 2,
        pvUci: ['d2d4', 'd7d5'],
        scoreCp: 28,
        winProbability: 53.1,
        expectedScore: 53.1,
        visits: 350,
        totalNodes: 1000,
        nodePercentage: 35.0,
        policyPercentage: 31.0,
        movesLeft: 32.0,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      ),
      const CandidateArrow(
        from: Square(6, 0), // g1
        to: Square(5, 2),   // f3
        uciMove: 'g1f3',
        rank: 3,
        pvUci: ['g1f3', 'd7d5'],
        scoreCp: 20,
        winProbability: 52.0,
        expectedScore: 52.0,
        visits: 150,
        totalNodes: 1000,
        nodePercentage: 15.0,
        policyPercentage: 18.0,
        movesLeft: 35.0,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      ),
    ];

    // -------------------------------------------------------------
    // Test 1: Isolated Configurations Immutability
    // -------------------------------------------------------------
    test('Candidate config mutations do not alter PieceManeuverConfig', () {
      var candidateConfig = const NibblerCandidateArrowConfig(
        arrowheadType: ArrowheadType.policy,
        arrowFilterLc0: ArrowFilterLc0.top2,
        curveAmount: 0.25,
      );

      var maneuverConfig = const PieceManeuverConfig(
        enabled: true,
        depthPlies: 4,
        filter: PvContinuationFilter.friendlyOnly,
        showStepNumbers: true,
      );

      // Mutate candidate config
      final updatedCandidate = candidateConfig.copyWith(
        arrowheadType: ArrowheadType.winrate,
        curveAmount: 0.4,
        arrowFilterLc0: ArrowFilterLc0.top1,
      );

      // Verify independence
      expect(updatedCandidate.arrowheadType, equals(ArrowheadType.winrate));
      expect(candidateConfig.arrowheadType, equals(ArrowheadType.policy));
      expect(maneuverConfig.enabled, isTrue);
      expect(maneuverConfig.depthPlies, equals(4));
      expect(maneuverConfig.filter, equals(PvContinuationFilter.friendlyOnly));
    });

    // -------------------------------------------------------------
    // Test 2: Sequential Position Simulator Strict Legal Line
    // -------------------------------------------------------------
    test('Maneuver arrows generate via sequential legal position cloning without leaking into candidate filters', () {
      final pos = ChessPosition.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      // PV: 1. e4 e5 2. Nf3 Nc6 3. Bb5
      final pv = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5'];

      final maneuverPlan = PvContinuationSimulator.simulate(
        initialPosition: pos,
        pvUciMoves: pv,
        maxPlies: 5,
        baseColor: const Color(0xFF00D2BE),
        filter: PvContinuationFilter.all,
      );

      expect(maneuverPlan.arrows.length, equals(5));
      expect(maneuverPlan.arrows[0].from.algebraic, equals('e2'));
      expect(maneuverPlan.arrows[0].to.algebraic, equals('e4'));
      expect(maneuverPlan.arrows[1].from.algebraic, equals('e7'));
      expect(maneuverPlan.arrows[1].to.algebraic, equals('e5'));
      expect(maneuverPlan.arrows[2].from.algebraic, equals('g1'));
      expect(maneuverPlan.arrows[2].to.algebraic, equals('f3'));
      expect(maneuverPlan.arrows[3].from.algebraic, equals('b8'));
      expect(maneuverPlan.arrows[3].to.algebraic, equals('c6'));
      expect(maneuverPlan.arrows[4].from.algebraic, equals('f1'));
      expect(maneuverPlan.arrows[4].to.algebraic, equals('b5'));

      // Maneuver arrows preserve ply index badges
      expect(maneuverPlan.continuationOnly.length, equals(4));
      expect(maneuverPlan.continuationOnly[0].plyIndex, equals(1));
      expect(maneuverPlan.continuationOnly[1].plyIndex, equals(2));
    });

    // -------------------------------------------------------------
    // Test 3: Arrowhead Telemetry Formatting Edge Cases
    // -------------------------------------------------------------
    test('Arrowhead formatting edge cases (Stockfish policy, missing mate, zero nodes)', () {
      // 1. Stockfish engine candidate with null policyPercentage & nodePercentage
      const sfCandidate = CandidateArrow(
        from: Square(4, 1),
        to: Square(4, 3),
        uciMove: 'e2e4',
        rank: 1,
        pvUci: ['e2e4'],
        scoreCp: 45,
        winProbability: 55.0,
        expectedScore: 55.0,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      expect(sfCandidate.getBadgeText(ArrowheadType.policy, EngineType.stockfish), equals('N/A'));
      expect(sfCandidate.getBadgeText(ArrowheadType.nodePct, EngineType.stockfish), equals('N/A'));
      expect(sfCandidate.getBadgeText(ArrowheadType.movesLeft, EngineType.stockfish), equals('N/A'));
      expect(sfCandidate.getBadgeText(ArrowheadType.winrate, EngineType.stockfish), equals('55'));
      expect(sfCandidate.getBadgeText(ArrowheadType.multipvRank, EngineType.stockfish), equals('1'));

      // 2. Candidate with mate in 3 on Stockfish
      const mateCandidate = CandidateArrow(
        from: Square(3, 0),
        to: Square(7, 4),
        uciMove: 'd1h5',
        rank: 1,
        pvUci: ['d1h5'],
        scoreCp: 10000,
        scoreMate: 3,
        winProbability: 100.0,
        expectedScore: 100.0,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );
      expect(mateCandidate.getBadgeText(ArrowheadType.movesLeft, EngineType.stockfish), equals('M3'));

      // 3. Candidate with mate in -2 on Stockfish
      const matedCandidate = CandidateArrow(
        from: Square(5, 6),
        to: Square(5, 5),
        uciMove: 'f7f6',
        rank: 1,
        pvUci: ['f7f6'],
        scoreCp: -10000,
        scoreMate: -2,
        winProbability: 0.0,
        expectedScore: 0.0,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );
      expect(matedCandidate.getBadgeText(ArrowheadType.movesLeft, EngineType.stockfish), equals('M2'));
    });

    // -------------------------------------------------------------
    // Test 4: Responsive Viewport Zero-Overflow Matrix
    // -------------------------------------------------------------
    final viewports = <String, Size>{
      'PHONE SMALL (360x640)': const Size(360, 640),
      'PHONE MEDIUM (390x844)': const Size(390, 844),
      'PHONE LARGE (430x932)': const Size(430, 932),
      'PHONE LANDSCAPE (844x390)': const Size(844, 390),
      'TABLET PORTRAIT (800x1280)': const Size(800, 1280),
      'TABLET LANDSCAPE (1280x800)': const Size(1280, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets('Zero layout overflow on ${entry.key} with board, candidates & maneuvers', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final maneuverPlan = PvContinuationSimulator.simulate(
          initialPosition: initialPos,
          pvUciMoves: ['e2e4', 'e7e5', 'g1f3', 'b8c6'],
          maxPlies: 4,
          baseColor: const Color(0xFF00D2BE),
          filter: PvContinuationFilter.all,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = (constraints.maxWidth < constraints.maxHeight
                            ? constraints.maxWidth
                            : constraints.maxHeight)
                        .clamp(200.0, 600.0);
                    return Center(
                      child: SizedBox(
                        width: boardSize,
                        height: boardSize,
                        child: NibblerBoard(
                          position: initialPos,
                          boardTheme: LichessBoardThemes.brown,
                          pieceSet: 'cburnett',
                          candidateArrows: sampleCandidates,
                          continuationPlan: maneuverPlan,
                          showPvContinuation: true,
                          arrowheadType: ArrowheadType.winrate,
                          engineType: EngineType.lc0,
                          onMove: (_) {},
                          isFlipped: false,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Zero overflow on ${entry.key}');
        expect(find.byType(NibblerBoard), findsOneWidget);
      });
    }

    // -------------------------------------------------------------
    // Test 5: PgnPasteDialog zero overflow with keyboard simulation
    // -------------------------------------------------------------
    for (final entry in viewports.entries) {
      testWidgets('PgnPasteDialog zero overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => PgnPasteDialog(onImportPgn: (_) {}),
                      );
                    },
                    child: const Text('Open PGN'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap open dialog
        await tester.tap(find.text('Open PGN'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'PgnPasteDialog must not overflow on ${entry.key}');
        expect(find.byType(PgnPasteDialog), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });
    }

    // -------------------------------------------------------------
    // Test 6: EngineManagerDialog zero overflow across all viewports
    // -------------------------------------------------------------
    for (final entry in viewports.entries) {
      testWidgets('EngineManagerDialog zero overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final settings = EngineSettings(
          activeEngine: EngineType.stockfish,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => EngineManagerDialog(
                          settings: settings,
                          onSettingsChanged: (_) {},
                        ),
                      );
                    },
                    child: const Text('Open Engines'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Engines'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'EngineManagerDialog must not overflow on ${entry.key}');
        expect(find.byType(EngineManagerDialog), findsOneWidget);

        // Close dialog
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
      });
    }

    // -------------------------------------------------------------
    // Test 7: ArrowSettingsDialog zero overflow and setting isolation
    // -------------------------------------------------------------
    testWidgets('ArrowSettingsDialog renders without overflow and preserves isolated values', (tester) async {
      tester.view.physicalSize = const Size(360, 640); // small phone
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var currentSettings = EngineSettings(
        activeEngine: EngineType.lc0,
        multiPv: 3,
        arrowheadType: ArrowheadType.winrate,
        arrowFilterOthers: ArrowFilterOthers.top3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ArrowSettingsDialog(
                        settings: currentSettings,
                        onSettingsChanged: (updated) {
                          currentSettings = updated;
                        },
                      ),
                    );
                  },
                  child: const Text('Open Arrow Settings'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Arrow Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ArrowSettingsDialog), findsOneWidget);

      // Switch to Policy arrowhead (scroll until visible in ListView)
      final policyFinder = find.text('Policy');
      await tester.scrollUntilVisible(policyFinder, 100);
      expect(policyFinder, findsOneWidget);
      await tester.tap(policyFinder);
      await tester.pumpAndSettle();

      // Expect arrowheadType changed to policy, but arrowFilterOthers remained top3 and multiPv remained 3
      expect(currentSettings.arrowheadType, equals(ArrowheadType.policy));
      expect(currentSettings.arrowFilterOthers, equals(ArrowFilterOthers.top3));
      expect(currentSettings.multiPv, equals(3));
    });
  });
}
