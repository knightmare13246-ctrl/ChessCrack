# TEST_INFRA: Comprehensive E2E & Integration Testing Infrastructure

## 1. Test Philosophy & Design Principles

### Opaque-Box & Requirement-Driven
- Tests validate observable system behavior across UI widgets, services, and domain pipelines rather than inspecting private internal variables.
- All expected outcomes are derived directly from:
  1. Official user requirements in `ORIGINAL_REQUEST.md`.
  2. Architecture specifications and interface contracts in `PROJECT.md`.
  3. FIDE Laws of Chess and standard UCI (Universal Chess Interface) protocol specifications.
  4. Desktop Nibbler standards for arrow rendering, MultiPV sorting, WDL conversion, and badge formatting.
- **Zero Facade Tests**: Every test exercises genuine computational logic, state transitions, parsing engines, formatting routines, and rendering pipelines. No mock can bypass core business rules or assertions.

### Progressive Testability & Isolation
- Tests are self-contained, idempotent, and isolated.
- No test depends on the side effects or execution order of preceding tests.
- System resources (temporary files, stream subscriptions, timers) are cleaned up in `tearDown` or `dispose`.

---

## 2. Complete Feature Inventory to Test Tier Mapping

Every feature from `PROJECT.md` is mapped across the 4-tier testing hierarchy:

| Feature # | Feature Name | Tier 1 (Coverage) | Tier 2 (Boundary & Corner) | Tier 3 (Cross-Feature Pairwise) | Tier 4 (Real-World Scenarios) |
|---|---|---|---|---|---|
| F1 | Strict State Decoupling | Activation vs Lifecycle vs Search enums | Rapid toggle states, error recovery | Stockfish/Lc0 with background pause | Scenario 5 (Lifecycle Interruption) |
| F2 | Nullable Engine Telemetry | Nullable nodes, nps, depth, seldepth | Zero nodes, omitted NPS, empty lines | Lc0 omitted NPS vs Stockfish continuous | Scenario 1 (Continuous Analysis) |
| F3 | Atomic Snapshot & MultiPV Sync | Generation tuple `(rev, req, session)` | Out-of-order PV packets, race conditions | MultiPV lines with rapid board moves | Scenario 2 (Tactical Move Trees) |
| F4 | Request ID + Revision Validation | Zero-bypass filter on UCI stream | Stale revision, negative IDs, 0 req ID | Background resume with new request ID | Scenario 5 (Interruption & Resume) |
| F5 | Search State Machine & Thrashing | `pauseAnalysis` vs `resumeAnalysis` vs `disableEngine` | Theme/tab switch does not abort search | Multi-tab switching during live search | Scenario 5 (Dialog & Settings switch) |
| F6 | Stockfish 19 Real UCI Pipeline | Comma-grouped nodes, real NPS formatting | Extreme node counts (>1B), depth > 100 | MultiPV 5 lines with WDL and eval bar | Scenario 1 & 2 (Deep Master Games) |
| F7 | Lc0 0.32.1 Missing Metric Handling | `N/s: N/A` when NPS omitted from UCI | Zero NPS, missing depth, missing time | Lc0 backend switching CPU vs OpenCL | Scenario 4 (Neural Sparring) |
| F8 | Maia Human Sparring Architecture | Dynamic name `Maia 1500`, Elo, Policy % | Nodes = 1 natural completion, no "Paused" | Maia hot-swap with active sparring | Scenario 4 (Maia Elo Ladder) |
| F9 | Maia Weights Hot-Swapping | Elo level switching (1100 to 2200) | Missing model file, corrupted weights | Switch Maia during active search | Scenario 4 (Sparring Ladder) |
| F10 | Nibbler Arrowhead Modes | Winrate, Expected Score, Policy, Rank, Node %, Moves Left | Missing metric returns `N/A`, division by 0 | Stockfish vs Lc0 badge semantics | Scenario 2 & 3 (Tactical Badges) |
| F11 | Arrow Filtering Rules | All, Top1, Top2, Top3, MinNodes, Within2/5% | Rank 1 absolute protection invariant | Combined filters with extreme evaluations | Scenario 2 (Blunder Detection) |
| F12 | Nibbler Visual Layering & Ordering | Longer shafts under shorter; Rank 1 on top | Identical lengths tie-broken by rank | Multi-arrow collision with badge offset | Scenario 2 (Deep Tactical Overlays) |
| F13 | Accurate Move Mapping & Castling | Exact square mapping; Castling $e1 \to g1/c1$ | Promotions ($e7 \to e8=q$), En Passant | Board flipped (Black perspective) | Scenario 1 & 3 (Castling & Promotions) |
| F14 | Robust Artifact Management | Download, verify, track, delete (SF, Lc0, Maia) | Network failure, cancelled download | Parallel download requests | Scenario 5 (Download & Delete) |
| F15 | Deletion Robustness & Hook Plumbing | `onBeforeEngineRemoved` fires before delete | Delete active engine while searching | Disk tally updates in real time | Scenario 5 (Active Engine Removal) |
| F16 | Atomic Process Lifecycle & Zombie Elimination | At most 1 process alive; clean termination | SIGTERM / SIGKILL fallback, file locks | Process count invariant across transitions | Scenario 5 (Lifecycle & Process Safety) |
| F17 | E2E Testing Suite | Opaque-box execution across all modules | Stress-testing stream inputs | Pairwise integration verification | Scenarios 1-5 |
| F18 | Static Analysis & Build Verification | `flutter analyze` 0 issues, `flutter test` 100% | Analyzer lints, unhandled nulls | Platform build compatibility | Full suite execution |
| F19 | Physical Android Validation | Device ABI detection, jniLibs vs documents | x86 vs ARM detection, storage paths | Real device APK execution | Android hardware gate |

