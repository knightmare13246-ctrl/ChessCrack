# Handoff Report: Explorer Survey 2 (Gen 2) — R2 Accurate Telemetry, State Decoupling & Search State Machine

**Working Directory**: `O:\ChessCrack\.agents\teamwork\explorer_survey_2_gen2`  
**Target Milestone**: R2 & Directives 1, 2, 3, 4, 5, 7  
**Timestamp**: 2026-10-01T18:22:00Z  
**Author**: Explorer 2 (`teamwork_explorer_survey_2_gen2`)  
**Parent Conversation ID**: `ce73e06e-4106-412c-a798-2d9e95386e10`

---

## 1. Observation

Direct code observations from inspecting the codebase across `O:\ChessCrack`:

### 1.1 State Conflation Across Models and Services
- **File**: `O:\ChessCrack\lib\models\engine_analysis.dart` (lines 19–26):
  ```dart
  enum EngineLifecycleState {
    idle,
    starting,
    ready,
    analyzing,
    stopping,
    error,
  }
  ```
  `EngineLifecycleState` conflates the native OS process lifecycle with search state (`analyzing`, `stopping`, `idle`). When the engine begins searching, its lifecycle changes to `analyzing`, and when paused or stopped it changes to `idle` or `ready`, even though the process itself remains initialized and alive.
- **File**: `O:\ChessCrack\lib\services\engine_trace_logger.dart` (lines 3–16):
  ```dart
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
  ```
  `EngineSearchState` lacks `paused` and `completed` states. `EngineActivationState` overlaps with both lifecycle (`starting`, `error`) and search control (`stopping`).
- **File**: `O:\ChessCrack\lib\models\engine_download_model.dart` (lines 3–13):
  `DownloadStatus` (`notInstalled`, `queued`, `downloading`, `verifying`, `installing`, `installed`, `error`, `cancelled`, `unsupported`) represents download progress, but there is no unified `EngineInstallationState` enum modeling artifact presence, verification, deletion, and readiness.

### 1.2 Fake 0 and 1 Defaults in Telemetry Pipelines
- **File**: `O:\ChessCrack\lib\services\uci_engine_service.dart`:
  - Lines 67–70, 87–90:
    ```dart
    int _currentNodes = 0;
    int _currentNps = 0;
    int _currentDepth = 0;
    ...
    int _currentSeldepth = 0;
    int _currentTimeMs = 0;
    int _currentHashfull = 0;
    int _currentTbhits = 0;
    ```
  - Lines 1082–1088 (when `startAnalysis` is called for a new position):
    ```dart
    _currentNodes = 0;
    _currentNps = 0;
    _currentDepth = 0;
    _currentSeldepth = 0;
    _currentTimeMs = 0;
    ```
    If an engine (like Lc0 0.32.1) omits `nps` from its `info` lines or during Maia 1-node evaluations, `_currentNps` remains `0`.
  - Lines 620–623 in `_parseInfoLine`:
    ```dart
    int depth = _currentDepth;
    int seldepth = 0;
    int nodes = _currentNodes;
    int nps = _currentNps;
    ```
    Telemetry fields are non-nullable integers defaulted to 0 or previous cached values.
- **File**: `O:\ChessCrack\lib\models\engine_analysis.dart`:
  - `PvLine` (lines 245–248, 271–274):
    ```dart
    final int depth;
    final int seldepth;
    final int nodes;
    final int nps;
    ...
    this.depth = 0,
    this.seldepth = 0,
    this.nodes = 0,
    this.nps = 0,
    ```
  - `PositionAnalysis` (lines 347–349, 360–362):
    ```dart
    final int totalNodes;
    final int nodesPerSecond;
    final int depth;
    ...
    this.totalNodes = 0,
    this.nodesPerSecond = 0,
    this.depth = 0,
    ```
    `seldepth` and `timeMs` are completely missing from `PositionAnalysis`!
  - `EngineDiagnostics` (lines 72–76, 116–120):
    `totalNodes = 0, nps = 0, depth = 0, seldepth = 0, timeMs = 0`.
  - `CandidateArrow` (`O:\ChessCrack\lib\models\candidate_arrow.dart`, lines 123, 148):
    `final int depth; ... this.depth = 0`.

