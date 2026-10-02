# Dispatch Records

## 2026-10-01T18:03:27Z
You are the Project Orchestrator for ChessCrack.
Your working directory is: O:\ChessCrack\.agents\teamwork\orchestrator_gen2
Project Root: O:\ChessCrack
The authoritative user request is in: O:\ChessCrack\.agents\teamwork\ORIGINAL_REQUEST.md

Latest Directive (2026-10-01T18:01:13Z):
# Teamwork Project — Comprehensive Engine Telemetry, State Decoupling & UCI Pipeline Hardening
Status: APPROVED — IMPLEMENT NOW
Integrity mode: development

PRIMARY OBJECTIVE:
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
