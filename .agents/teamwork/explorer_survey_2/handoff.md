# Handoff Report: Explorer Survey 2 — R2 Accurate Telemetry & Engine State Semantics

**Working Directory**: `O:\ChessCrack\.agents\teamwork\explorer_survey_2`  
**Target Requirement**: R2: Accurate Telemetry & Engine State Semantics  
**Timestamp**: 2026-10-01T16:24:00Z  
**Author**: Explorer 2 (`teamwork_preview_explorer`)

---

## 1. Observation

Direct code observations from inspecting the codebase:

### 1.1 Engine Command Generation & Continuous Search
- **File**: `O:\ChessCrack\lib\services\uci_engine_service.dart`
  - **Lines 115–119**:
    ```dart
    int? get _effectiveNodeLimit {
      if (_settings.isMaiaActive) return 1;
      if (_settings.activeEngine == EngineType.stockfish) return null;
      return _settings.nodeLimit;
    }
    ```
  - **Lines 1157–1163**:
    ```dart
    final effectiveNodeLimit = _effectiveNodeLimit;
    if (effectiveNodeLimit != null) {
      _sendCommand('go nodes $effectiveNodeLimit');
    } else {
      _sendCommand('go infinite');
    }
    ```
  - **Observation**: Stockfish correctly receives `go infinite` when analysis starts, while Maia correctly receives `go nodes 1` because `_settings.isMaiaActive` forces `_effectiveNodeLimit` to `1`.
  - **Lines 123–138**: Session reuse logic in `initializeEngine`:
    ```dart
    final bool engineChanged = settings != null && settings.activeEngine != _settings.activeEngine;
    if (settings != null) {
      _settings = settings;
    }
    if (!forceRestart &&
        !engineChanged &&
        isProcessAlive &&
        (_lifecycleState == EngineLifecycleState.ready ||
            _lifecycleState == EngineLifecycleState.analyzing ||
            _lifecycleState == EngineLifecycleState.idle)) {
      _setLifecycle(_lifecycleState, '${_settings.activeEngine.displayName} active (reused session)');
      return;
    }
    ```
    If `activeEngine` remains `EngineType.lc0` but `selectedMaiaId` or `weightsPath` changes (e.g. user selects `maia_1500` after `maia_1100`), `initializeEngine` does not restart the process with the new `--weights` CLI argument if `forceRestart` is false.

### 1.2 Maia Human Sparring Telemetry & Natural Completion
- **File**: `O:\ChessCrack\lib\services\uci_engine_service.dart`
  - **Lines 410–417**:
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
  - **Observation**: In Maia mode, Lc0 evaluates `go nodes 1` in ~10–50ms and emits `bestmove`. `_handleBestMove()` transitions `_searchState` to `EngineSearchState.ready` and sets `_isAnalyzing = false`.
