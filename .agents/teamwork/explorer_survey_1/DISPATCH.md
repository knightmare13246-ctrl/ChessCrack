# Dispatch Task — Explorer Survey 1 (R1 Arrow & Visuals)

- Working Directory: O:\ChessCrack\.agents\teamwork\explorer_survey_1
- Target Area: R1 Complete Nibbler Arrow & Visual Configuration Overhaul
- Path to Original Request: O:\ChessCrack\.agents\teamwork\ORIGINAL_REQUEST.md
- Orchestrator Conversation ID: 70045e72-c196-44cb-9257-32247d730728

## Mission:
Investigate the codebase for all aspects of Arrow Visualization, Nibbler Arrow Settings, and Move Mapping.

Specific Areas to Investigate:
1. Current chess board and arrow rendering implementation (CustomPainter, Flutter widgets, overlays).
2. Arrowhead display modes: Winrate %, Expected Score, Policy % (for Lc0/Maia), MultiPV Rank (#1, #2, #3), Node %, and C-Scale.
3. Arrow filtering: Lc0/Maia filtering rules (policy threshold, visit count, score delta) and conventional engine arrow filters.
4. Nibbler visual layering: Longer arrow shafts strictly underneath shorter shafts; Rank 1 on top; high-contrast rank borders; collision-resolved badge offsets.
5. Accurate move mapping: Exact source and target squares for all moves, including castling.
6. Settings storage and user configuration persistence for arrow settings.

Output:
Write your structured findings to `O:\ChessCrack\.agents\teamwork\explorer_survey_1\handoff.md` following the standard handoff protocol (Observation, Logic Chain, Caveats, Conclusion, Verification Method).

## 2026-10-01T16:15:05Z
You are Explorer 1 (teamwork_preview_explorer).
Your assigned working directory is: O:\ChessCrack\.agents\teamwork\explorer_survey_1
Your parent orchestrator conversation ID is: 70045e72-c196-44cb-9257-32247d730728

Read your instructions in O:\ChessCrack\.agents\teamwork\explorer_survey_1\DISPATCH.md and the user request in O:\ChessCrack\.agents\teamwork\ORIGINAL_REQUEST.md.
Investigate R1: Complete Nibbler Arrow & Visual Configuration Overhaul across the codebase.
- Locate all board painters, arrow rendering, coordinate mapping, arrow display modes, arrow filtering, layering, castling arrow mapping, and settings storage.
- Update progress.md with liveness timestamps.
- When done, write a complete, structured report to O:\ChessCrack\.agents\teamwork\explorer_survey_1\handoff.md following the handoff protocol (Observation, Logic Chain, Caveats, Conclusion, Verification Method).
- Send a completion message via send_message to recipient 70045e72-c196-44cb-9257-32247d730728.

