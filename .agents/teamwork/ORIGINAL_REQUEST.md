# Original User Request

## 2026-10-01T16:12:46Z

# Teamwork Project — Comprehensive Nibbler Engine Pipeline, Arrow Fidelity & Engine Lifecycle Overhaul

Comprehensive architecture review, stability hardening, and feature overhaul across ChessCrack's engine execution, telemetry pipelines, arrow visualization, and modular engine management to strictly match Nibbler's desktop standards on Android.

Working directory: O:\ChessCrack
Integrity mode: development

## Requirements

### R1. Complete Nibbler Arrow & Visual Configuration Overhaul
- Implement the complete suite of Nibbler arrow settings:
  - **Arrowhead display modes**: Winrate %, Expected Score, Policy % (for Lc0/Maia), MultiPV Rank (#1, #2, #3), Node %, and C-Scale.
  - **Arrow filtering**: Support both Lc0/Maia arrow filtering rules (by policy threshold, visit count, or score delta) and conventional engine arrow filters.
  - **Nibbler visual layering**: Longer arrow shafts strictly underneath shorter shafts; Rank 1 on top; high-contrast rank borders; collision-resolved badge offsets.
  - **Accurate move mapping**: Ensure arrows originate from and point directly to the exact source and target squares for all moves, including castling.

### R2. Accurate Telemetry & Engine State Semantics
- **Stockfish Continuous Analysis**: Full speed continuous search (`go infinite`) with live, high-frequency telemetry (Nodes with comma grouping, accurate real NPS, Depth, Seldepth, MultiPV lines, and WDL).
- **Maia Human Sparring Mode**: Maia operates via Leela Chess Zero at `Nodes = 1` for human move prediction. In Maia mode, replace conventional search-tree telemetry (which misleadingly displays `N/s: 0` and `Depth: 1`) with accurate human sparring metrics: Elo rating (~1100 to ~1900), move policy probabilities (e.g., `P: 34.2%`), and evaluation state.
- **Strict State Separation**: Eliminate all placeholder, synthetic, or false telemetry. Engine search state (`searching`, `paused`, `completed`, `ready`) must strictly match the UI button (`[⏸ Pause]` vs `[▶ Analyze]`) and telemetry headers.

### R3. Robust Engine & Network Management (Downloading & Deleting)
- **Engine Artifact Management**: Enable flawless downloading, verification, status tracking, and deletion of all engine binaries (Stockfish 19, Leela Chess Zero v0.32.1) and neural network weights (all 10 Maia Elo models).
- **Deletion Robustness**:
  - Tapping "DELETE" on any installed engine or model must cleanly terminate running processes, delete the files from app storage, update disk storage tallies in real-time, and revert the UI state.
  - Explicitly handle bundled read-only native libraries versus downloaded updates without throwing exceptions or corrupting storage tracking.
- **Atomic Process Lifecycle**: Avoid zombie engine processes, file lock contention during removal, or restart loops.

### R4. Comprehensive Verification & Android Validation
- Verify all changes compile with zero static analysis warnings (`flutter analyze`).
- Run the full test suite (`flutter test`) and add unit/widget tests covering arrow modes, telemetry states, and file deletion.
- Verify the release APK builds cleanly and test all behaviors on real Android hardware.

## Acceptance Criteria

### Engine & Network Lifecycle
- [ ] Any downloaded Maia network or engine binary can be deleted via the "DELETE" button and immediately reflected in storage counters without errors.
- [ ] Downloading engines and networks verifies the binary/weights and transitions through `DOWNLOADING -> VERIFYING -> INSTALLED -> READY`.

### Telemetry & Search
- [ ] Stockfish performs continuous search (`go infinite`) at full hardware speed with live, accurate NPS and nodes.
- [ ] Maia human sparring displays accurate policy percentages and Elo level without displaying `N/s: 0` or false depth values.
- [ ] Telemetry header and Analyze/Pause buttons accurately reflect the actual engine state at all times.

### Nibbler Arrows
- [ ] Arrowhead badges accurately display the selected metric (Winrate, Expected Score, Policy %, or Rank).
- [ ] Arrow layering strictly follows Nibbler rules: longer shafts underneath shorter shafts, badges never obscured.
- [ ] Arrow styling and colors accurately reflect move evaluations.


## 2026-10-01T18:01:13Z

# Teamwork Project — Comprehensive Engine Telemetry, State Decoupling & UCI Pipeline Hardening

Status: APPROVED — IMPLEMENT NOW
Working directory: O:\ChessCrack
Integrity mode: development

## PRIMARY OBJECTIVE
Fix the current ChessCrack engine-analysis regression at the ROOT across Stockfish 19, Leela Chess Zero (Lc0 0.32.1), and Maia Human Sparring Networks running through Lc0.

Key focus areas:
1. Strict State Decoupling: EngineInstallationState, EngineLifecycleState, AnalysisDataState.
2. Nullable Engine Telemetry: nodes, nps, depth, selDepth, timeMs (no fake 0/1 defaults).
3. Atomic Analysis Snapshot & MultiPV Synchronization: Everything belongs to the same (positionRevision, analysisRequestId, engineSessionId) generation.
4. Request ID + Position Revision Validation with Zero Bypasses.
5. Search State Machine & Thrashing Elimination (UI rebuilds, theme changes, or tab changes must never stop/restart search).
6. Stockfish 19 Real UCI Pipeline & Native Performance Benchmarking.
7. Lc0 0.32.1 Real Telemetry & Missing Metric Handling (N/A instead of 0 when NPS is omitted).
8. Maia Human Sparring Architecture (Nodes = 1, real policy P%, official networks, hot-swapping).
9. Nibbler-Standard Candidate Arrows, Castling/Promotion, Ordering & Badges.
10. Physical Android Device Verification on connected device, Flutter analyze (0 issues), Flutter tests (100% pass), and split/universal release APK builds.
