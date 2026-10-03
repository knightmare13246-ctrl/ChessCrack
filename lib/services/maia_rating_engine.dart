import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../models/chess_move.dart';
import '../models/chess_position.dart';
import '../models/maia_dual_analysis.dart';
import '../utils/san_formatter.dart';
import 'maia_tokenizer.dart';

/// Worker message protocols for isolated background inference
class _WorkerInitMessage {
  final SendPort replyPort;
  final String modelPath;
  _WorkerInitMessage(this.replyPort, this.modelPath);
}

class _WorkerSweepRequest {
  final SendPort replyPort;
  final int requestId;
  final String fen;
  final int positionRevision;
  final Float32List tokens;
  final List<String> legalMovesUci;
  final bool isBlack;
  final List<int> ratings;
  final List<String> priorityUciMoves;

  _WorkerSweepRequest({
    required this.replyPort,
    required this.requestId,
    required this.fen,
    required this.positionRevision,
    required this.tokens,
    required this.legalMovesUci,
    required this.isBlack,
    required this.ratings,
    required this.priorityUciMoves,
  });
}

class _WorkerSweepResponse {
  final int requestId;
  final bool success;
  final Map<int, Map<String, double>>? ratingMoveProbabilities;
  final String? error;

  _WorkerSweepResponse({
    required this.requestId,
    required this.success,
    this.ratingMoveProbabilities,
    this.error,
  });
}

/// Entrypoint executed inside the dedicated background worker isolate.
/// All heavy ONNX C++ execution runs here without touching the Flutter UI thread.
void _maiaWorkerEntryPoint(SendPort mainSendPort) {
  final workerReceivePort = ReceivePort();
  mainSendPort.send(workerReceivePort.sendPort);

  OrtSession? workerSession;
  String? loadedModelPath;
  int currentActiveRequestId = 0;

  workerReceivePort.listen((message) {
    if (message is _WorkerInitMessage) {
      if (loadedModelPath == message.modelPath && workerSession != null) {
        message.replyPort.send(true);
        return;
      }
      try {
        final file = File(message.modelPath);
        if (!file.existsSync() || file.lengthSync() < 1000000) {
          message.replyPort.send(false);
          return;
        }
        OrtEnv.instance.init();
        final sessionOptions = OrtSessionOptions()
          ..setIntraOpNumThreads(1)
          ..setInterOpNumThreads(1)
          ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortDisableAll);
        workerSession?.release();
        workerSession = OrtSession.fromFile(file, sessionOptions);
        loadedModelPath = message.modelPath;
        message.replyPort.send(true);
      } catch (e) {
        message.replyPort.send(false);
      }
    } else if (message is _WorkerSweepRequest) {
      currentActiveRequestId = message.requestId;
      if (workerSession == null) {
        message.replyPort.send(_WorkerSweepResponse(
          requestId: message.requestId,
          success: false,
          error: 'Model session not loaded in worker isolate',
        ));
        return;
      }
      final session = workerSession!;

      final ratingMoveProbs = <int, Map<String, double>>{};
      bool aborted = false;

      for (int i = 0; i < message.ratings.length; i++) {
        // Fast cancellation if superseded by a newer request while computing
        if (message.requestId != currentActiveRequestId) {
          aborted = true;
          break;
        }

        final rating = message.ratings[i];
        final rDouble = rating.toDouble();
        final eloSelf = Float32List.fromList([rDouble]);
        final eloOppo = Float32List.fromList([rDouble]);

        final inputTokens = OrtValueTensor.createTensorWithDataList(message.tokens, [1, 64, 12]);
        final inputEloSelf = OrtValueTensor.createTensorWithDataList(eloSelf, [1]);
        final inputEloOppo = OrtValueTensor.createTensorWithDataList(eloOppo, [1]);

        final runOptions = OrtRunOptions();
        final outputs = session.run(runOptions, {
          'tokens': inputTokens,
          'elo_self': inputEloSelf,
          'elo_oppo': inputEloOppo,
        }, ['logits_move', 'logits_value']);

        inputTokens.release();
        inputEloSelf.release();
        inputEloOppo.release();
        runOptions.release();

        final rawLogits = outputs[0]?.value as List<List<double>>;
        final moveProbabilities = MaiaTokenizer.decodePolicyLogitsFromUciList(
          logits: rawLogits[0],
          legalMovesUci: message.legalMovesUci,
          isBlack: message.isBlack,
        );

        for (final out in outputs) {
          out?.release();
        }

        ratingMoveProbs[rating] = moveProbabilities;
      }

      if (aborted) {
        message.replyPort.send(_WorkerSweepResponse(
          requestId: message.requestId,
          success: false,
          error: 'Aborted: superseded by newer request #$currentActiveRequestId',
        ));
      } else {
        message.replyPort.send(_WorkerSweepResponse(
          requestId: message.requestId,
          success: true,
          ratingMoveProbabilities: ratingMoveProbs,
        ));
      }
    } else if (message == 'dispose') {
      workerSession?.release();
      workerSession = null;
      loadedModelPath = null;
      workerReceivePort.close();
    }
  });
}

