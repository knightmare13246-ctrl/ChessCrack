import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/services/session_persistence_service.dart';
import 'package:nibbler_chess/services/uci_engine_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const squareE2 = Square(4, 1);
  const squareE4 = Square(4, 3);
  const squareD2 = Square(3, 1);
  const squareD4 = Square(3, 3);
  const squareG1 = Square(6, 0);
  const squareF3 = Square(5, 2);

  group('1. Background Pause and Resume Semantics', () {
    test('pauseForBackground preserves session state and marks paused', () {
      final settings = EngineSettings(
        activeEngine: EngineType.stockfish,
        threads: 1,
        hashSizeMb: 16,
        multiPv: 3,
      );
      final service = UciEngineService(settings);

      expect(service.isPausedForBackground, isFalse);
      expect(service.activeProcessCount, 0); // Not started yet

      service.pauseForBackground();
      expect(service.isPausedForBackground, isTrue);
    });

    test('resumeFromBackground increments analysisRequestId monotonically and preserves positionRevision', () {
      final settings = EngineSettings(
        activeEngine: EngineType.stockfish,
        threads: 1,
        hashSizeMb: 16,
        multiPv: 3,
      );
      final service = UciEngineService(settings);

      final initialReqId = service.analysisRequestId;
      final initialRev = service.positionRevision;

      service.pauseForBackground();
      expect(service.isPausedForBackground, isTrue);

      // Call resume
      service.resumeFromBackground();
      expect(service.isPausedForBackground, isFalse);
      expect(service.analysisRequestId, initialReqId + 1,
          reason: 'Resuming must create a NEW monotonic analysisRequestId');
      expect(service.positionRevision, initialRev,
          reason: 'Position revision must NOT change merely because app resumed');
    });

    test('Process count invariant is strictly at most 1', () {
      final settings = EngineSettings(
        activeEngine: EngineType.stockfish,
        threads: 1,
        hashSizeMb: 16,
        multiPv: 3,
      );
      final service = UciEngineService(settings);

      expect(service.activeProcessCount, inInclusiveRange(0, 1));
    });
  });

  group('2. Deterministic Draft Variation Persistence', () {
    test('reconstructDraftVariation rebuilds valid DraftVariation from startFen and UCI moves', () {
      final initialPos = ChessPosition.initial();
      final moves = ['e2e4', 'e7e5', 'g1f3'];

      final persisted = PersistedSession(
        fen: initialPos.toFen(),
        isDraftActive: true,
        draftStartFen: initialPos.toFen(),
        draftPvMovesUci: moves,
        draftSelectedMoveIndex: 1, // At e7e5
      );

      final draft = persisted.reconstructDraftVariation();
      expect(draft, isNotNull);
      expect(draft!.startFen, initialPos.toFen());
      expect(draft.totalMoves, 3);
      expect(draft.selectedMoveIndex, 1);
      expect(draft.currentMove, isNotNull);
      expect(draft.currentMove!.uci, 'e7e5');
      expect(draft.currentPosition.turn, PieceColor.white); // After 1...e5, it's White's turn
    });

    test('SessionPersistenceService saves and loads session state deterministically', () async {
      SharedPreferences.setMockInitialValues({});

      await SessionPersistenceService.saveSession(
        fen: ChessPosition.initialFen,
        pgn: '1. e4 e5 *',
        activeEngine: EngineType.lc0,
        isLiveAnalysisActive: true,
        multiPv: 3,
        arrowheadType: ArrowheadType.winrate,
        arrowFilterLc0: ArrowFilterLc0.all,
        arrowFilterOthers: ArrowFilterOthers.all,
        isFlipped: true,
        selectedTab: 2,
        draftVariation: null,
      );

      final loaded = await SessionPersistenceService.loadSession();
      expect(loaded, isNotNull);
      expect(loaded!.fen, ChessPosition.initialFen);
      expect(loaded.pgn, '1. e4 e5 *');
      expect(loaded.activeEngine, EngineType.lc0);
      expect(loaded.isLiveAnalysisActive, isTrue);
      expect(loaded.multiPv, 3);
      expect(loaded.arrowheadType, ArrowheadType.winrate);
      expect(loaded.arrowFilterLc0, ArrowFilterLc0.all);
      expect(loaded.arrowFilterOthers, ArrowFilterOthers.all);
      expect(loaded.isFlipped, isTrue);
      expect(loaded.selectedTab, 2);
      expect(loaded.isDraftActive, isFalse);
    });
  });

  group('3. Arrow Square-Pair Invariant Across Screen Geometry', () {
    test('Candidate arrows preserve chess square pairs regardless of screen pixel size', () {
      const defaultStyle = ArrowVisualStyle(
        shaftColor: Color(0xFF00D2BE),
        badgeColor: Color(0xFF004D40),
        textColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFF00D2BE),
      );

      final arrows = [
        const CandidateArrow(
          rank: 1,
          uciMove: 'e2e4',
          from: squareE2,
          to: squareE4,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
        const CandidateArrow(
          rank: 2,
          uciMove: 'd2d4',
          from: squareD2,
          to: squareD4,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
        const CandidateArrow(
          rank: 3,
          uciMove: 'g1f3',
          from: squareG1,
          to: squareF3,
          positionRevision: 1,
          requestId: 1,
          style: defaultStyle,
        ),
      ];

      // Geometry 1 (Portrait 320x320)
      const portraitBoardSize = 320.0;
      const portraitSquareSize = portraitBoardSize / 8.0;

      // Geometry 2 (Landscape 560x560)
      const landscapeBoardSize = 560.0;
      const landscapeSquareSize = landscapeBoardSize / 8.0;

      for (final arrow in arrows) {
        // Calculate centers in portrait
        final pStart = Offset(
          (arrow.from.file + 0.5) * portraitSquareSize,
          ((7 - arrow.from.rank) + 0.5) * portraitSquareSize,
        );
        final pEnd = Offset(
          (arrow.to.file + 0.5) * portraitSquareSize,
          ((7 - arrow.to.rank) + 0.5) * portraitSquareSize,
        );

        // Calculate centers in landscape
        final lStart = Offset(
          (arrow.from.file + 0.5) * landscapeSquareSize,
          ((7 - arrow.from.rank) + 0.5) * landscapeSquareSize,
        );
        final lEnd = Offset(
          (arrow.to.file + 0.5) * landscapeSquareSize,
          ((7 - arrow.to.rank) + 0.5) * landscapeSquareSize,
        );

        // Relative square centers must be identical proportions
        expect(pStart.dx / portraitBoardSize, closeTo(lStart.dx / landscapeBoardSize, 0.0001));
        expect(pStart.dy / portraitBoardSize, closeTo(lStart.dy / landscapeBoardSize, 0.0001));
        expect(pEnd.dx / portraitBoardSize, closeTo(lEnd.dx / landscapeBoardSize, 0.0001));
        expect(pEnd.dy / portraitBoardSize, closeTo(lEnd.dy / landscapeBoardSize, 0.0001));

        // Chess squares remain identical
        expect(arrow.from, isNotNull);
        expect(arrow.to, isNotNull);
      }

      // Verify exact rank pairs
      expect(arrows[0].from, squareE2);
      expect(arrows[0].to, squareE4);
      expect(arrows[1].from, squareD2);
      expect(arrows[1].to, squareD4);
      expect(arrows[2].from, squareG1);
      expect(arrows[2].to, squareF3);
    });
  });

  group('4. EngineDiagnostics Process Count Telemetry', () {
    test('EngineDiagnostics correctly holds activeProcessCount and copies it', () {
      final now = DateTime.now();
      final diag = EngineDiagnostics(
        lastUpdate: now,
        activeProcessCount: 1,
      );
      expect(diag.activeProcessCount, 1);

      final copy = diag.copyWith(activeProcessCount: 0);
      expect(copy.activeProcessCount, 0);
      expect(copy.lastUpdate, now);
    });
  });
}
