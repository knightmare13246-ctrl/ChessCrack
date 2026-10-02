## 2026-10-01T18:06:46Z

You are Explorer 1 for ChessCrack.
Your Working Directory is: O:\ChessCrack\.agents\teamwork\explorer_survey_1_gen2
Read O:\ChessCrack\.agents\teamwork\ORIGINAL_REQUEST.md before beginning.

MISSION:
Investigate Requirement R1 & Directive Focus 9:
Nibbler-Standard Candidate Arrows, Castling/Promotion, Ordering & Badges.

SPECIFIC OBJECTIVES:
1. Locate and inspect all arrow rendering, coordinate mapping, and candidate arrow models (e.g. `CandidateArrow`, custom painters, board overlays in `lib/`).
2. Arrowhead display modes: Winrate %, Expected Score, Policy % (for Lc0/Maia), MultiPV Rank (#1, #2, #3), Node %, and C-Scale. How are they configured, calculated, and rendered?
3. Arrow filtering: Support both Lc0/Maia arrow filtering rules (by policy threshold, visit count, or score delta) and conventional engine arrow filters. Where is filtering applied?
4. Nibbler visual layering: Longer arrow shafts strictly underneath shorter shafts; Rank 1 on top; high-contrast rank borders; collision-resolved badge offsets.
5. Accurate move mapping: Verify source and target square coordinates for all move types, including castling (e.g. King e1->g1 / e1->c1 or e8->g8 / e8->c8 — check whether arrows point to king or rook and if there is any mismatch with square offsets) and pawn promotions.
6. Settings persistence: How arrow appearance and mode preferences are stored and loaded in user settings.

OUTPUT:
Write your structured findings to:
O:\ChessCrack\.agents\teamwork\explorer_survey_1_gen2\handoff.md
Follow the standard Handoff format: Observation, Logic Chain, Caveats, Conclusion & Actionable Design, Verification Method.
Send a completion message back to parent when done.