### 1.3 Missing Engine Session ID and MultiPV Synchronization
- **File**: `O:\ChessCrack\lib\services\uci_engine_service.dart`:
  - Lines 54–57:
    ```dart
    int _positionRevision = 0;
    int _analysisRequestId = 0;
    int get positionRevision => _positionRevision;
    int get analysisRequestId => _analysisRequestId;
    ```
    There is NO `engineSessionId` variable. If the engine process crashes and restarts, or is reinitialized with new settings/weights, there is no session token to invalidate queued or buffered stdout events.
  - Lines 868–875:
    ```dart
    final sortedLines = _currentLines.values.toList()
      ..sort((a, b) => a.multipv.compareTo(b.multipv));

    final rawArrows = _candidateArrowsMap.values.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    ```
    In `_emitThrottledAnalysis`, `_currentLines` are directly emitted into `PositionAnalysis` without checking if each line matches `_positionRevision` or `_analysisRequestId`.
  - `CandidateArrow` lines 927–930 validate `a.requestId != _analysisRequestId` and `a.positionRevision != _positionRevision`, but lack `engineSessionId`.

### 1.4 Request ID and Revision Bypasses in UCI Stream Parsing
- **File**: `O:\ChessCrack\lib\services\uci_engine_service.dart`:
  - Lines 529–578 (`_parseInfoStringLine`):
    ```dart
    void _parseInfoStringLine(String line) {
      final afterPrefix = line.substring(12).trim();
      final tokens = afterPrefix.split(RegExp(r'\s+'));
      if (tokens.isEmpty) return;

      final moveToken = tokens[0];
      if (moveToken == 'node' || moveToken.length < 4) return;

      final pMatch = RegExp(r'\(P:\s*([\d\.]+)%\)').firstMatch(line);
      if (pMatch != null) {
        final pVal = double.tryParse(pMatch.group(1)!);
        if (pVal != null) {
          _positionPolicyCache[moveToken] = pVal;
        }
      }
      ...
      for (final entry in _candidateArrowsMap.entries) {
        if (entry.value.uciMove == moveToken) {
          _candidateArrowsMap[entry.key] = entry.value.copyWith(
            policyPercentage: _positionPolicyCache[moveToken],
            visits: _positionVisitsCache[moveToken] ?? entry.value.visits,
            movesLeft: _positionMlhCache[moveToken] ?? entry.value.movesLeft,
          );
          updated = true;
        }
      }
      if (updated) {
        _scheduleThrottledUpdate();
      }
    }
    ```
    **Critical Vulnerability**: `_parseInfoStringLine` does NOT check `_activeSearchFen`, `_positionRevision`, `_analysisRequestId`, `_searchState == EngineSearchState.stopping`, or `_activationState`! Delayed Lc0 verbose info strings from an old position write directly into `_positionPolicyCache` and mutate candidate arrows belonging to a new position.
  - Lines 613–615 and 709 in `_parseInfoLine`:
    ```dart
    final capturedRev = _positionRevision;
    final capturedReqId = _analysisRequestId;
    ...
    if (capturedRev != _positionRevision || capturedReqId != _analysisRequestId) {
      return;
    }
    ```
    Because UCI does not echo back custom request IDs, `capturedRev` is read from `_positionRevision` synchronously in the same function call. It does not verify against the request ID that originated the search.

### 1.5 Destructive Pause & Search Thrashing
- **File**: `O:\ChessCrack\lib\ui\screens\chess_analysis_screen.dart`:
  - Lines 478–492:
    ```dart
    void _toggleLiveAnalysis() async {
      setState(() {
        _isLiveAnalysisActive = !_isLiveAnalysisActive;
      });
      _saveSessionState();
      if (_isLiveAnalysisActive) {
        await _engineService.enableEngine();
        _startOrUpdateAnalysis();
      } else {
        await _engineService.disableEngine();
        setState(() {
          _currentAnalysis = null;
        });
      }
    }
    ```
  - Lines 730–736, 852–856:
    Both `EngineAnalysisPanel` instances pass `onToggleAnalysis: _toggleLiveAnalysis`.
  - Line 998: Top bar engine switch also passes `onTap: _toggleLiveAnalysis`.
- **File**: `O:\ChessCrack\lib\ui\widgets\engine_analysis_panel.dart` (lines 92–120):
  The panel button displays `[⏸ Pause]` when analyzing and `[▶ Analyze]` when not.
