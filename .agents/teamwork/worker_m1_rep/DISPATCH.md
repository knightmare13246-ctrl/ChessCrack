## 2026-10-01T19:19:18Z
You are Worker M1 (Replacement) for ChessCrack.
Your Working Directory is: O:\ChessCrack\.agents\teamwork\worker_m1_rep
Read O:\ChessCrack\.agents\teamwork\ORIGINAL_REQUEST.md, O:\ChessCrack\.agents\teamwork\PROJECT.md, O:\ChessCrack\.agents\teamwork\TEST_READY.md, and O:\ChessCrack\.agents\teamwork\explorer_survey_2_gen2\handoff.md before beginning.

CONTEXT & INTERRUPTION RECOVERY:
The previous worker was interrupted by a token error mid-edit. Your first step is to inspect the current state of modified files via `git status` and `git diff` across:
- lib/models/engine_analysis.dart
- lib/models/candidate_arrow.dart
- lib/models/engine_download_model.dart
- lib/services/engine_trace_logger.dart
- lib/services/uci_engine_service.dart
- lib/ui/screens/chess_analysis_screen.dart
- lib/ui/widgets/engine_analysis_panel.dart

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

EXCLUSIVE WRITE OWNERSHIP:
- lib/models/engine_analysis.dart
- lib/models/candidate_arrow.dart
- lib/models/engine_download_model.dart
- lib/services/engine_trace_logger.dart
- lib/services/uci_engine_service.dart
- lib/ui/screens/chess_analysis_screen.dart
- lib/ui/widgets/engine_analysis_panel.dart
- test/services/uci_engine_service_test.dart (and any unit tests)

MISSION (Milestone 1 Completion):
1. Complete Strict State Decoupling:
   - `EngineInstallationState`: `uninstalled`, `downloading`, `verifying`, `installed`, `ready`, `deleting`, `error`
   - `EngineLifecycleState`: `uninitialized`, `initializing`, `ready`, `disposed`, `error`
   - `AnalysisDataState`: `idle`, `searching`, `paused`, `completed`, `stopping` (replacing overloaded states in `EngineSearchState`).
2. Complete Nullable Engine Telemetry:
   - Convert all synthetic 0 defaults to nullable `int?`:
     - `PvLine`: `int? depth`, `int? seldepth`, `int? nodes`, `int? nps`
     - `PositionAnalysis`: `int? totalNodes`, `int? nodesPerSecond`, `int? depth`, `int? seldepth`, `int? timeMs`
     - `CandidateArrow`: `int? depth`
     - `EngineDiagnostics`: `int? totalNodes`, `int? nps`, `int? depth`, `int? seldepth`, `int? timeMs`
     - `UciEngineService`: `int? _currentNodes`, `int? _currentNps`, `int? _currentDepth`, `int? _currentSeldepth`, `int? _currentTimeMs`.
   - Update `PositionAnalysis.formattedHeader` to safely format nullable fields (`_formatNumber` when non-null, else '—'), and format missing NPS as `N/s: N/A` for Lc0.
3. Complete Atomic Analysis Snapshot & MultiPV Synchronization:
   - Introduce `engineSessionId` (incremented on each process launch).
   - Bundle `(positionRevision, analysisRequestId, engineSessionId)` generation tuple into all lines, arrows, and snapshot validation.
   - Filter `_emitThrottledAnalysis` so only lines and arrows matching the exact current generation are emitted.
4. Complete Zero-Bypass Stream Protection:
   - Unify stream validation so `_parseInfoLine`, `_parseInfoStringLine`, and `_handleBestMove` discard stale lines (session mismatch, disabled engine, stopping state for non-bestmove, or FEN mismatch).
5. Complete Search Control Decoupling:
   - Implement `pauseAnalysis()`: sends `stop`, sets `searchState = AnalysisDataState.paused`, keeps candidate arrows, lines, and eval intact.
   - Implement `resumeAnalysis()`: restarts search on active position without clearing data.
   - Retain `disableEngine()` for the master ON/OFF toggle.
   - Wire `EngineAnalysisPanel.onToggleAnalysis` to toggle `pauseAnalysis()` and `resumeAnalysis()`.
6. Verification & Tests:
   - Run `& "C:\flutter-sdk\bin\flutter.bat" analyze` and ensure 0 errors/warnings.
   - Run `& "C:\flutter-sdk\bin\flutter.bat" test -j 1` and ensure 100% pass rate across all tests (both existing unit tests and test/e2e/ suites).
   - Document verification commands and verbatim output in your handoff.

OUTPUT:
Write your report to: `O:\ChessCrack\.agents\teamwork\worker_m1_rep\handoff.md`
Send completion message to parent when done.
