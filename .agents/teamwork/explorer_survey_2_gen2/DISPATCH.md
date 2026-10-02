## 2026-10-01T18:06:46Z
You are Explorer 2 for ChessCrack.
Your Working Directory is: O:\ChessCrack\.agents\teamwork\explorer_survey_2_gen2
Read O:\ChessCrack\.agents\teamwork\ORIGINAL_REQUEST.md before beginning.

MISSION:
Investigate Requirement R2 & Directive Focus 1, 2, 3, 4, 5, 7:
Strict State Decoupling, Nullable Telemetry, Atomic Snapshots & Search State Machine.

SPECIFIC OBJECTIVES:
1. Strict State Decoupling: Analyze how `EngineInstallationState`, `EngineLifecycleState`, and `AnalysisDataState` (or `EngineSearchState`) should be strictly separated and represented across models and services.
2. Nullable Engine Telemetry: Investigate `nodes`, `nps`, `depth`, `selDepth`, `timeMs` across `PositionAnalysis`, `PvLine`, and UCI parsing. Identify where fake 0/1 defaults are injected and how to make them strictly nullable.
3. Atomic Analysis Snapshot & MultiPV Synchronization: How to ensure all MultiPV lines and candidate arrows belong to the same generation tuple `(positionRevision, analysisRequestId, engineSessionId)`.
4. Request ID + Position Revision Validation: Inspect how incoming UCI lines are routed and validated against the active request ID and position revision with zero bypasses.
5. Search State Machine & Thrashing Elimination: Investigate why UI rebuilds, theme changes, or tab changes might stop/restart search. Trace `_toggleLiveAnalysis`, `pauseAnalysis`, `resumeAnalysis`, and `disableEngine`.
6. Lc0 0.32.1 Real Telemetry & Missing Metric Handling: Ensure omitted NPS is displayed as `N/s: N/A` instead of 0.

OUTPUT:
Write your structured findings to:
O:\ChessCrack\.agents\teamwork\explorer_survey_2_gen2\handoff.md
Follow the standard Handoff format: Observation, Logic Chain, Caveats, Conclusion & Actionable Design, Verification Method.
Send a completion message back to parent when done.