- **File**: `O:\ChessCrack\lib\services\uci_engine_service.dart` (lines 245–281):
  `disableEngine()`:
  ```dart
  stopAnalysis();
  _activationState = EngineActivationState.disabled;
  _setLifecycle(EngineLifecycleState.idle, 'Engine disabled');
  _currentLines.clear();
  _candidateArrowsMap.clear();
  _positionPolicyCache.clear();
  _positionVisitsCache.clear();
  _positionMlhCache.clear();
  _currentNodes = 0;
  _currentNps = 0;
  _currentDepth = 0;
  _activeSearchFen = null;
  _pendingSearchFen = null;
  _evaluationNotifier.value = NormalizedEvaluation.neutral;
  _emitThrottledAnalysis(force: true);
  ```
  **Direct Defect**: Tapping `[⏸ Pause]` in the analysis panel calls `_toggleLiveAnalysis()`, which invokes `disableEngine()` and sets `_currentAnalysis = null`. This wipes all candidate arrows, all PV lines, all telemetry, and resets the evaluation bar to neutral (50.0%). There is no non-destructive `pauseAnalysis()` method.

### 1.6 Lc0 0.32.1 Missing NPS & Maia Completion Semantics
- **File**: `O:\ChessCrack\lib\services\uci_engine_service.dart` (lines 409–416):
  ```dart
  } else if (_searchState == EngineSearchState.searching) {
    final effectiveNodeLimit = _effectiveNodeLimit;
    if (effectiveNodeLimit != null) {
      // Natural stop because an explicit node limit was set and reached
      _searchState = EngineSearchState.ready;
      _isAnalyzing = false;
      _setLifecycle(EngineLifecycleState.ready, 'Analysis complete ($effectiveNodeLimit nodes reached)');
      _emitThrottledAnalysis(force: true);
    }
  ```
  When Maia evaluates a position (`go nodes 1`), Lc0 finishes within ~10–50ms and emits `bestmove`. `_isAnalyzing` is immediately set to `false`.
- **File**: `O:\ChessCrack\lib\models\engine_analysis.dart` (lines 388–413):
  ```dart
  String get formattedHeader {
    final bool isMaia = (engineName?.toLowerCase().contains('maia') == true);
    if (isMaia) {
      final status = isAnalyzing ? 'Evaluating Human Moves...' : 'Evaluation Complete (1-ply Policy)';
      return '$engineName · $status';
    }

    final formattedNodes = _formatNumber(totalNodes);
    final String npsText;
    if (isAnalyzing) {
      if (nodesPerSecond > 0) {
        npsText = 'N/s: ${_formatNumber(nodesPerSecond)}';
      } else {
        npsText = (engineName?.toLowerCase().contains('leela') == true ||
                engineName?.toLowerCase().contains('lc0') == true)
            ? 'N/s: N/A'
            : 'N/s: —';
      }
    } else {
      npsText = 'N/s: —';
    }

    final depthText = depth > 0 ? ', Depth: $depth' : '';
    final statusPrefix = !isAnalyzing ? 'Paused · ' : '';
    return '${statusPrefix}Nodes: $formattedNodes, $npsText$depthText';
  }
  ```
  For Lc0 when stopped or paused, `isAnalyzing` is `false`, so `npsText` defaults to `N/s: —` and prepends `Paused · `.
  For Maia, the header displays generic text `'Evaluation Complete (1-ply Policy)'` without showing human sparring metrics: Maia Elo rating (~1100–1900), top move policy probability (`P: XX.X%`), and evaluation state.

---

## 2. Logic Chain

1. **State Conflation Causes Leaky State Machines**:
   - `EngineInstallationState` tracks files on disk (`uninstalled`, `downloading`, `verifying`, `installed`, `ready`, `deleting`, `error`).
   - `EngineLifecycleState` tracks the OS process and UCI protocol ready handshake (`uninitialized`, `initializing`, `ready`, `disposed`, `error`).
   - `AnalysisDataState` tracks position search progress (`idle`, `searching`, `paused`, `completed`, `stopping`).
   - Because `EngineLifecycleState` was previously overloaded with `analyzing`, stopping a search altered the engine's lifecycle to `idle`, breaking the invariant that an engine process can remain `ready` while search is `paused` or `idle`.

