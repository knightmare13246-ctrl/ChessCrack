# Dispatch Task — Explorer Survey 3 (R3 Engine Lifecycle & R4 Test Infra)

- Working Directory: O:\ChessCrack\.agents\teamwork\explorer_survey_3
- Target Area: R3 Robust Engine & Network Management & R4 Test/Verification Architecture
- Path to Original Request: O:\ChessCrack\.agents\teamwork\ORIGINAL_REQUEST.md
- Orchestrator Conversation ID: 70045e72-c196-44cb-9257-32247d730728

## Mission:
Investigate the codebase for Engine Artifact Management (Downloading, Verifying, Storing, Deleting), Process Lifecycle Management, and Test Infrastructure.

Specific Areas to Investigate:
1. Engine & Network Artifact Management: Stockfish 19, Leela Chess Zero v0.32.1, and all 10 Maia Elo models (~1100 to ~1900). Download pipeline, checksum/hash verification, file storage paths on Android/local.
2. Deletion Robustness:
   - "DELETE" button implementation: Process termination, file deletion from app storage, real-time disk storage counter update, UI state revert.
   - Bundled read-only native libraries vs downloaded updates (how are native assets or bundled engines/weights handled without exceptions or corrupted tallies).
3. Process lifecycle: Zombie process prevention, file lock contention during deletion, restart loop prevention.
4. Testing infrastructure:
   - Existing unit, widget, and integration tests in `test/`.
   - `flutter analyze` configuration and current issues/warnings.
   - Test harness availability for mocking engines, simulating downloads/deletions, testing arrow rendering and telemetry states.

Output:
Write your structured findings to `O:\ChessCrack\.agents\teamwork\explorer_survey_3\handoff.md` following the standard handoff protocol (Observation, Logic Chain, Caveats, Conclusion, Verification Method).

## 2026-10-01T16:15:06Z
You are Explorer 3 (teamwork_preview_explorer).
Your assigned working directory is: O:\ChessCrack\.agents\teamwork\explorer_survey_3
Your parent orchestrator conversation ID is: 70045e72-c196-44cb-9257-32247d730728

Read your instructions in O:\ChessCrack\.agents\teamwork\explorer_survey_3\DISPATCH.md and the user request in O:\ChessCrack\.agents\teamwork\ORIGINAL_REQUEST.md.
Investigate R3: Robust Engine & Network Management (Downloading & Deleting) and R4: Test & Verification Infrastructure across the codebase.
- Locate engine artifact management (Stockfish 19, Lc0 v0.32.1, 10 Maia Elo models), download logic, hash verification, storage paths, deletion handlers, disk counter updates, read-only vs downloaded asset handling, process termination, zombie avoidance.
- Locate existing tests in test/, flutter analyze rules, current failures or test suite status.
- Update progress.md with liveness timestamps.
- When done, write a complete, structured report to O:\ChessCrack\.agents\teamwork\explorer_survey_3\handoff.md following the handoff protocol (Observation, Logic Chain, Caveats, Conclusion, Verification Method).
- Send a completion message via send_message to recipient 70045e72-c196-44cb-9257-32247d730728.

