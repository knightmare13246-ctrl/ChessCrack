# BRIEFING — 2026-10-01T18:27:30Z

## Mission
Investigate Requirement R3, R4 & Directive Focus 6, 8, 10: Engine Artifact Management, Stockfish 19 & Maia Architecture, Process Lifecycle & Android Build.

## 🔒 My Identity
- Archetype: explorer
- Roles: investigation, synthesis
- Working directory: O:\ChessCrack\.agents\teamwork\explorer_survey_3_gen2
- Original parent: ce73e06e-4106-412c-a798-2d9e95386e10
- Milestone: survey_3_gen2

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Produce 5-component handoff report (Observation, Logic Chain, Caveats, Conclusion, Verification Method) in O:\ChessCrack\.agents\teamwork\explorer_survey_3_gen2\handoff.md
- Report back to parent agent ce73e06e-4106-412c-a798-2d9e95386e10 using send_message

## Current Parent
- Conversation ID: ce73e06e-4106-412c-a798-2d9e95386e10
- Updated: not yet

## Investigation State
- **Explored paths**:
  - `lib/services/engine_download_service.dart`
  - `lib/services/native_engine_runner.dart`
  - `lib/services/uci_engine_service.dart`
  - `lib/models/engine_download_model.dart`
  - `lib/models/engine_analysis.dart`
  - `lib/models/engine_settings.dart`
  - `lib/ui/widgets/engine_manager_dialog.dart`
  - `lib/ui/screens/chess_analysis_screen.dart`
  - `android/app/build.gradle.kts`
  - `android/app/src/main/kotlin/org/chesscrack/app/MainActivity.kt`
  - `android/app/src/main/jniLibs/` (armeabi-v7a and arm64-v8a binaries)
  - `test/` (90 unit & widget tests)
  - Physical Android hardware: Samsung Galaxy M10 (SM-M105F, armeabi-v7a, Android 10 API 29) via ADB
- **Key findings**:
  1. `flutter analyze`: 0 issues found!
  2. `flutter test -j 1`: 100% pass (90/90 tests passed). Concurrency default on Windows causes socket timeout on some suites if run unbounded.
  3. Deletion bug: `onBeforeEngineRemoved` parameter in `EngineManagerDialog` is never passed by callers in `chess_analysis_screen.dart:555` or `engine_settings_dialog.dart:113`, causing running engine processes to remain active during deletion attempts, failing on Windows (file lock) and creating zombie processes on Android.
  4. Maia Telemetry Regression: `PositionAnalysis.formattedHeader` checks `engineName?.toLowerCase().contains('maia')`, but `engineName` is hardcoded to `_settings.activeEngine.displayName` (`'Lc0 (Leela)'`), which NEVER contains `'maia'`. Thus Maia always displayed `Nodes: 1, N/s: N/A, Depth: 1` or `Paused`!
  5. Lc0 Weight Dependency: `liblc0.so` lacks embedded weights. Running without `--weights` produces `error No embedded file detected.`. Selecting Lc0 requires an active Maia network or weights file.
  6. Live Hardware Verification: Stockfish 19 achieves 50k+ NPS on ARMv7 Galaxy M10. Maia 1100 completes root move policy evaluation in 23ms with 100% policy sum. Lc0 seamlessly hot-swaps weights via `setoption name WeightsFile` followed by `isready`.
- **Unexplored areas**: None within the scope of R3, R4 & Focus 6, 8, 10.

## Key Decisions Made
- Structured findings into five formal handoff sections with full code references, telemetry logs from physical device, and concrete actionable designs for Phase 2 implementers.

## Artifact Index
- O:\ChessCrack\.agents\teamwork\explorer_survey_3_gen2\DISPATCH.md — Incoming mission dispatch
- O:\ChessCrack\.agents\teamwork\explorer_survey_3_gen2\BRIEFING.md — Working memory
- O:\ChessCrack\.agents\teamwork\explorer_survey_3_gen2\progress.md — Liveness & progress tracker
- O:\ChessCrack\.agents\teamwork\explorer_survey_3_gen2\handoff.md — Final structured report
