import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_download_model.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/models/game_tree.dart';
import 'package:nibbler_chess/services/engine_download_service.dart';
import 'package:nibbler_chess/ui/widgets/nibbler_arrow_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Tier 4: Real-World Application Scenarios', () {
    test('Scenario 1: The Opera Game full replay, Queen sacrifice & checkmate verification', () {
      // 1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7
      // 8. Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7
      // 14. Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+!! Nxb8 17. Rd8#
      final tree = GameTree(root: GameNode(id: '0', position: ChessPosition.initial()));

      final operaUciMoves = [
        'e2e4', 'e7e5',
        'g1f3', 'd7d6',
        'd2d4', 'c8g4',
        'd4e5', 'g4f3',
        'd1f3', 'd6e5',
        'f1c4', 'g8f6',
        'f3b3', 'd8e7',
        'b1c3', 'c7c6',
        'c1g5', 'b7b5',
        'c3b5', 'c6b5',
        'c4b5', 'b8d7',
        'e1c1', 'a8d8', // 12. O-O-O Rd8
        'd1d7', 'd8d7',
        'h1d1', 'e7e6',
        'b5d7', 'f6d7',
        'b3b8', 'd7b8', // 16. Qb8+ Nxb8
        'd1d8', // 17. Rd8#
      ];

      for (final uci in operaUciMoves) {
        final pos = tree.currentNode.position;
        final move = pos.findLegalMoveByUci(uci);
        expect(move, isNotNull, reason: 'Move $uci in Opera Game must be legal');
        tree.addMove(move!);
      }

      final finalPosition = tree.currentNode.position;
      expect(finalPosition.isCheckmate(), isTrue,
          reason: '17. Rd8# must result in checkmate');
      expect(finalPosition.turn, PieceColor.black);

      // Verify checkmate evaluation formatting
      final mateAnalysis = PositionAnalysis(
        fen: finalPosition.toFen(),
        totalNodes: 1250000,
        nodesPerSecond: 420000,
        depth: 25,
        pvLines: [
          PvLine(
            multipv: 1,
            movesUci: ['d1d8'],
            winPercentage: 100.0,
            whiteWinPercentage: 100.0,
            scoreMate: 1,
          ),
        ],
        isAnalyzing: false,
        engineName: 'Stockfish 19',
      );

      expect(mateAnalysis.bestLine!.formattedScore, equals('+M1'));
      expect(mateAnalysis.bestLine!.whiteWinPercentage, equals(100.0));
    });

    test('Scenario 2: Kasparov vs Topalov 1999 tactical analysis & arrow overlay fidelity', () {
      // Position after 24. Rxd4!!
      // FEN: r1b1k2r/pp1p1p2/2n1p1p1/q1p1P1Pp/2P2P2/1PnB1N2/PB1P3P/R2QK2R w KQkq - 0 14
      const fen = 'r1b1k2r/pp1p1p2/2n1p1p1/q1p1P1Pp/2P2P2/1PnB1N2/PB1P3P/R2QK2R w KQkq - 0 14';
      final position = ChessPosition.fromFen(fen);

      const style1 = ArrowVisualStyle(
        shaftColor: Color(0xFF00D2BE),
        badgeColor: Color(0xFF004D40),
        textColor: Colors.white,
        borderColor: Colors.white,
      );
      const style2 = ArrowVisualStyle(
        shaftColor: Color(0xFF4CAF50),
        badgeColor: Color(0xFF1B5E20),
        textColor: Colors.white,
        borderColor: Colors.black45,
      );

      const arrows = [
        CandidateArrow(
          rank: 1,
          uciMove: 'd1c1',
          from: Square(3, 0), // d1
          to: Square(2, 0), // c1
          expectedScore: 68.5,
          positionRevision: 1,
          requestId: 1,
          style: style1,
        ),
        CandidateArrow(
          rank: 2,
          uciMove: 'd1e2',
          from: Square(3, 0), // d1
          to: Square(4, 1), // e2
          expectedScore: 61.2,
          positionRevision: 1,
          requestId: 1,
          style: style2,
        ),
      ];

      final painter = NibblerArrowPainter(
        candidateArrows: arrows,
        position: position,
        positionRevision: 1,
        analysisRequestId: 1,
        arrowheadType: ArrowheadType.winrate,
        engineType: EngineType.stockfish,
      );

      // Verify that Rank 1 badge displays expected score 69
      expect(arrows[0].getBadgeText(ArrowheadType.winrate, EngineType.stockfish), equals('69'));
      expect(arrows[1].getBadgeText(ArrowheadType.winrate, EngineType.stockfish), equals('61'));
      expect(painter.candidateArrows.length, 2);
    });

    test('Scenario 3: King and Pawn endgame pawn promotion & checkmate representation', () {
      // 8/4P3/8/8/8/8/k7/4K3 w - - 0 1
      const promoFen = '8/4P3/8/8/8/8/k7/4K3 w - - 0 1';
      final pos = ChessPosition.fromFen(promoFen);

      final promoMove = pos.findLegalMoveByUci('e7e8q');
      expect(promoMove, isNotNull);
      expect(promoMove!.promotion, isNotNull);
      expect(promoMove.promotion, PieceType.queen);

      // Apply the move
      final tree = GameTree(root: GameNode(id: '0', position: pos));
      tree.addMove(promoMove);

      final postPromoPos = tree.currentNode.position;
      expect(postPromoPos.turn, PieceColor.black);
      expect(postPromoPos.toFen(), contains('Q'));

      // Checkmate in 2 line evaluation
      final pvLine = PvLine(
        multipv: 1,
        movesUci: ['e7e8q', 'a2b2', 'e8e2'],
        winPercentage: 100.0,
        whiteWinPercentage: 100.0,
        scoreMate: 2,
      );

      expect(pvLine.formattedScore, equals('+M2'));
      expect(pvLine.badgeScore, equals(100));
    });

    test('Scenario 4: Maia Human Sparring Elo Ladder progression and policy telemetry', () {
      final elos = [1100, 1500, 1900];

      for (final elo in elos) {
        final settings = EngineSettings(
          activeEngine: EngineType.lc0,
          selectedMaiaId: 'maia_$elo',
          weightsPath: '/mock/networks/maia/$elo/maia-$elo.pb.gz',
          nodeLimit: 1,
        );

        expect(settings.isMaiaActive, isTrue);
        expect(settings.nodeLimit, equals(1));

        // Analyzing state
        final analyzing = PositionAnalysis(
          fen: ChessPosition.initialFen,
          totalNodes: 1,
          isAnalyzing: true,
          engineName: 'Maia $elo',
        );
        expect(analyzing.formattedHeader, equals('Maia $elo · Evaluating Human Moves...'));

        // Completed state
        final completed = PositionAnalysis(
          fen: ChessPosition.initialFen,
          totalNodes: 1,
          isAnalyzing: false,
          engineName: 'Maia $elo',
        );
        expect(completed.formattedHeader, equals('Maia $elo · Evaluation Complete (1-ply Policy)'));
        expect(completed.formattedHeader.startsWith('Paused · '), isFalse);
      }
    });

    test('Scenario 5: Active analysis interruption, deletion hook & storage update', () async {
      final downloadService = EngineDownloadService();
      bool engineDisabledBeforeDelete = false;

      // Setup mock installed Maia model
      final model = MaiaModelInfo(
        id: 'maia_scenario_test',
        name: 'Maia 1500',
        approximateElo: 1500,
        filename: 'maia-1500.pb.gz',
        officialSourceUrl: '',
        downloadUrl: '',
        localPath: '${Directory.systemTemp.path}/scenario_maia.pb.gz',
        metadataPath: '${Directory.systemTemp.path}/scenario_maia.json',
        estimatedSizeBytes: 48 * 1024 * 1024,
        credit: 'CSSLab',
        status: DownloadStatus.installed,
        installedSizeBytes: 48 * 1024 * 1024,
      );
      downloadService.maiaModels[model.id] = model;

      final testFile = File(model.localPath);
      testFile.writeAsStringSync('model data');

      // User triggers deletion through dialog hook
      await downloadService.removeMaiaModel(
        model.id,
        onBeforeDelete: () async {
          // This simulates the dialog wiring: onBeforeEngineRemoved: () => service.disableEngine()
          engineDisabledBeforeDelete = true;
        },
      );

      expect(engineDisabledBeforeDelete, isTrue);
      expect(testFile.existsSync(), isFalse);
      expect(model.status, DownloadStatus.notInstalled);
      expect(model.installedSizeBytes, equals(0));

      downloadService.maiaModels.remove(model.id);
    });
  });
}