---

## 3. Systematic 4-Tier Test Design

### Tier 1: Feature Coverage (>=5 test cases per feature category)
Detailed unit and integration tests verifying the happy path and primary specifications for each feature:
- **T1.1 State Machine & Search Control**:
  1. `EngineActivationState` transitions between `disabled`, `starting`, `enabled`.
  2. `pauseForBackground()` pauses search without killing engine process.
  3. `resumeFromBackground()` creates a strictly monotonic `analysisRequestId` while preserving `positionRevision`.
  4. `activeProcessCount` never exceeds 1 under any sequence of calls.
  5. `disableEngine()` resets session and evaluation to neutral.
- **T1.2 Telemetry & Formatting**:
  1. Node count comma grouping formats single, thousand, million, and billion values accurately (`1,360,000`).
  2. Stockfish live NPS formats with `N/s: <formatted_number>`.
  3. Lc0 omitted NPS formats as `N/s: N/A` instead of fake 0.
  4. Depth and Seldepth tracking correctly reflected in formatted headers and diagnostics.
  5. PositionAnalysis formats non-Maia paused state with prefix `Paused · Nodes: ...`.
- **T1.3 Maia Human Sparring**:
  1. Engine name dynamically formats as `Maia <elo>` (e.g. `Maia 1500`).
  2. Maia analyzing header formats as `Maia <elo> · Evaluating Human Moves...`.
  3. Maia completed header formats as `Maia <elo> · Evaluation Complete (1-ply Policy)` without synthetic "Paused".
  4. Policy percentage formatting in PV lines (`P: 34.20%`).
  5. Arrowhead badge in policy mode displays rounded policy percentage (`22`).
- **T1.4 Arrow Modes & Filtering**:
  1. Winrate mode displays pure win percentage or expected score.
  2. Expected score mode displays calculated score.
  3. Policy mode displays neural prior for Lc0 and `N/A` for Stockfish.
  4. MultiPV rank mode displays 1-based rank (`1`, `2`, `3`).
  5. Node % mode displays candidate visit ratio for Lc0 and `N/A` for Stockfish.
  6. Moves Left Ahead mode displays MLH for Lc0 and mate distance for Stockfish.
- **T1.5 Artifact Deletion & Storage Lifecycle**:
  1. `removeStockfish()` invokes `onBeforeDelete` before unlinking files.
  2. `removeLc0()` invokes `onBeforeDelete` before unlinking files.
  3. `removeMaiaModel()` invokes `onBeforeDelete` and clears `installedSizeBytes`.
  4. `getStorageSummary()` reflects cumulative storage size in bytes and drops to 0 after removal.
  5. `isBundled` accurately identifies system native libraries (`libstockfish.so`).

### Tier 2: Boundary & Corner Cases (>=5 test cases per feature category)
Tests for extreme inputs, degenerate conditions, network interruptions, and malformed inputs:
- **T2.1 Telemetry Boundaries**:
  1. Zero nodes (`0`) formatted cleanly without commas or negative offsets.
  2. Extreme nodes (`12,345,678,901`) formatted with multiple comma groupings.
  3. Null / omitted `scoreCp` and `scoreMate` handled gracefully with fallback expected score.
  4. Missing request ID (<= 0) rejected by arrow painter and telemetry streams.
  5. Stale position revision rejected with zero bypasses.
- **T2.2 Arrow Rendering Boundaries**:
  1. Sibling arrows from same source square receive quadratic curvature offsets without crashing.
  2. Zero-length move (`from == to`) rejected by arrow painter.
  3. Illegal move string rejected by legal move validator before paint.
  4. Severe pruning in `filterCandidateArrows` retains Rank 1 candidate (never drops below 1 arrow).
  5. Rapid successive position changes reject out-of-sequence arrow frames.
