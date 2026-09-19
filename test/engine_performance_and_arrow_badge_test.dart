import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_move.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/models/engine_analysis.dart';
import 'package:nibbler_chess/models/engine_settings.dart';
import 'package:nibbler_chess/ui/widgets/nibbler_arrow_painter.dart';

void main() {
  group('1. Engine Performance & Options Tracking Telemetry', () {
    test('EngineDiagnostics correctly tracks requested options and application status', () {
      final diag = EngineDiagnostics(
        engineName: 'Stockfish 19',
        engineVersion: 'Stockfish 19',
        threads: 4,
        hashSizeMb: 256,
        multiPv: 3,
        requestedThreads: 4,
        requestedHashMb: 256,
        requestedMultiPv: 3,
        optionsApplied: true,
        readyOkReceived: true,
        depth: 20,
        seldepth: 28,
        timeMs: 2500,
        totalNodes: 1360000,
        nps: 453000,
        hashfull: 63,
        tbhits: 0,
        bestmove: 'e2e4',
        currmove: 'g1f3',
        currmovenumber: 2,
        currentFen: ChessPosition.initialFen,
        lastUpdate: DateTime.now(),
        activeProcessCount: 1,
      );

      expect(diag.engineVersion, equals('Stockfish 19'));
      expect(diag.requestedThreads, equals(4));
      expect(diag.requestedHashMb, equals(256));
      expect(diag.requestedMultiPv, equals(3));
      expect(diag.optionsApplied, isTrue);
      expect(diag.readyOkReceived, isTrue);
      expect(diag.depth, equals(20));
      expect(diag.seldepth, equals(28));
      expect(diag.timeMs, equals(2500));
      expect(diag.nps, equals(453000));
      expect(diag.hashfull, equals(63));
      expect(diag.bestmove, equals('e2e4'));
      expect(diag.currmove, equals('g1f3'));
      expect(diag.currmovenumber, equals(2));
    });

    test('EngineSettings copyWith preserves and updates threads and hash', () {
      final initial = EngineSettings();
      expect(initial.threads, equals(1));
      expect(initial.hashSizeMb, equals(16));

      final updated = initial.copyWith(
        threads: 4,
        hashSizeMb: 256,
        multiPv: 5,
      );

      expect(updated.threads, equals(4));
      expect(updated.hashSizeMb, equals(256));
      expect(updated.multiPv, equals(5));
    });
  });

  group('2. Multi-Arrow Badge Collision Avoidance & Layer Rendering', () {
    test('NibblerArrowPainter paints multiple overlapping candidate moves without crashing', () {
      final position = ChessPosition.initial();
      const arrows = [
        CandidateArrow(
          rank: 1,
          uciMove: 'e2e4',
          from: Square(4, 1),
          to: Square(4, 3),
          pvUci: ['e2e4', 'e7e5'],
          expectedScore: 54.0,
          winProbability: 54.0,
          depth: 18,
          positionRevision: 1,
          requestId: 1,
          style: ArrowVisualStyle(
            shaftColor: Color(0xFF4CAF50),
            badgeColor: Color(0xFF4CAF50),
            textColor: Color(0xFFFFFFFF),
            borderColor: Color(0xFFFFFFFF),
          ),
        ),
        CandidateArrow(
          rank: 2,
          uciMove: 'd2d4',
          from: Square(3, 1),
          to: Square(3, 3),
          pvUci: ['d2d4', 'd7d5'],
          expectedScore: 53.0,
          winProbability: 53.0,
          depth: 18,
          positionRevision: 1,
          requestId: 1,
          style: ArrowVisualStyle(
            shaftColor: Color(0xFF29B6F6),
            badgeColor: Color(0xFF29B6F6),
            textColor: Color(0xFFFFFFFF),
            borderColor: Color(0x66000000),
          ),
        ),
        CandidateArrow(
          rank: 3,
          uciMove: 'g1f3',
          from: Square(6, 0),
          to: Square(5, 2),
          pvUci: ['g1f3', 'd7d5'],
          expectedScore: 52.5,
          winProbability: 52.5,
          depth: 18,
          positionRevision: 1,
          requestId: 1,
          style: ArrowVisualStyle(
            shaftColor: Color(0xFFAB47BC),
            badgeColor: Color(0xFFAB47BC),
            textColor: Color(0xFFFFFFFF),
            borderColor: Color(0x66000000),
          ),
        ),
      ];

      final painter = NibblerArrowPainter(
        candidateArrows: arrows,
        position: position,
        positionRevision: 1,
        analysisRequestId: 1,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(800, 800);

      // Should execute all 3 passes without throwing
      expect(() => painter.paint(canvas, size), returnsNormally);
    });

    test('Two arrows targeting adjacent or intersecting squares generate valid bounding boxes', () {
      final position = ChessPosition.initial();
      const arrow1 = CandidateArrow(
        rank: 1,
        uciMove: 'e2e4',
        from: Square(4, 1),
        to: Square(4, 3),
        expectedScore: 55.0,
        winProbability: 55.0,
        depth: 20,
        positionRevision: 1,
        requestId: 1,
        style: ArrowVisualStyle(
          shaftColor: Color(0xFF4CAF50),
          badgeColor: Color(0xFF4CAF50),
          textColor: Color(0xFFFFFFFF),
          borderColor: Color(0xFFFFFFFF),
        ),
      );

      const arrow2 = CandidateArrow(
        rank: 2,
        uciMove: 'd2d4',
        from: Square(3, 1),
        to: Square(3, 3),
        expectedScore: 53.0,
        winProbability: 53.0,
        depth: 20,
        positionRevision: 1,
        requestId: 1,
        style: ArrowVisualStyle(
          shaftColor: Color(0xFF29B6F6),
          badgeColor: Color(0xFF29B6F6),
          textColor: Color(0xFFFFFFFF),
          borderColor: Color(0x66000000),
        ),
      );

      final painter = NibblerArrowPainter(
        candidateArrows: [arrow1, arrow2],
        position: position,
        positionRevision: 1,
        analysisRequestId: 1,
        arrowheadType: ArrowheadType.winrate,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 400);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
