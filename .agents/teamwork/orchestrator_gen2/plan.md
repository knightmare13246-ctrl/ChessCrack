# Master Engineering Plan: ChessCrack Engine Telemetry, State Decoupling & UCI Pipeline Hardening

## Overview
Comprehensive remediation of the engine-analysis regression across Stockfish 19, Leela Chess Zero (Lc0 0.32.1), and Maia Human Sparring Networks running through Lc0, delivering desktop Nibbler standards on Android.

---

## Phase 0: Discovery & Scope Mapping (Survey)
- Dispatch 3 parallel Explorers:
  - **Explorer 1 (Nibbler Arrow Fidelity & Visual Overlay)**:
    Inspect candidate arrow models, coordinate mapping (castling/promotion), arrowhead badge display modes (Winrate %, Expected Score, Policy %, Rank, Node %, C-Scale), arrow layering (longer shafts underneath shorter shafts, Rank 1 on top), badge collision offsets, and settings persistence.
  - **Explorer 2 (State Decoupling, Telemetry & Search State Machine)**:
    Examine decoupling of `EngineInstallationState`, `EngineLifecycleState`, and `AnalysisDataState`. Nullable telemetry fields (no 0/1 synthetic defaults). Atomic analysis snapshot generation tracking (`positionRevision`, `analysisRequestId`, `engineSessionId`). Request ID validation. Elimination of UI/theme/tab thrashing.
  - **Explorer 3 (Engine Artifact Management, Stockfish 19, Lc0/Maia Architecture & Native Process Lifecycle)**:
    Inspect binary downloading, verification, deletion, and storage tracking. Bundled native libraries vs downloaded updates. Clean process termination with zero zombies. Stockfish 19 continuous search pipeline (`go infinite`). Lc0 0.32.1 telemetry (`N/s: N/A`). Maia human sparring mode (`nodes = 1`, policy %, network hot-swapping). Real Android hardware build pipeline.

---

## Phase 1: Architecture Specification & Synthesis
- Consolidate explorer findings into `PROJECT.md` (or `SCOPE.md`).
- Define Feature Inventory, Interface Contracts, Data Models, and Component Boundaries:
  - `EngineInstallationState`: uninstalled, downloading, verifying, installed, ready, deleting, error.
  - `EngineLifecycleState`: uninitialized, initializing, ready, disposed, error.
  - `AnalysisDataState`: idle, searching, paused, completed, stopping.
  - `PositionAnalysis`: nullable nodes, nps, depth, seldepth, timeMs, generation metadata.
- Establish strict Code Layout and write ownership boundaries.

---

## Phase 2: Milestone Execution

### Milestone 1: Strict State Decoupling & Nullable Telemetry Pipeline
- Decouple `EngineInstallationState`, `EngineLifecycleState`, and `AnalysisDataState`.
- Make telemetry metrics nullable (`int? nodes, int? nps, int? depth, int? seldepth, int? timeMs`).
- Implement atomic snapshot synchronization with `(positionRevision, analysisRequestId, engineSessionId)`.
- Validate all incoming UCI data against current request ID and position revision with zero bypasses.
- Decouple search control from lifecycle: true `pause` (preserves arrows/eval) vs `disable` (resets session). Eliminate UI rebuild thrashing.

### Milestone 2: Stockfish 19 UCI & Maia Human Sparring Pipeline
- Stockfish 19 continuous search: `go infinite` at full native hardware speed with comma-grouped nodes and real NPS.
- Lc0 0.32.1 real telemetry parsing: handle omitted NPS cleanly as `N/s: N/A` without fake 0 defaults.
- Maia Human Sparring Architecture: `go nodes 1`, real policy probability `P: XX.X%`, human sparring header with Elo rating (~1100–1900), natural completion to `completed` state without synthetic "Paused" text.
- Model hot-swapping: seamlessly reload weights or restart Lc0 process when changing Maia Elo levels.

### Milestone 3: Nibbler-Standard Candidate Arrows & Visual Overlay
- Complete suite of arrowhead display modes: Winrate %, Expected Score, Policy %, MultiPV Rank, Node %, C-Scale.
- Arrow filtering: policy threshold, visit count, score delta, conventional rank filters.
- Nibbler visual layering: longer shafts underneath shorter shafts, Rank 1 on top, high-contrast borders.
- Accurate move mapping: exact source/target squares, proper castling king/rook handling, promotion representation.
- Collision-resolved badge offsets.

### Milestone 4: Robust Engine & Network Artifact Management
- Full download, verify, track, and delete lifecycle for Stockfish 19, Lc0 0.32.1, and all 10 Maia Elo models.
- "DELETE" button cleanly terminates active processes, removes files, updates disk storage tallies in real time, and handles bundled vs downloaded binaries.
- Atomic process lifecycle: prevent zombie processes, file locks, or restart loops.

### Milestone 5: E2E Verification & Android Hardware Delivery
- Complete E2E testing suite (Tiers 1–4).
- Static analysis verification: `flutter analyze` with 0 warnings/errors.
- Full test suite: `flutter test` with 100% pass rate.
- Release APK build verification (split per ABI and universal).
- Verification on connected physical Android device.

---

## Phase 3: Final Acceptance & Sentinel Handoff
- Full gate audit and verification report generation.
- Attestation of zero regressions, authentic telemetry, and desktop Nibbler fidelity.
