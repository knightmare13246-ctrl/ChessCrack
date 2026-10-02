# BRIEFING — 2026-10-01T16:16:00Z

## Mission
Investigate R2: Accurate Telemetry & Engine State Semantics across the codebase (UCI pipeline, Stockfish infinite analysis, Maia sparring metrics, telemetry parsing/formatting, engine state machine/UI sync).

## 🔒 My Identity
- Archetype: teamwork_preview_explorer
- Roles: [explorer, investigator]
- Working directory: O:\ChessCrack\.agents\teamwork\explorer_survey_2
- Original parent: 70045e72-c196-44cb-9257-32247d730728
- Milestone: Survey & Architecture Review (R2)

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Investigate R2: Accurate Telemetry & Engine State Semantics
- Write report to handoff.md following 5-component handoff protocol
- Keep progress.md updated with liveness heartbeat

## Current Parent
- Conversation ID: 70045e72-c196-44cb-9257-32247d730728
- Updated: 2026-10-01T16:22:00Z

## Investigation State
- **Explored paths**:
  - `lib/services/uci_engine_service.dart` (UCI command generation, continuous analysis, bestmove handling, telemetry parsing)
  - `lib/services/native_engine_runner.dart` (process binary resolution, permissions, ABI detection)
  - `lib/models/engine_analysis.dart` (EngineSearchState, EngineActivationState, PositionAnalysis, PvLine, EngineDiagnostics)
  - `lib/models/engine_settings.dart` (EngineSettings, Maia active detection, nodeLimit)
  - `lib/models/engine_download_model.dart` & `lib/services/engine_download_service.dart` (10 Maia Elo models, download & install lifecycle)
  - `lib/controllers/evaluation_controller.dart` (deadband stabilization, evaluation smoothing, neutral reset)
  - `lib/ui/screens/chess_analysis_screen.dart` (UI bindings, toggle live analysis vs pause, layout, tab controller)
  - `lib/ui/widgets/engine_analysis_panel.dart` (header text, Pause/Analyze button, line metrics, draft variation toolbar)
  - `lib/ui/widgets/engine_diagnostics_panel.dart` (detailed telemetry chips, UCI status, arrow pipeline diagnostics)
  - `lib/utils/score_adapters.dart` & `win_rate_calculator.dart` (Stockfish logistic vs Lc0 WDL evaluation adapters)
  - `test/` suite (ran `flutter test` and `flutter analyze` via `C:\flutter-sdk\bin\flutter.bat`, all 90 tests pass and 0 analysis errors)
- **Key findings**:
  - Stockfish continuous search operates via `go infinite`, but `seldepth` is parsed yet omitted from `formattedHeader`.
  - In Maia human sparring mode (`isMaiaActive`, Lc0 `go nodes 1`), the search finishes in ~10-50ms, triggering `_handleBestMove()`, which sets `_searchState = ready` and `_isAnalyzing = false`. This causes `PositionAnalysis.formattedHeader` to erroneously display `"Paused · Nodes: 1, N/s: —, Depth: 1"` (or `N/s: N/A`), misleadingly showing conventional tree search metrics instead of human sparring metrics (Elo level, move policy probability `P: XX.X%`, and evaluation).
  - The Pause/Analyze button in `EngineAnalysisPanel` is bound directly to `_toggleLiveAnalysis()`, which completely disables the engine (`disableEngine()`) and resets `_currentAnalysis = null`, wiping all candidate arrows, lines, and eval bar. True non-destructive pausing (`searching` -> `paused`) does not exist in the UI or service.
  - The state machine lacks explicit separation of 4 search states (`searching`, `paused`, `completed`, `ready`).
- **Unexplored areas**: None. All components in scope for R2 surveyed and analyzed.

## Key Decisions Made
- Identified exact architectural root causes for R2 requirements.
- Formulated clean design for `EngineSearchState` (`searching`, `paused`, `completed`, `ready`), dedicated `pauseAnalysis()` vs `resumeAnalysis()`, Maia human sparring header formatter, and UI button decoupling.

## Artifact Index
- O:\ChessCrack\.agents\teamwork\explorer_survey_2\DISPATCH.md — Task instructions
- O:\ChessCrack\.agents\teamwork\explorer_survey_2\progress.md — Liveness heartbeat and progress tracking
- O:\ChessCrack\.agents\teamwork\explorer_survey_2\handoff.md — Final investigation report

