import 'dart:collection';

enum EngineSearchState {
  idle,
  ready,
  searching,
  stopping,
}

enum EngineActivationState {
  disabled, // Engine is OFF, no search, no background CPU
  starting, // Engine process launching/initializing UCI
  enabled,  // Engine is ON, ready or actively analyzing
  stopping, // Engine stopping search before becoming disabled
  error,    // Engine startup or execution failure
}

class EngineTraceEvent {
  final DateTime timestamp;
  final int requestId;
  final String activeFen;
  final String? pendingFen;
  final EngineSearchState engineState;
  final EngineActivationState activationState;
  final String rawUciLine;
  final String action; // 'DISCARDED_STOPPING', 'PARSED', 'STOP_COMPLETION', 'NEW_SEARCH_STARTED', etc.

  EngineTraceEvent({
    required this.timestamp,
    required this.requestId,
    required this.activeFen,
    this.pendingFen,
    required this.engineState,
    required this.activationState,
    required this.rawUciLine,
    required this.action,
  });

  String format() {
    final t = timestamp;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}.${t.millisecond.toString().padLeft(3, '0')}';
    return '[$timeStr] req=$requestId state=${engineState.name} act=${activationState.name} action=$action | $rawUciLine';
  }
}

class EngineTraceLogger {
  static final EngineTraceLogger instance = EngineTraceLogger._();
  EngineTraceLogger._();

  final Queue<EngineTraceEvent> _history = Queue<EngineTraceEvent>();
  static const int maxEvents = 300;

  bool enabled = true;

  void log({
    required int requestId,
    required String activeFen,
    String? pendingFen,
    required EngineSearchState engineState,
    required EngineActivationState activationState,
    required String rawUciLine,
    required String action,
  }) {
    if (!enabled) return;

    final event = EngineTraceEvent(
      timestamp: DateTime.now(),
      requestId: requestId,
      activeFen: activeFen,
      pendingFen: pendingFen,
      engineState: engineState,
      activationState: activationState,
      rawUciLine: rawUciLine,
      action: action,
    );

    if (_history.length >= maxEvents) {
      _history.removeFirst();
    }
    _history.add(event);
  }

  List<EngineTraceEvent> get events => _history.toList();

  void clear() => _history.clear();
}
