# PROJECT: ChessCrack Engine Telemetry, State Decoupling & UCI Pipeline Hardening

## Architecture Overview
ChessCrack's engine and analysis architecture is structured into decoupled layers:
1. **Engine Artifact & Storage Layer**:
   - `EngineDownloadService`: Manages downloading, verification, disk tracking, and deletion of engine binaries and neural network weights.
   - States: `EngineInstallationState` (`uninstalled`, `downloading`, `verifying`, `installed`, `ready`, `deleting`, `error`).
   - Binaries: Bundled native libraries (`jniLibs` extracted to `nativeLibraryDir`) vs downloaded user updates.
2. **Native Process & UCI Execution Layer**:
   - `UciEngineService`: Spawns and manages native OS processes (Stockfish 19, Lc0 0.32.1).
   - `NativeEngineRunner`: MethodChannel interface to Kotlin runtime for ABI and executable path resolution.
   - States: `EngineLifecycleState` (`uninitialized`, `initializing`, `ready`, `disposed`, `error`).
   - Session Tracking: `engineSessionId` incremented on every process start to invalidate buffered output.
3. **Analysis & Search State Machine Layer**:
   - States: `AnalysisDataState` (`idle`, `searching`, `paused`, `completed`, `stopping`).
   - Generation Invariant: `AnalysisGeneration(positionRevision, analysisRequestId, engineSessionId)`. All PV lines, candidate arrows, and diagnostics must strictly match the active generation.
   - Zero-Bypass Stream Protection: Unified stream guard across `info`, `info string`, and `bestmove`.
   - Search Control: Non-destructive `pauseAnalysis()` (preserves data and eval) vs `resumeAnalysis()`, decoupled from `disableEngine()`.
4. **Data Models & Telemetry Representation**:
   - `PositionAnalysis`: Nullable `int? totalNodes, nodesPerSecond, depth, seldepth, timeMs`.
   - `PvLine`: Nullable `int? depth, seldepth, nodes, nps`, with `winPercentage`, `expectedScore`, `policyPercentage`.
   - `CandidateArrow`: Display modes (`winrate`, `expectedScore`, `policy`, `rank`, `nodePercent`, `cScale`).
5. **Board Overlay & Arrow Presentation Layer**:
   - `NibblerArrowPainter`: Shaft sorting (longer underneath shorter), Rank 1 badge on top with high-contrast border and drop shadow, collision offsets.
   - Filtering: Conventional score-delta / MultiPV rank filters and Lc0/Maia policy threshold / visit filters.
   - Move Coordinates: Exact source and target square mapping, proper King castling ($e1 \to g1$, $e1 \to c1$).

---

## Feature Inventory
Every feature and directive is cataloged with its assigned milestone:

| # | Feature / Directive | Description | Milestone | Source |
|---|---------------------|-------------|-----------|--------|
| 1 | Strict State Decoupling | Decouple `EngineInstallationState`, `EngineLifecycleState`, and `AnalysisDataState` into orthogonal enums | M1 | Directive Focus 1, R2 |
| 2 | Nullable Engine Telemetry | Replace fake 0/1 defaults with `int?` for nodes, nps, depth, seldepth, timeMs across all models & services | M1 | Directive Focus 2, R2 |
| 3 | Atomic Analysis Snapshot & MultiPV Sync | Bundle `(positionRevision, analysisRequestId, engineSessionId)` generation tuple into all lines and arrows | M1 | Directive Focus 3, R2 |
| 4 | Request ID + Revision Validation | Implement zero-bypass guard on all UCI streams including `_parseInfoStringLine` to eliminate ghost data | M1 | Directive Focus 4, R2 |
| 5 | Search State Machine & Thrashing Elimination | Implement true non-destructive `pauseAnalysis()` and `resumeAnalysis()`; eliminate UI/tab/theme restart thrashing | M1 | Directive Focus 5, R2 |
| 6 | Stockfish 19 Real UCI Pipeline | Continuous search (`go infinite`) at full hardware speed with comma grouping, real NPS, depth/seldepth | M2 | Directive Focus 6, R2 |
| 7 | Lc0 0.32.1 Missing Metric Handling | Format omitted NPS as `N/s: N/A` instead of fake 0; validate weights file dependency | M2 | Directive Focus 7, R2 |
| 8 | Maia Human Sparring Architecture | Bounded `go nodes 1`, dynamic engine naming (`Maia 1500`), Elo rating, top move policy P%, clean completion | M2 | Directive Focus 8, R2 |
| 9 | Maia Weights Hot-Swapping | Seamlessly switch Maia Elo levels via `setoption name WeightsFile` without process leaks | M2 | Directive Focus 8, R3 |
| 10 | Nibbler Arrowhead Presentation Modes | Implement Winrate %, Expected Score, Policy %, MultiPV Rank (`#1`), Node %, and C-Scale | M3 | Directive Focus 9, R1 |
| 11 | Arrow Filtering Rules | Support both conventional engine filters and Lc0/Maia policy threshold and visit filters | M3 | Directive Focus 9, R1 |
| 12 | Nibbler Visual Layering & Ordering | Longer shafts underneath shorter shafts; Rank 1 on top; high-contrast rank borders; collision offsets | M3 | Directive Focus 9, R1 |
| 13 | Accurate Move Mapping & Castling | Map exact squares; ensure King castling points to destination square ($g1$/$c1$); handle promotions | M3 | Directive Focus 9, R1 |
| 14 | Robust Engine & Network Artifact Management | Download, verify, track, and delete Stockfish 19, Lc0 0.32.1, and all 10 Maia Elo models | M4 | Directive Focus 8, R3 |
| 15 | Deletion Robustness & Hook Plumbing | Wire `onBeforeEngineRemoved` across all dialog callers; terminate process before delete; update storage tallies | M4 | Directive Focus 8, R3 |
| 16 | Atomic Process Lifecycle & Zombie Prevention | Ensure at most 1 engine process alive; clean `quit` with fallback kill; prevent file lock contention | M4 | Directive Focus 8, R3 |
| 17 | E2E Testing Suite & Regression Verification | Comprehensive opaque-box test suite (Tiers 1-4) covering all features and corner cases | M5 | Directive Focus 10, R4 |
| 18 | Static Analysis & Build Verification | Verify `flutter analyze` (0 issues), `flutter test` (100% pass), and split/universal release APK builds | M5 | Directive Focus 10, R4 |
| 19 | Physical Android Device Validation | Validate live Stockfish 19 continuous search and Maia sparring execution on connected hardware | M5 | Directive Focus 10, R4 |

