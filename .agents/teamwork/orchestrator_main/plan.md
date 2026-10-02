# Orchestration Plan — Nibbler Engine Pipeline & Lifecycle Overhaul

## 1. Objectives & Requirements Traceability
- **R1: Complete Nibbler Arrow & Visual Configuration Overhaul**
  - Arrowhead display modes: Winrate %, Expected Score, Policy %, MultiPV Rank (#1, #2, #3), Node %, C-Scale.
  - Arrow filtering: Lc0/Maia rules (policy threshold, visit count, score delta) and conventional engine filters.
  - Nibbler visual layering: Longer shafts strictly underneath shorter; Rank 1 on top; high-contrast borders; collision-resolved badge offsets.
  - Accurate move mapping: Exact source/target squares, proper castling representation.
- **R2: Accurate Telemetry & Engine State Semantics**
  - Stockfish Continuous Analysis: `go infinite` with live high-frequency telemetry (comma-grouped nodes, real NPS, depth, seldepth, MultiPV, WDL).
  - Maia Human Sparring Mode: Lc0 at nodes=1, replace misleading N/s=0 and depth=1 with Elo rating (~1100-1900), move policy probabilities (P: xx%), and eval.
  - Strict State Separation: Eliminate placeholder/synthetic telemetry; engine state matches UI buttons [Pause] vs [Analyze] and headers.
- **R3: Robust Engine & Network Management (Downloading & Deleting)**
  - Artifact Management: Stockfish 19, Lc0 v0.32.1, 10 Maia Elo neural weights (download, verify, status, delete).
  - Deletion Robustness: Process termination, file deletion, storage tally updates, read-only native lib vs downloaded file handling.
  - Atomic Process Lifecycle: No zombie processes, no file lock contention, no restart loops.
- **R4: Comprehensive Verification & Android Validation**
  - Zero static analysis warnings (`flutter analyze`).
  - Unit/widget/integration tests covering arrow modes, telemetry states, file deletion (`flutter test`).
  - Clean release APK verification.

## 2. Phase-by-Phase Plan

### Phase 0: Survey & Assessment
- Spawn 3 parallel Explorers to map the existing codebase architecture:
  - **Explorer 1**: Arrow rendering system, custom painter / widgets, board coordinate mapping, Nibbler settings model/storage.
  - **Explorer 2**: Engine process management, UCI protocol handling, telemetry parsing (Stockfish infinite vs Maia sparring), engine state machines.
  - **Explorer 3**: Engine downloading, asset verification, file storage, deletion handlers, native lib bundling vs app files.
- Aggregate findings into `PROJECT.md` (Architecture, Feature Inventory, Milestones, Interface Contracts, Code Layout).

### Phase 1: Implementation Track Execution
- Decompose into Milestones M1, M2, M3 based on explorer survey.
- For each milestone, execute:
  1. Detailed Explorer investigation of specific module.
  2. Worker implementation with strict integrity guidelines.
  3. 2 independent Reviewers.
  4. 2 Challengers for empirical/edge-case verification.
  5. Forensic Auditor for integrity and anti-cheat verification.
  6. Gate verification.

### Phase 2: Dual Track E2E Testing & Hardening
- Concurrent/sequential E2E test suite construction (Tiers 1-4) derived from user requirements.
- Final Milestone: Pass 100% E2E tests, followed by Tier 5 Adversarial Coverage Hardening.

### Phase 3: Final System Verification & Sentinel Handoff
- Verify clean `flutter analyze` and `flutter test`.
- Package comprehensive handoff report.
