import 'dart:io';
import 'dart:convert';

void main(List<String> args) {
  String activeScenario = '';

  stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    final trimmed = line.trim();
    if (trimmed == 'uci') {
      stdout.writeln('id name MockEngine 1.0');
      stdout.writeln('id author Empirical Challenger');
      stdout.writeln('uciok');
    } else if (trimmed == 'isready') {
      stdout.writeln('readyok');
    } else if (trimmed.startsWith('position fen ')) {
      // Position acknowledged
    } else if (trimmed.startsWith('setoption name CustomScenario value ')) {
      activeScenario = trimmed.substring(36).trim();
    } else if (trimmed.startsWith('go')) {
      if (activeScenario == 'out_of_order_multipv') {
        // Stream MultiPV 3, then 2, then 1 out-of-order
        stdout.writeln('info depth 10 seldepth 12 multipv 3 score cp -10 nodes 3000 nps 200000 time 100 pv g1f3 b8c6');
        stdout.writeln('info depth 10 seldepth 12 multipv 2 score cp 20 nodes 4000 nps 200000 time 100 pv d2d4 d7d5');
        stdout.writeln('info depth 10 seldepth 12 multipv 1 score cp 40 nodes 5000 nps 200000 time 100 pv e2e4 e7e5');
      } else if (activeScenario == 'illegal_move_injection') {
        // MultiPV 1 with illegal move 'e2e5'
        stdout.writeln('info depth 10 multipv 1 score cp 100 nodes 1000 pv e2e5 e7e5');
        // MultiPV 2 with legal move 'e2e4'
        stdout.writeln('info depth 10 multipv 2 score cp 35 nodes 2000 pv e2e4 e7e5');
      } else if (activeScenario == 'info_string_telemetry') {
        stdout.writeln('info string e2e4  (322 ) N:       700 (+ 0) (P: 38.50%) (WL:  0.15) (D: 0.50) (M: 20.0)');
      } else {
        // Normal search stream: MultiPV lines
        stdout.writeln('info depth 15 seldepth 18 multipv 1 score cp 55 nodes 100000 nps 500000 time 200 wdl 600 350 50 pv e2e4 e7e5');
        stdout.writeln('info depth 15 seldepth 18 multipv 2 score cp 30 nodes 80000 nps 500000 time 200 wdl 450 450 100 pv d2d4 d7d5');
        stdout.writeln('info string e2e4  (322 ) N:       60000 (+ 0) (P: 42.10%) (WL:  0.25) (D: 0.50) (M: 24.0)');
      }
    } else if (trimmed == 'stop') {
      stdout.writeln('bestmove e2e4');
    } else if (trimmed == 'quit') {
      exit(0);
    }
  });
}