- **File**: `O:\ChessCrack\lib\models\engine_analysis.dart`
  - **Lines 388–408**:
    ```dart
    String get formattedHeader {
      final formattedNodes = _formatNumber(totalNodes);
      final String npsText;
      if (isAnalyzing) {
        if (nodesPerSecond > 0) {
          npsText = 'N/s: ${_formatNumber(nodesPerSecond)}';
        } else {
          npsText = (engineName?.toLowerCase().contains('leela') == true ||
                  engineName?.toLowerCase().contains('lc0') == true ||
                  engineName?.toLowerCase().contains('maia') == true)
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
  - **Observation**: Because `_isAnalyzing` becomes `false` upon reaching 1 node, `formattedHeader` outputs:
    `"Paused · Nodes: 1, N/s: —, Depth: 1"` (or `"Nodes: 1, N/s: N/A, Depth: 1"` if still considered analyzing).
    It displays conventional search tree metrics (`Nodes: 1, N/s: —, Depth: 1`) instead of human sparring metrics: Elo rating (~1100 to ~1900), move policy probability (`P: XX.X%`), and evaluation state.
    It falsely displays `"Paused · "` even when the user never paused the engine.

### 1.3 Telemetry Parsing (Stockfish & Lc0/Maia)
- **File**: `O:\ChessCrack\lib\services\uci_engine_service.dart`
  - **Lines 616–704**: `_parseInfoLine()` parses `multipv`, `depth`, `seldepth`, `time`, `nodes`, `nps`, `hashfull`, `tbhits`, `currmove`, `currmovenumber`, `movesleft`, `score cp`, `score mate`, `wdl`, `n`, `p`, `u`, `pv`.
  - **Lines 529–578**: `_parseInfoStringLine()` extracts `(P: XX.XX%)` into `_positionPolicyCache`, `N: XX` into `_positionVisitsCache`, and `(M: XX.X)` into `_positionMlhCache`.
  - **Lines 732–772**: `PvLine` is constructed with `policyPercentage`, `visitPercentage`, `movesLeft`, `wdl`, `nodes`, `nps`, `depth`, `seldepth`.
  - **Lines 794–816**: `CandidateArrow` is constructed with `policyPercentage`, `visits`, `totalNodes`, `nodePercentage`, `movesLeft`, `depth`.
  - **File**: `O:\ChessCrack\lib\ui\widgets\engine_analysis_panel.dart`
  - **Lines 427–450**: `_formatLineMetrics()` displays:
    ```dart
    if (enabledStats.contains('policy') && line.policyPercentage != null) {
      parts.add('P: ${line.policyPercentage!.toStringAsFixed(1)}%');
    }
    if (enabledStats.contains('depth') && line.depth > 0) {
      parts.add('d: ${line.depth}');
    }
    if (enabledStats.contains('nodes') && line.nodes > 0) {
      parts.add('nodes: ${line.nodes}');
    }
    if (enabledStats.contains('nps') && line.nps > 0) {
      parts.add('${(line.nps / 1000).toStringAsFixed(0)}k nps');
    }
    ```
  - **Observation**: For Maia lines, displaying `d: 1, nodes: 1` creates noise. But policy percentage `P: XX.X%` is already correctly parsed from UCI and stored in `PvLine.policyPercentage` and `CandidateArrow.policyPercentage`.

### 1.4 State Machine & UI Button Desynchronization
- **File**: `O:\ChessCrack\lib\services\engine_trace_logger.dart`
  - **Lines 3–8**:
    ```dart
    enum EngineSearchState {
      idle,
      ready,
      searching,
      stopping,
    }
    ```
    `EngineSearchState` does not contain `paused` or `completed`.
- **File**: `O:\ChessCrack\lib\models\engine_analysis.dart`
  - `PositionAnalysis` (lines 343–370) has `final bool isAnalyzing;`, but lacks `EngineSearchState searchState` or `isMaia`.
- **File**: `O:\ChessCrack\lib\ui\screens\chess_analysis_screen.dart`
  - **Lines 478–492**:
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
  - **Lines 732–733, 853–855**:
    ```dart
    EngineAnalysisPanel(
      analysis: _currentAnalysis,
      isAnalyzing: _isLiveAnalysisActive && _engineService.isAnalyzing,
      onToggleAnalysis: _toggleLiveAnalysis,
    ```
- **File**: `O:\ChessCrack\lib\ui\widgets\engine_analysis_panel.dart`
  - **Lines 93–120**:
    ```dart
    GestureDetector(
      onTap: onToggleAnalysis,
      child: Container(
        ...
        child: Row(
          children: [
            Icon(isAnalyzing ? Icons.pause : Icons.play_arrow),
            Text(isAnalyzing ? 'Pause' : 'Analyze'),
          ],
        ),
      ),
    )
    ```
- **File**: `O:\ChessCrack\lib\services\uci_engine_service.dart`
  - **Lines 245–281**: `disableEngine()`:
    ```dart
    stopAnalysis();
    _activationState = EngineActivationState.disabled;
    _setLifecycle(EngineLifecycleState.idle, 'Engine disabled');
    _currentLines.clear();
    _candidateArrowsMap.clear();
    ...
    _evaluationNotifier.value = NormalizedEvaluation.neutral;
    _emitThrottledAnalysis(force: true);
    ```
- **Observation**:
  - The Pause button in `EngineAnalysisPanel` calls `_toggleLiveAnalysis()`, which invokes `disableEngine()` and sets `_currentAnalysis = null`.
  - Tapping "Pause" behaves as "Disable Engine and Wipe All Data", removing all candidate arrows, lines, and resetting the eval bar.
  - In Maia mode, because `_isAnalyzing` becomes `false` when 1 node completes, the button flips to `[▶ Analyze]`. Tapping `[▶ Analyze]` calls `_toggleLiveAnalysis()`, which flips `_isLiveAnalysisActive` to `false` and disables the engine.

---

## 2. Logic Chain

1. **Premise 1**: Stockfish Continuous Search:
   - `_effectiveNodeLimit` is `null` for Stockfish.
   - `UciEngineService._startSearchOnEngine()` sends `position fen $_currentFen` followed by `go infinite`.
   - Incoming `info` lines stream `nodes`, `nps`, `depth`, `seldepth`, `wdl`, `score`, and `pv`.
   - `_formatNumber(totalNodes)` performs comma-grouping.
   - *Defect*: `PositionAnalysis.formattedHeader` omits `seldepth` (which Stockfish supplies), and if paused, shows `N/s: —`.

2. **Premise 2**: Maia Human Sparring Mode:
   - Maia is an Lc0 neural net model configured with `selectedMaiaId` (Elo 1100–2200).
   - `_effectiveNodeLimit` returns `1`. Lc0 is commanded with `go nodes 1`.
   - Lc0 finishes almost instantaneously (~10–50ms) and issues `bestmove`.
   - `_handleBestMove()` transitions `_searchState` to `ready` and sets `_isAnalyzing = false`.
   - *Defect 1*: `PositionAnalysis.formattedHeader` evaluates `!isAnalyzing` and prepends `"Paused · "`.
   - *Defect 2*: `formattedHeader` prints `"Nodes: 1, N/s: —, Depth: 1"` (or `"N/s: N/A"`).
   - *Requirement R2 Violation*: Conventional tree telemetry must be replaced in Maia mode with human sparring metrics: Maia model Elo (e.g. `Maia 1500 (Elo ~1500)`), top move policy probability (`P: 34.2%`), and evaluation state, with no `N/s: 0` or false depth values.

3. **Premise 3**: State Machine & UI Synchronization:
   - R2 mandates strict separation of 4 search states: `searching`, `paused`, `completed`, `ready`.
   - Currently, `EngineSearchState` has `idle`, `ready`, `searching`, `stopping`.
   - In `ChessAnalysisScreen`, there is only `_isLiveAnalysisActive` and `_engineService.isAnalyzing`.
   - The panel button `[⏸ Pause] / [▶ Analyze]` is wired to `_toggleLiveAnalysis()`.
   - Calling `_toggleLiveAnalysis()` executes `disableEngine()`, wiping all candidate arrows, lines, and resetting the eval bar to neutral.
   - *Defect*: A true `pause` action does not exist. Pausing should stop UCI computation via `stop`, transition to `paused`, and retain all lines, arrows, and evaluations on screen.
   - *Defect*: When `completed` (e.g. Maia 1-node search completes), the engine state is `completed`. The UI button should display `[▶ Analyze]`, and the header must show completed sparring metrics, not `"Paused"`.

---

## 3. Caveats

- **No Caveats**: The entire UCI engine lifecycle, telemetry parsing, formatting, state machine, and UI bindings were directly read from source code, traced, and verified against tests (`flutter test` passes with 90/90 tests, `flutter analyze` reports 0 issues).
- All 10 Maia models in `EngineDownloadService` use official upstream naming and weights URLs (`maia-1100.pb.gz` through `maia-2200.pb.gz`).
- No modifications were made to the source tree in this survey task (strictly read-only investigation).

---

## 4. Conclusion & Actionable Design

To achieve complete compliance with Requirement R2, the following changes are required:

### 4.1 Update `EngineSearchState` & State Semantics
Add `paused` and `completed` to `EngineSearchState` in `lib/services/engine_trace_logger.dart`:
```dart
enum EngineSearchState {
  ready,
  searching,
  paused,
  completed,
  stopping,
  idle,
}
```
State semantics:
- `searching`: UCI process running `go infinite` or `go nodes 1`.
- `paused`: User paused search on current position. Engine sent `stop`. Telemetry, arrows, lines, and evaluation bar are preserved.
- `completed`: Bounded search finished naturally (Maia `nodes = 1`, or checkmate/draw reached). Telemetry, arrows, lines, and evaluation bar are preserved.
- `ready`: Engine idle/ready to receive new position.

### 4.2 Decouple Master ON/OFF from Pause/Analyze
In `UciEngineService`:
- Add `void pauseAnalysis()`:
  - If searching, send `stop`, set `_searchState = EngineSearchState.paused`, set `_isAnalyzing = false`.
  - DO NOT clear `_currentLines`, `_candidateArrowsMap`, or `_evaluationNotifier`.
  - Emit throttled analysis update so UI updates header to `"Paused · ..."`.
- Add `void resumeAnalysis()`:
  - If `paused` or `completed` or `ready`, call `startAnalysis(_currentPosition)`.
- Keep `disableEngine()` for the top app bar `ON / OFF` toggle.
- In `ChessAnalysisScreen`:
  - `_toggleSearchPause()`: calls `_engineService.pauseAnalysis()` when searching, or `_engineService.resumeAnalysis()` when paused/completed.
  - Pass `_toggleSearchPause` to `EngineAnalysisPanel.onToggleAnalysis`.

### 4.3 Maia Human Sparring Telemetry in `PositionAnalysis` & Header
In `PositionAnalysis`:
- Pass `searchState`, `isMaia`, `maiaElo`, `seldepth`, and `topPolicyPercent`.
- Update `formattedHeader`:
  ```dart
  if (isMaia) {
    final eloStr = maiaElo != null ? 'Maia $maiaElo (~$maiaElo Elo)' : 'Maia Human Sparring';
    final topMove = pvLines.isNotEmpty ? pvLines.first : null;
    final policyStr = (topMove?.policyPercentage != null)
        ? ' · Top Move: ${topMove!.primaryMoveSan ?? topMove.primaryMoveUci} (P: ${topMove.policyPercentage!.toStringAsFixed(1)}%)'
        : '';
    final scoreStr = topMove != null ? ' · Score: ${topMove.formattedScore}' : '';

    if (searchState == EngineSearchState.searching) {
      return '$eloStr · Predicting move...';
    } else if (searchState == EngineSearchState.paused) {
      return 'Paused · $eloStr$policyStr$scoreStr';
    } else {
      return '$eloStr$policyStr$scoreStr';
    }
  } else {
    // Stockfish / conventional engine
    final formattedNodes = _formatNumber(totalNodes);
    final String npsText = isAnalyzing && nodesPerSecond > 0
        ? 'N/s: ${_formatNumber(nodesPerSecond)}'
        : 'N/s: —';
    final seldepthStr = (seldepth > 0 && seldepth > depth) ? '/$seldepth' : '';
    final depthText = depth > 0 ? ', Depth: $depth$seldepthStr' : '';
    final prefix = searchState == EngineSearchState.paused ? 'Paused · ' : '';
    return '${prefix}Nodes: $formattedNodes, $npsText$depthText';
  }
  ```
- In `EngineAnalysisPanel._formatLineMetrics`:
  When `isMaiaActive`, suppress `d: 1` and `nodes: 1`, and prioritize `P: XX.X%` and score.

### 4.4 Lc0 / Maia Weights Switching Handshake
In `UciEngineService.initializeEngine`:
Check if `settings.weightsPath != _settings.weightsPath` or `settings.selectedMaiaId != _settings.selectedMaiaId`. If changed, do not reuse session without reloading weights or force-restarting Lc0 with the target model.

---

## 5. Verification Method

1. **Static Analysis**:
   ```powershell
   C:\flutter-sdk\bin\flutter.bat analyze
   ```
   *Expected*: `No issues found!`.

2. **Automated Unit & Widget Tests**:
   ```powershell
   C:\flutter-sdk\bin\flutter.bat test
   ```
   *Expected*: All existing 90 tests pass, plus new tests verifying:
   - Maia telemetry header formatting: confirms Elo rating and policy % are displayed without `N/s: 0` or `Depth: 1`.
   - Stockfish continuous search: confirms comma-grouped nodes, real NPS, depth/seldepth formatting.
   - Non-destructive pause: confirms pausing search preserves candidate arrows, lines, and evaluation bar.
   - State machine: confirms transitions across `searching`, `paused`, `completed`, `ready`.

3. **Invalidation Conditions**:
   - Tapping "Pause" clears candidate arrows or lines.
   - Maia mode displays `N/s: 0`, `N/s: N/A`, or `Depth: 1` in the header.
   - Maia mode displays `"Paused"` immediately after 1-node search completes without user interaction.
   - The panel button shows `[▶ Analyze]` while Stockfish is actively searching `go infinite`.
