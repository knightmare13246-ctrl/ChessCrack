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
  final int activeRating;
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
    required this.activeRating,
    required this.priorityUciMoves,
  });
}

/// Timing metrics from worker isolate execution
class _WorkerTimingMetrics {
  final int batchMs;
  final int inferenceMs;
  final int decodeMs;
  _WorkerTimingMetrics({required this.batchMs, required this.inferenceMs, required this.decodeMs});
}

class _WorkerSweepResponse {
  final int requestId;
  final bool success;
  final Map<int, Map<String, double>>? ratingMoveProbabilities;
  final String? error;
  final bool isPartial;
  final _WorkerTimingMetrics? timing;

  _WorkerSweepResponse({
    required this.requestId,
    required this.success,
    this.ratingMoveProbabilities,
    this.error,
    this.isPartial = false,
    this.timing,
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
          ..setIntraOpNumThreads(2)
          ..setInterOpNumThreads(1)
          ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortDisableAll);
        workerSession?.release();
        workerSession = OrtSession.fromFile(file, sessionOptions);
        loadedModelPath = message.modelPath;
        debugPrint('[MaiaWorker] Model loaded successfully with 2 intra-op threads: ${message.modelPath}');
        message.replyPort.send(true);
      } catch (e, stack) {
        debugPrint('[MaiaWorker] Model loading failed: $e\n$stack');
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

      try {
        final session = workerSession!;
        final ratings = message.ratings;
        final batchSize = ratings.length;

        // 1. Prepare batch tokens [batchSize, 64, 12]
        final swBatch = Stopwatch()..start();
        final singleLength = message.tokens.length; // 64 * 12 = 768
        final batchTokens = Float32List(batchSize * singleLength);
        for (int b = 0; b < batchSize; b++) {
          batchTokens.setRange(b * singleLength, (b + 1) * singleLength, message.tokens);
        }

        final eloSelfList = Float32List.fromList(ratings.map((r) => r.toDouble()).toList());
        final eloOppoList = Float32List.fromList(ratings.map((r) => r.toDouble()).toList());

        final inputTokens = OrtValueTensor.createTensorWithDataList(batchTokens, [batchSize, 64, 12]);
        final inputEloSelf = OrtValueTensor.createTensorWithDataList(eloSelfList, [batchSize]);
        final inputEloOppo = OrtValueTensor.createTensorWithDataList(eloOppoList, [batchSize]);
        swBatch.stop();
        debugPrint('[MAIA_GRAPH] batch_created in ${swBatch.elapsedMilliseconds}ms, batchSize=$batchSize');

        final swInfer = Stopwatch()..start();
        debugPrint('[MAIA_GRAPH] inference_started (batchSize=$batchSize)');
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
        swInfer.stop();
        debugPrint('[MAIA_GRAPH] inference_finished in ${swInfer.elapsedMilliseconds}ms');

        if (message.requestId != currentActiveRequestId) {
          for (final out in outputs) {
            out?.release();
          }
          message.replyPort.send(_WorkerSweepResponse(
            requestId: message.requestId,
            success: false,
            error: 'Aborted: superseded by newer request #$currentActiveRequestId',
          ));
          return;
        }

        final swDecode = Stopwatch()..start();
        final rawLogits = outputs[0]?.value as List;
        final ratingMoveProbs = <int, Map<String, double>>{};

        for (int i = 0; i < ratings.length; i++) {
          final rating = ratings[i];
          final rowList = (rawLogits[i] as List).cast<double>();
          final moveProbabilities = MaiaTokenizer.decodePolicyLogitsFromUciList(
            logits: rowList,
            legalMovesUci: message.legalMovesUci,
            isBlack: message.isBlack,
          );
          ratingMoveProbs[rating] = moveProbabilities;
          if (i == 0) {
            final sorted = moveProbabilities.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            debugPrint('[MaiaWorker] Rating $rating top 5: ${sorted.take(5).map((e) => "${e.key}:${(e.value * 100).toStringAsFixed(1)}%").join(", ")}');
          }
        }

        for (final out in outputs) {
          out?.release();
        }
        swDecode.stop();
        debugPrint('[MAIA_GRAPH] probabilities_extracted in ${swDecode.elapsedMilliseconds}ms');

        message.replyPort.send(_WorkerSweepResponse(
          requestId: message.requestId,
          success: true,
          ratingMoveProbabilities: ratingMoveProbs,
          isPartial: false,
          timing: _WorkerTimingMetrics(
            batchMs: swBatch.elapsedMilliseconds,
            inferenceMs: swInfer.elapsedMilliseconds,
            decodeMs: swDecode.elapsedMilliseconds,
          ),
        ));
      } catch (e, stack) {
        debugPrint('[MaiaWorker] Error in batched sweep: $e\n$stack');
        message.replyPort.send(_WorkerSweepResponse(
          requestId: message.requestId,
          success: false,
          error: e.toString(),
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

/// Deterministic cache key for exact Maia graph requests.
class GraphCacheKey {
  final String fen;
  final String modelVariant;
  final int ratingStart;
  final int ratingEnd;
  final int ratingStep;

  const GraphCacheKey({
    required this.fen,
    required this.modelVariant,
    required this.ratingStart,
    required this.ratingEnd,
    required this.ratingStep,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphCacheKey &&
          runtimeType == other.runtimeType &&
          fen == other.fen &&
          modelVariant == other.modelVariant &&
          ratingStart == other.ratingStart &&
          ratingEnd == other.ratingEnd &&
          ratingStep == other.ratingStep;

  @override
  int get hashCode => Object.hash(fen, modelVariant, ratingStart, ratingEnd, ratingStep);
}

/// Debug performance telemetry for Maia graph inference.
class MaiaPerformanceTelemetry {
  final String modelName;
  final bool sessionReused;
  final bool isCacheHit;
  final int batchSize;
  final int ratingsSampled;
  final int prepareMs;
  final int inferenceMs;
  final int postProcessMs;
  final int totalMs;
  final int requestId;
  final int positionRevision;

  const MaiaPerformanceTelemetry({
    required this.modelName,
    required this.sessionReused,
    required this.isCacheHit,
    required this.batchSize,
    required this.ratingsSampled,
    required this.prepareMs,
    required this.inferenceMs,
    required this.postProcessMs,
    required this.totalMs,
    required this.requestId,
    required this.positionRevision,
  });

  String get summary =>
      'Maia Graph:\n'
      'Model: $modelName\n'
      'Session: ${sessionReused ? "REUSED" : "CREATED"}\n'
      'Cache: ${isCacheHit ? "HIT" : "MISS"}\n'
      'Batch size: $batchSize\n'
      'Ratings sampled: $ratingsSampled\n'
      'Inference: ${inferenceMs}ms\n'
      'Post-process: ${postProcessMs}ms\n'
      'Total: ${totalMs}ms\n'
      'Request ID: $requestId\n'
      'Position revision: $positionRevision';
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

  /// Canonical 11-point rating grid spanning 600..2600.
  /// Yields a crisp visual curve while keeping batched tensor operations fast and responsive.
  static const List<int> supportedRatings = [
    600, 800, 1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400, 2600
  ];

  static const int _maxCacheEntries = 50;
  final Map<GraphCacheKey, MaiaRatingSweepSnapshot> _lruCache = {};

  MaiaPerformanceTelemetry? _latestTelemetry;
  MaiaPerformanceTelemetry? get latestTelemetry => _latestTelemetry;

  MaiaRatingSweepSnapshot? getCachedSweep(GraphCacheKey key) {
    final cached = _lruCache[key];
    if (cached != null) {
      _lruCache.remove(key);
      _lruCache[key] = cached;
    }
    return cached;
  }

  void cacheSweep(GraphCacheKey key, MaiaRatingSweepSnapshot snapshot) {
    if (_lruCache.length >= _maxCacheEntries) {
      _lruCache.remove(_lruCache.keys.first);
    }
    _lruCache[key] = snapshot;
  }

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

  /// Evaluates the position across rating conditions in the background isolate.
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
    void Function(MaiaRatingSweepSnapshot partialSnapshot)? onPartialUpdate,
  }) async {
    final swTotal = Stopwatch()..start();
    final requestId = ++_analysisRequestId;
    final currentFen = position.toFen();

    final sweepRatings = <int>{...supportedRatings, activeRating}.toList()..sort();
    final cacheKey = GraphCacheKey(
      fen: currentFen,
      modelVariant: 'maia3_simplified',
      ratingStart: sweepRatings.first,
      ratingEnd: sweepRatings.last,
      ratingStep: 200,
    );

    // Exact deterministic LRU cache check (0ms return)
    final cached = getCachedSweep(cacheKey);
    if (cached != null) {
      debugPrint('[MAIA_GRAPH] cache_hit=true (instant 0ms) req=#$requestId fen=$currentFen');
      _latestTelemetry = MaiaPerformanceTelemetry(
        modelName: 'Maia-3 (FP32)',
        sessionReused: true,
        isCacheHit: true,
        batchSize: sweepRatings.length,
        ratingsSampled: sweepRatings.length,
        prepareMs: 0,
        inferenceMs: 0,
        postProcessMs: 0,
        totalMs: 0,
        requestId: requestId,
        positionRevision: positionRevision,
      );
      return cached;
    }

    debugPrint('[MAIA_GRAPH] request_created req=#$requestId fen=$currentFen');

    final prepareStart = swTotal.elapsedMilliseconds;
    final singleTokens = MaiaTokenizer.tokenizePosition(position);
    final tokenizeMs = swTotal.elapsedMilliseconds - prepareStart;
    debugPrint('[MAIA_GRAPH] board_tokenized in ${tokenizeMs}ms');

    final maskStart = swTotal.elapsedMilliseconds;
    final legalMovesUci = position.legalMoves.map((m) => m.uci).toList();
    final isBlack = position.turn == PieceColor.black;
    final maskMs = swTotal.elapsedMilliseconds - maskStart;
    debugPrint('[MAIA_GRAPH] legal_mask_created in ${maskMs}ms');

    final sessionStart = swTotal.elapsedMilliseconds;
    final wasLoaded = isModelLoaded;
    final isLoaded = await ensureModelLoaded(modelPath);
    final sessionMs = swTotal.elapsedMilliseconds - sessionStart;
    debugPrint('[MAIA_GRAPH] model_session_acquired in ${sessionMs}ms (reused=$wasLoaded)');

    if (!isLoaded || _workerSendPort == null) {
      debugPrint('[MaiaRatingEngine] Model not loaded in computeSweep');
      return null;
    }

    _isComputing = true;
    try {
      final replyPort = ReceivePort();
      final request = _WorkerSweepRequest(
        replyPort: replyPort.sendPort,
        requestId: requestId,
        fen: currentFen,
        positionRevision: positionRevision,
        tokens: singleTokens,
        legalMovesUci: legalMovesUci,
        isBlack: isBlack,
        ratings: sweepRatings,
        activeRating: activeRating,
        priorityUciMoves: priorityUciMoves,
      );

      _workerSendPort!.send(request);

      final completer = Completer<MaiaRatingSweepSnapshot?>();

      replyPort.listen((message) {
        if (message is! _WorkerSweepResponse) return;
        if (message.requestId != _analysisRequestId) {
          replyPort.close();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        if (!message.success || message.ratingMoveProbabilities == null) {
          replyPort.close();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final swSnap = Stopwatch()..start();
        final snapshot = _buildSnapshot(
          position: position,
          positionRevision: positionRevision,
          currentFen: currentFen,
          requestId: requestId,
          priorityUciMoves: priorityUciMoves,
          ratingMoveProbs: message.ratingMoveProbabilities!,
        );
        final snapMs = swSnap.elapsedMilliseconds;
        debugPrint('[MAIA_GRAPH] graph_points_created in ${snapMs}ms');

        cacheSweep(cacheKey, snapshot);

        final totalMs = swTotal.elapsedMilliseconds;
        final batchMs = message.timing?.batchMs ?? 0;
        final inferMs = message.timing?.inferenceMs ?? 0;
        final decodeMs = message.timing?.decodeMs ?? 0;
        final postProcessMs = decodeMs + snapMs;

        _latestTelemetry = MaiaPerformanceTelemetry(
          modelName: 'Maia-3 (FP32)',
          sessionReused: wasLoaded,
          isCacheHit: false,
          batchSize: sweepRatings.length,
          ratingsSampled: sweepRatings.length,
          prepareMs: tokenizeMs + maskMs,
          inferenceMs: inferMs,
          postProcessMs: postProcessMs,
          totalMs: totalMs,
          requestId: requestId,
          positionRevision: positionRevision,
        );

        debugPrint('[MAIA_GRAPH] total=${totalMs}ms prepare=${tokenizeMs + maskMs}ms tokenize=${tokenizeMs}ms session=${sessionMs}ms batch=${batchMs}ms inference=${inferMs}ms decode=${decodeMs}ms snapshot=${snapMs}ms');

        replyPort.close();
        if (!completer.isCompleted) completer.complete(snapshot);
      });

      return await completer.future;
    } catch (e, stack) {
      debugPrint('[MaiaRatingEngine] Inference error: $e\n$stack');
      return null;
    } finally {
      if (requestId == _analysisRequestId) {
        _isComputing = false;
      }
    }
  }

  MaiaRatingSweepSnapshot _buildSnapshot({
    required ChessPosition position,
    required int positionRevision,
    required String currentFen,
    required int requestId,
    required List<String> priorityUciMoves,
    required Map<int, Map<String, double>> ratingMoveProbs,
  }) {
    final candidateSet = <String>{};

    // Priority moves (explicit user highlights or played move, limit to at most 2)
    for (final m in priorityUciMoves) {
      if (candidateSet.length < 2 && position.legalMoves.any((lm) => lm.uci == m)) {
        candidateSet.add(m);
      }
    }

    // Calculate peak probability for each move across available ratings
    final peakProbs = <String, double>{};
    for (final probs in ratingMoveProbs.values) {
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
    final availableRatings = ratingMoveProbs.keys.toList()..sort();

    final seriesList = <MoveRatingCurve>[];
    for (int i = 0; i < candidateMoves.length; i++) {
      final uci = candidateMoves[i];
      final color = MovesByRatingDataset.palette[i % MovesByRatingDataset.palette.length];

      final points = <MoveRatingPoint>[];
      for (final rating in availableRatings) {
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

    return MaiaRatingSweepSnapshot(
      fen: currentFen,
      modelId: 'maia3_simplified',
      modelVersion: '3.0 (CSSLab / ICLR 2026)',
      ratings: availableRatings,
      candidateMoves: candidateMoves,
      series: seriesList,
      positionRevision: positionRevision,
      analysisRequestId: requestId,
      createdAt: DateTime.now(),
    );
  }

  void dispose() {
    _workerSendPort?.send('dispose');
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
    _loadedModelPath = null;
  }
}