2. **Synthetic 0 Defaults Corrupt Engine Semantics**:
   - Stockfish continuous search produces real non-zero nodes and NPS.
   - Lc0 0.32.1 frequently omits NPS during short bursts or node limits.
   - Defaulting `nps` to `0` makes it impossible to distinguish between "0 nodes/sec" (engine hung) and "NPS omitted by engine" (`N/s: N/A`).
   - Defaulting `depth` and `nodes` to `0` displays false "Nodes: 0" headers before initial UCI telemetry is received.
   - All telemetry metrics (`nodes`, `nps`, `depth`, `selDepth`, `timeMs`) must be `int?`.

3. **MultiPV Generation Drift & Missing Session Token**:
   - Asynchronous UCI output can interleave MultiPV line 1 (from depth 15) with MultiPV line 2 (from depth 14).
   - If an engine process crashes or is restarted, buffered lines from the previous process instance must be rejected.
   - Introducing `engineSessionId` and bundling `(positionRevision, analysisRequestId, engineSessionId)` into an immutable `AnalysisGeneration` guarantees that every `PvLine`, `CandidateArrow`, and `PositionAnalysis` belongs to the exact same generation tuple.

4. **Zero-Bypass Validation Eliminates Ghost Data**:
   - `_parseInfoStringLine` was updating candidate arrows without verifying FEN, revision, or request ID.
   - An incoming stream guard must validate every line (`info`, `info string`, and `bestmove`) against the active generation tuple before updating any internal cache or scheduling a UI update.

5. **Eliminating Pause/Disable Thrashing**:
   - The user interface provides two distinct controls:
     1. Engine Master Switch (`ON / OFF` in top app bar): Calls `enableEngine()` / `disableEngine()`.
     2. Search Control (`[⏸ Pause] / [▶ Analyze]` in analysis panel): Must call `pauseAnalysis()` / `resumeAnalysis()`.
   - `pauseAnalysis()` sends `stop` to the UCI engine, transitions `AnalysisDataState` to `paused`, and strictly preserves all candidate arrows, PV lines, and evaluations.
   - `resumeAnalysis()` re-issues `go infinite` (or `go nodes N`) for the current position without clearing existing analysis data.

---

## 3. Caveats

- **No Caveats**: All findings are based on direct inspection of source code in `O:\ChessCrack\lib`.
- Baseline verification confirmed: `flutter analyze` reports 0 issues; `flutter test` reports 90/90 tests passing.
- This investigation is read-only. No code modifications were made.

---

## 4. Conclusion & Actionable Design

### 4.1 Strict State Decoupling Architecture

Define three distinct state enums across their respective domains:

```dart
/// 1. Artifact & Disk Management (EngineDownloadService / Models)
enum EngineInstallationState {
  uninstalled,
  downloading,
  verifying,
  installed,
  ready,
  deleting,
  error,
}

/// 2. Native Process & UCI Protocol Lifecycle (UciEngineService Process Manager)
enum EngineLifecycleState {
  uninitialized,
  initializing,
  ready,
  disposed,
  error,
}

/// 3. Search & Telemetry State Machine (UciEngineService & PositionAnalysis)
enum AnalysisDataState {
  idle,       // Engine enabled, but not currently searching (awaiting position)
  searching,  // Engine actively computing (go infinite or go nodes N)
  paused,     // User paused computation; data preserved on screen
  completed,  // Search bounded by node limit (Maia nodes = 1) or mate/draw reached
  stopping,   // Transient: stop sent, awaiting bestmove
}
```

### 4.2 Nullable Engine Telemetry Pipeline

Make all telemetry fields strictly nullable across models and services:

#### `PvLine` (`lib/models/engine_analysis.dart`)
```dart
class PvLine {
  final int multipv;
  final int? scoreCp;
  final int? scoreMate;
  final double winPercentage;
  final double whiteWinPercentage;
  final double expectedScore;
  final double whiteExpectedScore;
  final List<int>? wdl;
  final List<String> movesUci;
  List<String> movesSan;
  final List<PvMoveItem> pvMoves;
  final String startFen;
  final int? depth;         // Nullable
  final int? seldepth;      // Nullable
  final int? nodes;         // Nullable
  final int? nps;           // Nullable
  final double? visitPercentage;
  final double? policyPercentage;
  final double? utility;
  final double? movesLeft;
  final int positionRevision;
  final int analysisRequestId;
  final int engineSessionId; // New
  ...
```