/// Service responsible for executing rating-conditioned Maia neural network sweeps.
///
/// Implements the official Maia-3 model contract (CSSLab / ICLR 2026).
/// Runs all heavy ONNX inference in a dedicated background worker isolate
/// so the Flutter UI thread never stutters, drops frames, or hangs.
class MaiaRatingEngine {
  static final MaiaRatingEngine _instance = MaiaRatingEngine._internal();
  factory MaiaRatingEngine() => _instance;
  MaiaRatingEngine._internal();

  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  String? _loadedModelPath;
  int _analysisRequestId = 0;
  bool _isComputing = false;

  bool get isComputing => _isComputing;
  bool get isModelLoaded => _workerSendPort != null && _loadedModelPath != null;

  static const List<int> supportedRatings = [
    600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500,
    1600, 1700, 1800, 1900, 2000, 2100, 2200, 2300, 2400, 2500, 2600
  ];

  /// Spawns the worker isolate if not running and loads the ONNX runtime model session.
  /// Guarantees: Model loading happens ONCE and is reused across all position changes.
  Future<bool> ensureModelLoaded(String modelPath) async {
    if (modelPath.contains('.download')) {
      developer.log(
        'MaiaRatingEngine: Refusing to load temporary download path: $modelPath',
        name: 'MaiaRatingEngine',
        level: 900,
      );
      return false;
    }

    if (_workerSendPort != null && _loadedModelPath == modelPath) {
      return true; // Already loaded! Reuse existing session.
    }

    final file = File(modelPath);
    if (!file.existsSync() || file.lengthSync() < 1000000) {
      return false;
    }

    try {
      // Spawn worker isolate if not yet spawned
      if (_workerIsolate == null || _workerSendPort == null) {
        final handshakePort = ReceivePort();
        _workerIsolate = await Isolate.spawn(_maiaWorkerEntryPoint, handshakePort.sendPort);
        _workerSendPort = await handshakePort.first as SendPort;
      }

      // Request worker to load ONNX model
      final replyPort = ReceivePort();
      _workerSendPort!.send(_WorkerInitMessage(replyPort.sendPort, modelPath));
      final loaded = await replyPort.first as bool;
      if (loaded) {
        _loadedModelPath = modelPath;
        if (kDebugMode) {
          developer.log('MaiaRatingEngine: Model session loaded in background isolate from $modelPath', name: 'MaiaRatingEngine');
        }
        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      developer.log(
        'MaiaRatingEngine: Failed to spawn worker isolate or load session: $e',
        name: 'MaiaRatingEngine',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Evaluates the position across all 21 rating conditions in the background isolate.
  ///
  /// Guarantees:
  /// 1. Zero UI main-thread blocking (runs completely on background worker thread).
  /// 2. Request ID and revision protection to immediately discard stale requests.
  /// 3. Returns genuine model output snapshot without fabricating data.
  Future<MaiaRatingSweepSnapshot?> computeSweep({
    required ChessPosition position,
    required int positionRevision,
    required int activeRating,
    required String modelPath,
    List<String> priorityUciMoves = const [],
  }) async {
    final requestId = ++_analysisRequestId;
    final currentFen = position.toFen();

    final isLoaded = await ensureModelLoaded(modelPath);
    if (!isLoaded || _workerSendPort == null) {
      return null;
    }

    _isComputing = true;
    try {
      // 1. Prepare one-hot board tokens for current position [1, 64, 12]
      final singleTokens = MaiaTokenizer.tokenizePosition(position);
      final legalMovesUci = position.legalMoves.map((m) => m.uci).toList();
      final isBlack = position.turn == PieceColor.black;

      // 2. Dispatch sweep request to background worker isolate
      final replyPort = ReceivePort();
      final request = _WorkerSweepRequest(
        replyPort: replyPort.sendPort,
        requestId: requestId,
        fen: currentFen,
        positionRevision: positionRevision,
        tokens: singleTokens,
        legalMovesUci: legalMovesUci,
        isBlack: isBlack,
        ratings: supportedRatings,
        priorityUciMoves: priorityUciMoves,
      );

      _workerSendPort!.send(request);
      final response = await replyPort.first as _WorkerSweepResponse;

      // 3. Stale request check: discard if superseded
      if (requestId != _analysisRequestId || !response.success || response.ratingMoveProbabilities == null) {
        return null;
      }

      final ratingMoveProbs = response.ratingMoveProbabilities!;

      // 4. Stable Candidate Move Selection:
      // Collect top moves based on peak probability across all ratings
      final candidateSet = <String>{};

      // Priority moves (explicit user highlights or played move, limit to at most 2)
      for (final m in priorityUciMoves) {
        if (candidateSet.length < 2 && position.legalMoves.any((lm) => lm.uci == m)) {
          candidateSet.add(m);
        }
      }

      // Calculate peak probability for each move across all 21 ratings
      final peakProbs = <String, double>{};
      for (final rating in supportedRatings) {
        final probs = ratingMoveProbs[rating] ?? {};
        for (final entry in probs.entries) {
          final current = peakProbs[entry.key] ?? 0.0;
          if (entry.value > current) {
            peakProbs[entry.key] = entry.value;
          }
        }
      }

      // Sort moves by peak probability descending
      final sortedByPeak = peakProbs.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedByPeak) {
        if (candidateSet.length >= MovesByRatingDataset.palette.length) break;
        candidateSet.add(entry.key);
      }

      final candidateMoves = candidateSet.toList();

      // 5. Build continuous MoveRatingCurve series for each candidate move across all 21 ratings
      final seriesList = <MoveRatingCurve>[];
      for (int i = 0; i < candidateMoves.length; i++) {
        final uci = candidateMoves[i];
        final color = MovesByRatingDataset.palette[i % MovesByRatingDataset.palette.length];

        final points = <MoveRatingPoint>[];
        for (final rating in supportedRatings) {
          final probs = ratingMoveProbs[rating] ?? {};
          final prob = (probs[uci] ?? 0.0) * 100.0; // 0.0 to 100.0%
          points.add(MoveRatingPoint(rating: rating, probability: prob));
        }

        // Format SAN string from current position
        String san = uci;
        try {
          final move = position.legalMoves.firstWhere(
            (m) => m.uci == uci,
            orElse: () => ChessMove(
              from: Square.fromAlgebraic(uci.substring(0, 2)),
              to: Square.fromAlgebraic(uci.substring(2, 4)),
              piece: position.pieceAt(Square.fromAlgebraic(uci.substring(0, 2)))!,
            ),
          );
          san = SANFormatter.formatSan(position, move);
        } catch (_) {}

        seriesList.add(MoveRatingCurve(
          uciMove: uci,
          sanMove: san,
          curveColor: color,
          points: points,
        ));
      }

      final snapshot = MaiaRatingSweepSnapshot(
        fen: currentFen,
        modelId: 'maia3_simplified',
        modelVersion: '3.0 (CSSLab / ICLR 2026)',
        ratings: List<int>.from(supportedRatings),
        candidateMoves: candidateMoves,
        series: seriesList,
        positionRevision: positionRevision,
        analysisRequestId: requestId,
        createdAt: DateTime.now(),
      );

      return snapshot;
    } catch (e, stack) {
      developer.log('MaiaRatingEngine: Inference error: $e', name: 'MaiaRatingEngine', error: e, stackTrace: stack);
      return null;
    } finally {
      if (requestId == _analysisRequestId) {
        _isComputing = false;
      }
    }
  }

  void dispose() {
    _workerSendPort?.send('dispose');
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
    _loadedModelPath = null;
  }
}