- **T2.3 Sparring & Search Boundaries**:
  1. Bounded search `go nodes 1` produces immediate single-node completion.
  2. Dead drawn endgame WDL (`[0, 1000, 0]`) produces exactly 50.0% expected score.
  3. Mate-in-1 (`scoreMate: 1`) produces 100% expected score and `+M1` badge.
  4. Getting mated (`scoreMate: -1`) produces 0% expected score and `-M1` badge.
  5. Perspective inversion: Black to move with mate-in-1 produces White expected score of 0.0%.
- **T2.4 Artifact & Storage Boundaries**:
  1. Deletion of non-existent artifact completes gracefully without throwing filesystem exceptions.
  2. Unlink of read-only bundled library handled cleanly without filesystem corruption.
  3. Zero bytes received during failed download transitions to `DownloadStatus.error`.
  4. Incomplete download file (`.download`) cleaned up on error or cancellation.
  5. Architecture mismatch (e.g. x86_64 on Android) marks status as `unsupported`.

### Tier 3: Cross-Feature Combinations (Pairwise Coverage)
Matrix of pairwise interactions testing combined features:
- **Engine Type $\times$ Arrowhead Mode**:
  - Stockfish with Winrate, Expected Score, Policy (`N/A`), Rank, Node % (`N/A`), Moves Left (Mate fallback).
  - Lc0 with Winrate, Expected Score, Policy (P%), Rank, Node % (N%), Moves Left (MLH).
- **Engine Type $\times$ Arrow Filters**:
  - Stockfish with `within50Cp`, `within100Cp`, `top1`, `top2`, `top3`.
  - Lc0 with `minNodes1`, `minNodes5`, `within2PctScore`, `within5PctScore`, `all`.
- **Search State $\times$ UI Rebuilding**:
  - Active search preserved during theme switch (`LichessTheme`).
  - Active search preserved during tab switch (Engine Analysis $\to$ Game Tree $\to$ Diagnostics).
  - Active search paused during app backgrounding (`AppLifecycleState.paused`) and cleanly resumed on foreground (`AppLifecycleState.resumed`).
- **Active Search $\times$ Model Deletion**:
  - Calling deletion on active engine cleanly invokes `disableEngine()` to kill process before file deletion.
  - Active UI panel updates immediately to uninstalled/disabled state.

### Tier 4: Real-World Application Scenarios (>=5 Realistic Scenarios)
1. **Scenario 1: The Opera Game (Morphy vs Duke Karl / Count Isouard, 1858)**
   - Walk through move tree from initial position through 1. e4 e5 2. Nf3 d6 3. d4 Bg4 ... 16. Qb8+!! Nxb8 17. Rd8#.
   - Verify Stockfish MultiPV analysis generation, monotonic request IDs, and checkmate detection.
2. **Scenario 2: Kasparov's Immortal (Kasparov vs Topalov, Wijk aan Zee 1999)**
   - Analyze critical position after 24. Rxd4!! (FEN: `r1b1k2r/pp1p1p2/2n1p1p1/q1p1P1Pp/2P2P2/1PnB1N2/PB1P3P/R2QK2R w KQkq - 0 14`).
   - Verify candidate arrows layering (longer shafts underneath shorter), high-contrast Rank 1 badge on top, and badge collision avoidance.
3. **Scenario 3: Endgame Pawn Promotion & Checkmate Conversion**
   - Endgame position with passed pawn on 7th rank (`8/4P3/8/8/8/8/k7/4K3 w - - 0 1`).
   - Move $e7 \to e8=Q$, verify move mapping coordinates, promotion SAN notation (`e8=Q` or figurine `e8=♕`), and mate line updates.
4. **Scenario 4: Maia Human Sparring Elo Ladder**
   - User switches between Maia 1100, Maia 1500, and Maia 1900 on a typical tactical position with a human blunder.
   - Verify dynamic engine naming, human sparring header, 1-node policy evaluation without conventional search metrics, and natural completion without synthetic "Paused".
5. **Scenario 5: Active Analysis Interruption & Artifact Management**
   - User initiates continuous analysis, opens engine manager dialog, deletes the active engine/network model.
   - Verify `onBeforeEngineRemoved` terminates the active engine process, deletes files from disk, updates storage tally in real time, and resets the UI safely.

---

## 4. Test Suite Execution & Invalidation Conditions

### Test Suite Execution
Execute the entire E2E test suite using Flutter's single-threaded runner to preserve deterministic logging and timing:
```powershell
& "C:\flutter-sdk\bin\flutter.bat" test -j 1 test/e2e/
```

### Invalidation Conditions
A test run is considered INVALID if:
1. Any test produces unhandled exceptions or crashes.
2. Any test relies on network connectivity to download external binaries during execution (must use local mocks / test fixtures).
3. Any test produces zombie OS processes (`stockfish.exe` or `lc0.exe` left running after test execution).
4. Telemetry displays fake 0 or 1 values where nullable metrics (`N/A` or `—`) are specified.
5. Rank 1 candidate arrow is ever pruned by filtering thresholds.