#### `PositionAnalysis` (`lib/models/engine_analysis.dart`)
```dart
class PositionAnalysis {
  final String fen;
  final int positionRevision;
  final int analysisRequestId;
  final int engineSessionId; // New
  final int? totalNodes;     // Nullable
  final int? nodesPerSecond; // Nullable
  final int? depth;          // Nullable
  final int? seldepth;       // Nullable (added)
  final int? timeMs;         // Nullable (added)
  final AnalysisDataState searchState; // New
  final bool isMaia;         // New
  final int? maiaElo;        // New
  final List<PvLine> pvLines;
  final List<CandidateArrow> candidateArrows;
  final bool isAnalyzing;
  final String? engineName;
  final EngineDiagnostics? diagnostics;
  ...
```

#### `CandidateArrow` (`lib/models/candidate_arrow.dart`)
```dart
class CandidateArrow {
  final int rank;
  final String uciMove;
  final Square from;
  final Square to;
  ...
  final int? depth;          // Nullable
  final int positionRevision;
  final int requestId;
  final int engineSessionId; // New
  ...
```

### 4.3 Atomic Analysis Snapshot & Generation Tuple

1. **Generation Class**:
   ```dart
   class AnalysisGeneration {
     final int positionRevision;
     final int analysisRequestId;
     final int engineSessionId;

     const AnalysisGeneration({
       required this.positionRevision,
       required this.analysisRequestId,
       required this.engineSessionId,
     });

     bool matches({
       required int revision,
       required int requestId,
       required int sessionId,
     }) =>
         positionRevision == revision &&
         analysisRequestId == requestId &&
         engineSessionId == sessionId;
   }
   ```
2. **Session ID Tracking**:
   `UciEngineService` maintains `int _engineSessionId = 0`.
   Every time `initializeEngine` spawns a process, `_engineSessionId++`.
   The stdout stream listener binds `final localSessionId = _engineSessionId;`.
   Any line received where `localSessionId != _engineSessionId` is discarded immediately.
3. **Atomic Snapshot Emission**:
   In `_emitThrottledAnalysis`:
   ```dart
   final validLines = _currentLines.values
       .where((l) =>
           l.positionRevision == _positionRevision &&
           l.analysisRequestId == _analysisRequestId &&
           l.engineSessionId == _engineSessionId)
       .toList()
     ..sort((a, b) => a.multipv.compareTo(b.multipv));

   final validArrows = _candidateArrowsMap.values
       .where((a) =>
           a.positionRevision == _positionRevision &&
           a.requestId == _analysisRequestId &&
           a.engineSessionId == _engineSessionId)
       .toList()
     ..sort((a, b) => a.rank.compareTo(b.rank));
   ```

### 4.4 Zero-Bypass Stream Invariant

All handlers (`_parseInfoLine`, `_parseInfoStringLine`, `_handleBestMove`) must execute this unified guard before inspecting tokens:

```dart
bool _validateStreamLine({
  required int sessionId,
  required String rawLine,
}) {
  if (sessionId != _engineSessionId) return false;
  if (_activationState != EngineActivationState.enabled) return false;
  if (_searchState == AnalysisDataState.stopping) {
    // Only bestmove is permitted during stopping
    return rawLine.startsWith('bestmove');
  }
  if (_activeSearchFen != _currentFen) return false;
  return true;
}
```
Apply this guard to `_parseInfoStringLine` to completely eliminate the caching bypass vulnerability.

### 4.5 Search Control Decoupling (`pauseAnalysis` vs `disableEngine`)

Implement distinct methods in `UciEngineService`:

```dart
/// Pauses search without clearing arrows, lines, or eval
void pauseAnalysis() {
  if (_searchState != AnalysisDataState.searching) return;

  _searchState = AnalysisDataState.stopping;
  _isAnalyzing = false;
  _sendCommand('stop');

  // Do NOT clear _currentLines or _candidateArrowsMap!
  _setLifecycle(EngineLifecycleState.ready, 'Analysis paused');
  _searchState = AnalysisDataState.paused;
  _emitThrottledAnalysis(force: true);
}

/// Resumes search on the active position
void resumeAnalysis() {
  if (_activationState != EngineActivationState.enabled) return;
  if (_searchState == AnalysisDataState.searching) return;

  startAnalysis(_currentPosition);
}

/// Disables engine and cleans up (top bar ON/OFF)
Future<void> disableEngine() async {
  ... // Existing disable logic
}
```

