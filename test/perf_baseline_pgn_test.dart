// DEBUG-only profiling harness: baseline for the existing Dart PGN pipeline.
// Run: flutter test test/perf_baseline_pgn_test.dart --reporter expanded
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/chess_position.dart';
import 'package:nibbler_chess/services/pgn_parser.dart';

void main() {
  test('BASELINE: existing Dart PgnParser throughput', () {
    const iterations = 300;
    final games = [
      PgnParser.sampleKasparovTopalov,
      PgnParser.sampleFischerGameOfCentury,
    ];

    // warm-up
    for (final g in games) {
      PgnParser.parse(g);
    }

    var plies = 0;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      for (final g in games) {
        final tree = PgnParser.parse(g);
        var n = tree.root;
        while (n.hasChildren) {
          n = n.children.first;
          plies++;
        }
      }
    }
    sw.stop();
    final totalGames = iterations * games.length;
    final secs = sw.elapsedMicroseconds / 1e6;
    // ignore: avoid_print
    print('[PERF] Dart PgnParser.parse: $totalGames games, $plies plies in '
        '${secs.toStringAsFixed(3)}s  =>  '
        '${(totalGames / secs).toStringAsFixed(0)} games/s, '
        '${(plies / secs).toStringAsFixed(0)} plies/s, '
        '${(secs * 1000 / totalGames).toStringAsFixed(2)} ms/game');
  });

  test('BASELINE: Dart legal move generation + applyMove', () {
    var pos = ChessPosition.initial();
    final sw = Stopwatch()..start();
    var moves = 0;
    for (var i = 0; i < 20000; i++) {
      final legal = pos.generateLegalMoves();
      if (legal.isEmpty) {
        pos = ChessPosition.initial();
        continue;
      }
      pos = pos.applyMove(legal[i % legal.length]);
      moves++;
    }
    sw.stop();
    // ignore: avoid_print
    print('[PERF] Dart movegen+apply: $moves plies in '
        '${sw.elapsedMilliseconds}ms => '
        '${(moves / (sw.elapsedMicroseconds / 1e6)).toStringAsFixed(0)} plies/s');
  });
}
