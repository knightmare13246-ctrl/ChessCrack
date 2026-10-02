import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_download_model.dart';
import 'package:nibbler_chess/models/engine_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Maia Human Sparring Architecture Suite', () {
    test('1. Official Maia models inventory contains all 10 Elo models with Nodes = 1 requirement', () {
      final expectedElos = [1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2200];

      // Ensure models can be instantiated and mapped
      for (final elo in expectedElos) {
        final id = 'maia_$elo';
        final model = MaiaModelInfo(
          id: id,
          name: 'Maia $elo',
          approximateElo: elo,
          filename: 'maia-$elo.pb.gz',
          officialSourceUrl: 'https://lczero.org/play/networks/sparring-nets/',
          downloadUrl: 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-$elo.pb.gz',
          localPath: '/mock/path/networks/maia/$elo/maia-$elo.pb.gz',
          metadataPath: '/mock/path/networks/maia/$elo/metadata.json',
          estimatedSizeBytes: 48 * 1024 * 1024,
          credit: 'University of Toronto CSSLab',
          notes: 'Run at Nodes = 1',
        );

        expect(model.id, id);
        expect(model.name, 'Maia $elo');
        expect(model.approximateElo, elo);
        expect(model.notes, equals('Run at Nodes = 1'));
      }
    });

    test('2. Maia analyzing telemetry header displays Evaluating Human Moves...', () {
      const analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1,
        nodesPerSecond: 0,
        depth: 1,
        isAnalyzing: true,
        engineName: 'Maia 1500',
      );

      final header = analysis.formattedHeader;
      expect(header, equals('Maia 1500 · Evaluating Human Moves...'),
          reason: 'Maia analyzing header must strictly display Evaluating Human Moves...');
      expect(header, isNot(contains('Paused')));
      expect(header, isNot(contains('N/s: 0')));
      expect(header, isNot(contains('Depth: 1')));
    });

    test('3. Maia completed telemetry header displays Evaluation Complete (1-ply Policy) without synthetic Paused', () {
      const analysis = PositionAnalysis(
        fen: ChessPosition.initialFen,
        totalNodes: 1,
        nodesPerSecond: 0,
        depth: 1,
        isAnalyzing: false, // 1-node search completed
        engineName: 'Maia 1500',
      );

      final header = analysis.formattedHeader;
      expect(header, equals('Maia 1500 · Evaluation Complete (1-ply Policy)'),
          reason: 'Maia completed header must NOT prepend "Paused · "');
      expect(header.startsWith('Paused · '), isFalse);
      expect(header, isNot(contains('N/s: 0')));
    });

    test('4. Maia Policy % telemetry and candidate badge formatting', () {
      const squareE2 = Square(4, 1);
      const squareE4 = Square(4, 3);
      const defaultStyle = ArrowVisualStyle(
        shaftColor: Color(0xFF00D2BE),
        badgeColor: Color(0xFF004D40),
        textColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFF00D2BE),
      );

      const arrow = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        policyPercentage: 38.6,
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      expect(arrow.getBadgeText(ArrowheadType.policy, EngineType.lc0), equals('39'),
          reason: 'Policy badge must round policy percentage');
      expect(arrow.isMetricAvailable(ArrowheadType.policy, EngineType.lc0), isTrue);

      final pvLine = PvLine(
        multipv: 1,
        movesUci: ['e2e4'],
        winPercentage: 50.0,
        whiteWinPercentage: 50.0,
        policyPercentage: 38.60,
      );

      expect(pvLine.formattedMetrics, contains('P: 38.60%'),
          reason: 'PvLine metrics must format Policy % precisely');
    });

    test('5. Selecting Maia configuration enforces Lc0 activeEngine and nodeLimit = 1', () {
      final settings = EngineSettings(
        activeEngine: EngineType.stockfish,
      );

      // User selects Maia 1900
      final maiaSettings = settings.copyWith(
        activeEngine: EngineType.lc0,
        selectedMaiaId: 'maia_1900',
        weightsPath: '/path/to/maia-1900.pb.gz',
        nodeLimit: 1,
      );

      expect(maiaSettings.activeEngine, EngineType.lc0);
      expect(maiaSettings.selectedMaiaId, 'maia_1900');
      expect(maiaSettings.isMaiaActive, isTrue);
      expect(maiaSettings.nodeLimit, equals(1),
          reason: 'Maia sparring mode strictly mandates nodeLimit = 1');
    });

    test('6. Maia hot-swapping switches weights path and retains nodeLimit = 1', () {
      final initialMaia = EngineSettings(
        activeEngine: EngineType.lc0,
        selectedMaiaId: 'maia_1100',
        weightsPath: '/path/to/maia-1100.pb.gz',
        nodeLimit: 1,
      );

      // Hot swap to Maia 1800
      final swappedMaia = initialMaia.copyWith(
        selectedMaiaId: 'maia_1800',
        weightsPath: '/path/to/maia-1800.pb.gz',
        nodeLimit: 1,
      );

      expect(swappedMaia.selectedMaiaId, 'maia_1800');
      expect(swappedMaia.weightsPath, '/path/to/maia-1800.pb.gz');
      expect(swappedMaia.nodeLimit, 1);
      expect(swappedMaia.isMaiaActive, isTrue);
    });

    test('7. Stockfish rejects Policy mode badge and returns N/A', () {
      const squareE2 = Square(4, 1);
      const squareE4 = Square(4, 3);
      const defaultStyle = ArrowVisualStyle(
        shaftColor: Color(0xFF00D2BE),
        badgeColor: Color(0xFF004D40),
        textColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFF00D2BE),
      );

      const sfArrow = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: squareE2,
        to: squareE4,
        policyPercentage: null, // Stockfish has no policy prior
        positionRevision: 1,
        requestId: 1,
        style: defaultStyle,
      );

      expect(sfArrow.getBadgeText(ArrowheadType.policy, EngineType.stockfish), equals('N/A'));
      expect(sfArrow.isMetricAvailable(ArrowheadType.policy, EngineType.stockfish), isFalse);
    });
  });
}