---

## Milestones

| # | Milestone Name | Scope | Dependencies | Status |
|---|----------------|-------|--------------|--------|
| M1 | Strict State Decoupling & Nullable Telemetry Pipeline | Features 1, 2, 3, 4, 5: State enums, nullable telemetry models, generation tuple, zero-bypass guard, non-destructive pause | None | IN_PROGRESS |
| M2 | Stockfish 19 UCI & Maia Human Sparring Pipeline | Features 6, 7, 8, 9: Stockfish continuous search, Lc0 N/A telemetry, Maia dynamic naming, Elo & policy sparring header, hot-swapping | M1 | PLANNED |
| M3 | Nibbler-Standard Candidate Arrows & Visual Overlay | Features 10, 11, 12, 13: Arrowhead modes, filtering, layering, castling/promotion coordinates, badge collision offsets | M1 | PLANNED |
| M4 | Robust Engine & Network Artifact Management | Features 14, 15, 16: Download/delete lifecycle, storage updates, `onBeforeEngineRemoved` plumbing, zombie elimination | M1, M2 | PLANNED |
| M5 | E2E Verification & Android Hardware Delivery | Features 17, 18, 19: Comprehensive E2E tests, `flutter analyze`, `flutter test`, release APKs, live Android validation | M1, M2, M3, M4 | PLANNED |

---

## Interface Contracts

### 1. State Models (`lib/models/engine_analysis.dart`, `lib/models/engine_download_model.dart`)
- `enum EngineInstallationState`: `uninstalled, downloading, verifying, installed, ready, deleting, error`
- `enum EngineLifecycleState`: `uninitialized, initializing, ready, disposed, error`
- `enum AnalysisDataState`: `idle, searching, paused, completed, stopping`
- `class AnalysisGeneration`: `final int positionRevision; final int analysisRequestId; final int engineSessionId;`
- `class PositionAnalysis`:
  - `final int? totalNodes;`
  - `final int? nodesPerSecond;`
  - `final int? depth;`
  - `final int? seldepth;`
  - `final int? timeMs;`
  - `final AnalysisDataState searchState;`
  - `final bool isMaia;`
  - `final int? maiaElo;`

### 2. Search & Engine Control (`lib/services/uci_engine_service.dart`)
- `void pauseAnalysis()`: Sends `stop`, sets `_searchState = AnalysisDataState.paused`, preserves lines/arrows/eval.
- `void resumeAnalysis()`: Re-issues search on current position without resetting lines/eval.
- `Future<void> disableEngine()`: Stops search, kills process/session, resets data to neutral.
- `String get effectiveEngineDisplayName`: Returns `'Maia $elo'` when Maia active, else `_settings.activeEngine.displayName`.

### 3. Candidate Arrow Modes & Filtering (`lib/models/candidate_arrow.dart`, `lib/models/engine_settings.dart`)
- `enum ArrowheadType`: `winrate, expectedScore, policy, rank, nodePercent, cScale`
- `enum ArrowFilterLc0`: `all, minVisits10, minVisits100, minVisits1000, topMoveOnly, top3Moves, within50PercentVisits, within80PercentVisits, minPolicy1, minPolicy5, within5PctPolicy`
- Castling mapping: Target square for Kingside is $g1$/$g8$; Queenside is $c1$/$c8$.

### 4. Artifact Management & Deletion Hook (`lib/ui/widgets/engine_manager_dialog.dart`, `lib/services/engine_download_service.dart`)
- `EngineManagerDialog.show(..., {Future<void> Function()? onBeforeEngineRemoved})`
- Call sites in `chess_analysis_screen.dart` and `engine_settings_dialog.dart` MUST pass `onBeforeEngineRemoved: () async => await _engineService.disableEngine()`.

---

## Code Layout & File Write Ownership

| Component | Target Files | Exclusive Owner Milestone |
|-----------|--------------|---------------------------|
| State & Telemetry Models | `lib/models/engine_analysis.dart`, `lib/models/candidate_arrow.dart`, `lib/models/engine_download_model.dart` | M1 |
| Engine Service Pipeline | `lib/services/uci_engine_service.dart`, `lib/services/engine_trace_logger.dart` | M1 & M2 |
| Screen & Panel UI Binding | `lib/ui/screens/chess_analysis_screen.dart`, `lib/ui/widgets/engine_analysis_panel.dart` | M1, M2, M4 |
| Arrow Overlay & Rendering | `lib/ui/widgets/nibbler_board.dart`, `lib/ui/widgets/nibbler_arrow_painter.dart`, `lib/models/engine_settings.dart` | M3 |
| Artifact Download & Storage | `lib/services/engine_download_service.dart`, `lib/ui/widgets/engine_manager_dialog.dart`, `lib/ui/widgets/engine_settings_dialog.dart` | M4 |
| E2E Tests & Verification | `test/`, `test/e2e/`, build validation scripts | M5 |