In `ChessAnalysisScreen`:
- Wire top app bar toggle to `_toggleEngineActivation()` (`enableEngine` / `disableEngine`).
- Wire `EngineAnalysisPanel.onToggleAnalysis` to `_toggleSearchPause()`:
  ```dart
  void _toggleSearchPause() {
    if (_engineService.searchState == AnalysisDataState.searching) {
      _engineService.pauseAnalysis();
    } else {
      _engineService.resumeAnalysis();
    }
  }
  ```

### 4.6 Authentic Telemetry & Missing Metric Formatting

Update `PositionAnalysis.formattedHeader`:
```dart
String get formattedHeader {
  if (isMaia) {
    final eloStr = maiaElo != null ? 'Maia $maiaElo (~$maiaElo Elo)' : 'Maia Human Sparring';
    final topMove = pvLines.isNotEmpty ? pvLines.first : null;
    final policyStr = (topMove?.policyPercentage != null)
        ? ' · Top Move: ${topMove!.primaryMoveSan ?? topMove.primaryMoveUci} (P: ${topMove.policyPercentage!.toStringAsFixed(1)}%)'
        : '';
    final scoreStr = topMove != null ? ' · Score: ${topMove.formattedScore}' : '';

    switch (searchState) {
      case AnalysisDataState.searching:
        return '$eloStr · Predicting human move...';
      case AnalysisDataState.paused:
        return 'Paused · $eloStr$policyStr$scoreStr';
      case AnalysisDataState.completed:
      default:
        return '$eloStr$policyStr$scoreStr';
    }
  }

  // Stockfish / Conventional Engine
  final nodesStr = totalNodes != null ? _formatNumber(totalNodes!) : '—';
  final String npsText;
  if (nodesPerSecond != null && nodesPerSecond! > 0) {
    npsText = 'N/s: ${_formatNumber(nodesPerSecond!)}';
  } else if (engineName?.toLowerCase().contains('lc0') == true ||
             engineName?.toLowerCase().contains('leela') == true) {
    npsText = 'N/s: N/A';
  } else {
    npsText = isAnalyzing ? 'N/s: —' : 'N/s: —';
  }

  final depthStr = depth != null && depth! > 0
      ? (seldepth != null && seldepth! > depth! ? ', Depth: $depth/$seldepth' : ', Depth: $depth')
      : '';
  final prefix = searchState == AnalysisDataState.paused ? 'Paused · ' : '';

  return '${prefix}Nodes: $nodesStr, $npsText$depthStr';
}
```

---

## 5. Verification Method

1. **Static Analysis**:
   ```powershell
   C:\flutter-sdk\bin\flutter.bat analyze
   ```
   *Expected*: `No issues found!`.

2. **Automated Test Suite**:
   ```powershell
   C:\flutter-sdk\bin\flutter.bat test
   ```
   *Expected*: All 90 existing tests pass. Add unit tests for:
   - `AnalysisGeneration` validation: Verify that lines or arrows with mismatched `(positionRevision, analysisRequestId, engineSessionId)` are rejected.
   - `_parseInfoStringLine` guard: Verify that info strings received during `stopping` or for stale FENs are dropped.
   - `pauseAnalysis()` vs `disableEngine()`: Verify that `pauseAnalysis()` transitions state to `paused` while retaining all `pvLines`, `candidateArrows`, and evaluations, whereas `disableEngine()` resets to neutral.
   - Nullable telemetry formatting: Verify that `nodesPerSecond == null` displays `N/s: N/A` for Lc0 and does not inject fake `0`.
   - Maia completed telemetry: Verify that `searchState == AnalysisDataState.completed` displays Elo, top move policy, and score without prepending `"Paused · "`.

3. **Invalidation Conditions**:
   - Tapping "Pause" on the analysis panel removes arrows or resets the eval bar.
   - Maia mode displays `Nodes: 1, N/s: 0, Depth: 1` or `"Paused · "`.
   - Lc0 displays `N/s: 0` instead of `N/s: N/A`.
   - Switching board orientation or tabs stops the active engine search.
