# BRIEFING — 2026-10-01T18:28:00Z

## Mission
Investigate Requirement R1 & Directive Focus 9: Nibbler-Standard Candidate Arrows, Castling/Promotion, Ordering & Badges across ChessCrack.

## 🔒 My Identity
- Archetype: explorer
- Roles: investigator, synthesizer
- Working directory: O:\ChessCrack\.agents\teamwork\explorer_survey_1_gen2
- Original parent: ce73e06e-4106-412c-a798-2d9e95386e10
- Milestone: Explorer Survey Gen2

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Produce a structured 5-component handoff report (handoff.md)
- Follow Nibbler standards for arrow settings, filtering, layering, castling, and display modes

## Current Parent
- Conversation ID: ce73e06e-4106-412c-a798-2d9e95386e10
- Updated: 2026-10-01T18:28:00Z

## Investigation State
- **Explored paths**:
  - `lib/models/candidate_arrow.dart`
  - `lib/ui/widgets/nibbler_arrow_painter.dart`
  - `lib/ui/widgets/nibbler_board.dart`
  - `lib/ui/widgets/arrow_settings_dialog.dart`
  - `lib/models/engine_settings.dart`
  - `lib/models/engine_analysis.dart`
  - `lib/models/chess_position.dart`
  - `lib/models/chess_move.dart`
  - `lib/services/uci_engine_service.dart`
  - `lib/services/session_persistence_service.dart`
  - `lib/utils/score_adapters.dart`
  - `lib/utils/win_rate_calculator.dart`
  - `test/candidate_arrow_system_test.dart`
  - `test/engine_performance_and_arrow_badge_test.dart`
- **Key findings**:
  1. Arrow rendering architecture is a 3-pass layer system (Shafts -> Arrowheads -> Badges) in `NibblerArrowPainter`, cleanly separated inside an isolated `RepaintBoundary` on `NibblerBoard`.
  2. Arrowhead display modes currently support Winrate, Node %, Policy %, MultiPV Rank, Moves Left. Missing from R1 are explicit `expectedScore` and `cScale` (Centipawn Scale) modes, as well as `#$rank` prefixing.
  3. Arrow filtering is applied in `uci_engine_service.dart` using pure function `filterCandidateArrows()`. Supports MultiPV rank caps, Lc0 node %, Lc0 expected score delta, and Stockfish centipawn delta. Missing is Policy threshold filtering (critical for Maia's `Nodes = 1` human sparring mode).
  4. Visual layering follows length-based shaft ordering (longer underneath shorter) with quadratic Bezier curvature for sibling moves sharing an origin square. Rank 1 gets preferred destination center badge placement with high-contrast 2.2px white border and blur shadow.
  5. Coordinate mapping for standard and flipped board orientations is mathematically consistent between `NibblerBoard` and `NibblerArrowPainter`. Castling moves via `findLegalMoveByUci` map King e1->g1 and e1->c1 accurately. A critical bug hazard was identified in `PvLine.toSquare` which substrings raw UCI text without resolving Chess960/FRC castling notation (`e1h1` -> `h1`).
  6. Settings persistence stores and restores all preferences through `SessionPersistenceService` and `EngineSettings` JSON serialization.
- **Unexplored areas**: None within the scope of R1.

## Key Decisions Made
- Formulate comprehensive actionable design for implementer:
  - Add `expectedScore` and `cScale` to `ArrowheadType`.
  - Add policy threshold filters (`minPolicy1`, `minPolicy5`, `within5PctPolicy`) to `ArrowFilterLc0`.
  - Patch `PvLine.toSquare`/`fromSquare` to use `pvMoves.first.move` coordinates to eliminate FRC castling rook pointing risk.
  - Refine arrowhead rendering order to guarantee Rank 1 arrowhead priority.

## Artifact Index
- O:\ChessCrack\.agents\teamwork\explorer_survey_1_gen2\BRIEFING.md — persistent working memory
- O:\ChessCrack\.agents\teamwork\explorer_survey_1_gen2\progress.md — liveness heartbeat
- O:\ChessCrack\.agents\teamwork\explorer_survey_1_gen2\handoff.md — 5-component handoff report
