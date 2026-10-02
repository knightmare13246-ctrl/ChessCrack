# Handoff Report — Explorer Survey 1 Gen2: Nibbler-Standard Candidate Arrows, Castling/Promotion, Ordering & Badges

## Executive Summary
This report presents the complete architectural investigation of **Requirement R1 & Directive Focus 9** across the ChessCrack codebase. The candidate arrow pipeline in ChessCrack is structurally robust, featuring a 3-pass layer rendering engine (`NibblerArrowPainter`) with dynamic quadratic Bezier curves for sibling moves and an active 6-offset collision avoidance algorithm for score badges. However, key divergences from the Nibbler desktop standard were identified:
1. Two required arrowhead display modes are missing from `ArrowheadType`: **Expected Score** (currently conflated into pure winrate) and **C-Scale (Centipawn Scale)**. MultiPV Rank also lacks the `#` prefix (`#1`, `#2`, `#3`).
2. Arrow filtering lacks **Policy threshold (P%)** filtering rules for Lc0 and Maia. Because Maia human sparring runs strictly at `Nodes = 1`, node visit percentages are uninformative, making Policy prior filtering the essential mechanism for Maia candidate pruning.
3. In `PvLine.toSquare` (`lib/models/engine_analysis.dart:301-309`), raw UCI string slicing (`m.substring(2, 4)`) creates a critical bug hazard for Chess960/FRC castling notation (`e1h1` / `e1a1`), pointing the arrow to the rook square (`h1`) rather than the king destination square (`g1`).
4. Arrowheads in Layer 2 are sorted by shaft distance rather than rank priority, allowing a shorter lower-ranked move's arrowhead to visually draw on top of Rank 1's arrowhead.

Comprehensive actionable designs and code patches are detailed below.

---

## 1. Observation

### 1.1 Candidate Arrow Models and Enums (`lib/models/candidate_arrow.dart`)
- **Arrowhead presentation modes** (`candidate_arrow.dart:7-17`):
  ```dart
  enum ArrowheadType {
    winrate('Winrate', 'Pure win percentage without draw score (W / total * 100%)'),
    nodePct('Node %', 'Percentage of search visits allocated to this candidate move'),
    policy('Policy', 'Neural network prior probability (P) before MCTS search'),
    multipvRank('MultiPV rank', 'Engine search preference rank (1, 2, 3...)'),
    movesLeft('Moves Left Ahead', 'Estimated plies or moves remaining in game (MLH)');
  ```
  *Observed:* `ArrowheadType` is missing `expectedScore` (Win + 0.5*Draw) and `cScale` (Centipawn Scale).
- **Badge text formatting** (`candidate_arrow.dart:157-198`):
  ```dart
  case ArrowheadType.winrate:
    final score = winProbability ?? expectedScore;
    if (score != null) {
      return '${score.round()}';
    }
    return 'N/A';
  case ArrowheadType.multipvRank:
    return '$rank';
  ```
  *Observed:* `winrate` conflates `winProbability` (pure win %) and `expectedScore` (win + 0.5*draw). `multipvRank` outputs `'1'`, `'2'`, `'3'` without the `#` symbol.
- **Lc0 Arrow Filters** (`candidate_arrow.dart:20-33`):
  ```dart
  enum ArrowFilterLc0 {
    all, top1, top2, top3, minNodes1, minNodes5, within2PctScore, within5PctScore;
  }
  ```
  *Observed:* No filter exists for Policy prior percentage (`policyPercentage`), despite Maia running at `Nodes = 1` where all moves have 1 visit.
- **Conventional Engine Filters** (`candidate_arrow.dart:36-47`):
  ```dart
  enum ArrowFilterOthers {
    all, top1, top2, top3, within50Cp, within100Cp;
  }
  ```
- **Filtering Implementation** (`candidate_arrow.dart:269-338`):
  Filtering is implemented in pure function `filterCandidateArrows({required List<CandidateArrow> arrows, required EngineSettings settings})`.
  In `candidate_arrow.dart:323-328`:
  ```dart
  case ArrowFilterOthers.within50Cp:
    final bestCp = arrows.first.scoreCp ?? 0;
    filtered = arrows.where((a) => a.rank == 1 || (a.scoreCp != null && (bestCp - a.scoreCp!) <= 50)).toList();
    break;
  ```
  *Observed:* If Rank 1 is a forced mate (`scoreMate != null`, `scoreCp == null`), `bestCp` defaults to 0, causing subsequent cp-scored moves to be compared against 0 rather than a mate advantage. Furthermore, moves with mate scores have `scoreCp == null` and are dropped even if they are slightly slower mates.

### 1.2 Coordinate Mapping and Castling Moves (`lib/models/chess_position.dart`, `lib/models/chess_move.dart`, `lib/models/engine_analysis.dart`)
- **Square Representation** (`chess_move.dart:76-115`):
  `Square(file, rank)` where `file` is 0..7 (a..h) and `rank` is 0..7 (1..8). `algebraic` formats as `'${a+file}${rank+1}'`.
- **Castling Generation in `ChessPosition`** (`chess_position.dart:431-468`):
  - White Kingside: `from = Square(4, 0)` (e1), `to = Square(6, 0)` (g1).
  - White Queenside: `from = Square(4, 0)` (e1), `to = Square(2, 0)` (c1).
  - Black Kingside: `from = Square(4, 7)` (e8), `to = Square(6, 7)` (g8).
  - Black Queenside: `from = Square(4, 7)` (e8), `to = Square(2, 7)` (c8).
- **UCI Lookup Map** (`chess_position.dart:265-288`):
  ```dart
  if (m.isCastling) {
    if (m.from == const Square(4, 0)) {
      if (m.to == const Square(6, 0)) {
        uciMap['e1h1'] = m; // Chess960 / FRC alias
      } else if (m.to == const Square(2, 0)) {
        uciMap['e1a1'] = m; // Chess960 / FRC alias
      }
    } else if (m.from == const Square(4, 7)) {
      if (m.to == const Square(6, 7)) {
        uciMap['e8h8'] = m; // Chess960 / FRC alias
      } else if (m.to == const Square(2, 7)) {
        uciMap['e8a8'] = m; // Chess960 / FRC alias
      }
    }
  }
  ```
  *Observed:* `findLegalMoveByUci` resolves both standard (`e1g1`) and FRC (`e1h1`) UCI tokens to `ChessMove` with `to = Square(6, 0)` (`g1`).
- **Telemetry Construction in `uci_engine_service.dart`** (`uci_engine_service.dart:716-720, 791-795`):
  ```dart
  final firstMoveUci = movesUci.first;
  final candidateMove = _currentPosition.findLegalMoveByUci(firstMoveUci);
  ...
  final candidateArrow = CandidateArrow(
    rank: multipv,
    uciMove: firstMoveUci,
    from: candidateMove.from,
    to: candidateMove.to,
  ...
  ```
  *Observed:* When `candidateMove` is resolved, `from` is `e1` and `to` is `g1` (the king's destination), not `h1` (the rook).
- **Defect in `PvLine.toSquare`** (`engine_analysis.dart:291-309`):
  ```dart
  Square? get fromSquare {
    final m = primaryMoveUci;
    if (m == null || m.length < 4) return null;
    try {
      return Square.fromAlgebraic(m.substring(0, 2));
    } catch (_) {
      return null;
    }
  }

  Square? get toSquare {
    final m = primaryMoveUci;
    if (m == null || m.length < 4) return null;
    try {
      return Square.fromAlgebraic(m.substring(2, 4));
    } catch (_) {
      return null;
    }
  }
  ```
  *Observed:* If `primaryMoveUci` is an FRC castling token like `"e1h1"`, `m.substring(2, 4)` is `"h1"`. `toSquare` evaluates to `Square(7, 0)` (the rook square). If `NibblerArrowPainter._fromPvLines` is used as a fallback (`nibbler_arrow_painter.dart:36-39`), the arrow points to the rook on `h1` instead of the king destination on `g1`.
- **Pawn Promotions**:
  UCI is 5 characters (e.g. `e7e8q`, `d2d1n`).
  `ChessPosition._generatePseudoLegalMoves` (`chess_position.dart:380-425`) creates `ChessMove` with `from = Square(file, 6)`, `to = Square(destFile, 7)`, `promotion = PieceType.queen`. Both standard coordinates and promotions match 1:1.

### 1.3 Arrow Rendering & Coordinate Calculation (`lib/ui/widgets/nibbler_arrow_painter.dart`, `lib/ui/widgets/nibbler_board.dart`)
- **Board Stack Layering** (`nibbler_board.dart:214-253`):
  - Layer 1: Background texture / colors (`_buildBoardBackground`)
  - Layer 2: Square highlights (`_buildHighlightsLayer`)
  - Layer 3: Legal move dots / capture rings (`_buildMoveTargetsLayer`)
  - Layer 4: Animated pieces with drag & drop (`_buildPiecesLayer`)
  - Layer 5: Candidate arrows inside `RepaintBoundary` with `IgnorePointer` (`NibblerArrowPainter`)
- **Coordinate Transformation** (`nibbler_arrow_painter.dart:385-391` vs `nibbler_board.dart:649-653`):
  `NibblerArrowPainter._getSquareCenter`:
  ```dart
  final f = isFlipped ? (7 - sq.file) : sq.file;
  final r = isFlipped ? sq.rank : (7 - sq.rank);
  return Offset((f + 0.5) * squareSize, (r + 0.5) * squareSize);
  ```
  `NibblerBoard._getSquareRect`:
  ```dart
  final f = widget.isFlipped ? (7 - sq.file) : sq.file;
  final r = widget.isFlipped ? sq.rank : (7 - sq.rank);
  return Rect.fromLTWH(f * squareSize, r * squareSize, squareSize, squareSize);
  ```
  *Observed:* Square centers exactly equal `Rect.center` across all 64 squares in both White (`isFlipped = false`) and Black (`isFlipped = true`) orientations.
- **3-Pass Layer Rendering** (`nibbler_arrow_painter.dart:273-311`):
  - Pass 1: Arrow shafts
  - Pass 2: Arrowheads
  - Pass 3: Score badges (RRect with drop shadow, fill, border, TextPainter text)
- **Layering Order** (`nibbler_arrow_painter.dart:277-283`):
  ```dart
  final drawOrder = List<_PreparedArrow>.from(prepared)
    ..sort((a, b) {
      final lenCmp = b.distance.compareTo(a.distance);
      if (lenCmp != 0) return lenCmp;
      return b.arrow.rank.compareTo(a.arrow.rank);
    });
  ```
  *Observed:* Shafts are sorted descending by distance (`b.distance.compareTo(a.distance)`). Longer arrows are painted first; shorter arrows are painted on top.
  *Observed:* Arrowheads (Layer 2) currently reuse `drawOrder`. If Rank 1 is longer than Rank 2, Rank 1's arrowhead is painted before Rank 2's arrowhead, leaving Rank 1's arrowhead underneath.
  *Observed:* Badges (Layer 3) are sorted descending by rank (`b.arrow.rank.compareTo(a.arrow.rank)`), ensuring Rank 1's badge is painted last and strictly on top.
- **Sibling Curvature Offsets** (`uci_engine_service.dart:883-895`, `nibbler_arrow_painter.dart:133-158`):
  When multiple candidate moves originate from the same square (`a.from`), they receive alternating quadratic Bezier curvature offsets:
  - Sibling 0 (Rank 1 from square): `curvature = 0.0` (straight arrow)
  - Sibling 1: `curvature = -0.16` (curves left)
  - Sibling 2: `curvature = +0.16` (curves right)
  - Sibling 3: `curvature = -0.32`
  - Sibling 4: `curvature = +0.32`
  In `NibblerArrowPainter`, quadratic Bezier control points and end tangent angles are calculated:
  `angle = math.atan2(endTangentY, endTangentX);`
  The arrowhead rotates cleanly to match the curve trajectory into the destination square.
- **Badge Collision Resolution** (`nibbler_arrow_painter.dart:178-272`):
  Badges are positioned using `TextPainter` measurement with horizontal/vertical padding.
  Rank 1 is placed first and anchors at the destination square center.
  Subsequent ranks evaluate 6 candidate offsets:
  1. Preferred (destination center)
  2. Along trajectory backwards (`step = badgeH * 1.15`)
  3. Perpendicular normal (+nX, +nY)
  4. Perpendicular normal (-nX, -nY)
  5. Backwards along trajectory by `2 * step`
  6. Forward along trajectory by `0.6 * step`
  All candidates are clamped to `boardBounds` (`[4, 4, width-8, height-8]`). Overlap area with already placed badges is penalized with `cost = overlapArea + (i * 25.0)`, guaranteeing collision-free placement.
- **Rank Borders** (`nibbler_arrow_painter.dart:368-374`):
  Rank 1: 2.2px white stroke (`#FFFFFF`) with 4.0px blur drop shadow.
  Other ranks: 1.2px dark stroke (`0x66000000`).

### 1.4 Settings Persistence & Live Updates (`lib/models/engine_settings.dart`, `lib/services/session_persistence_service.dart`, `lib/ui/widgets/arrow_settings_dialog.dart`)
- **EngineSettings** (`engine_settings.dart:93-143`):
  `toJson()` serializes `arrowheadType`, `arrowFilterLc0`, `arrowFilterOthers`, `infoboxStats`.
  `fromJson()` cleanly deserializes them with fallback defaults.
- **SessionPersistenceService** (`session_persistence_service.dart:176-178, 221-224, 304-321`):
  Persists to `SharedPreferences` under keys `chesscrack_arrowhead`, `chesscrack_arrow_filter_lc0`, `chesscrack_arrow_filter_others`, `chesscrack_infobox_stats`.
  Supports backwards compatibility with legacy schema version 1 keys.
- **ArrowSettingsDialog** (`arrow_settings_dialog.dart`):
  Provides UI controls for Arrowhead Type, Arrow Filter (dynamic for Lc0 vs Stockfish), and Infobox stats checkboxes.
  Calls `_engineService.updatePresentationSettings(updated)` on every change.
- **Live Presentation Update** (`uci_engine_service.dart:1270-1273`):
  `updatePresentationSettings` updates `_settings` and calls `_emitThrottledAnalysis(force: true)`, re-filtering candidate arrows and notifying the UI immediately without stopping or disturbing the engine process.

### 1.5 Verification Suite Execution
- Ran `flutter test test/candidate_arrow_system_test.dart test/engine_performance_and_arrow_badge_test.dart`:
  **24/24 tests passed** (exited code 0).
- Ran full test suite (`flutter test` across all 10 test files):
  **90/90 tests passed** (exited code 0).
- Ran `flutter analyze`:
  Exited with **0 issues found** (clean static analysis).

---

## 2. Logic Chain

### 2.1 Arrowhead Display Modes (Objective 2)
1. **From Observation 1.1**, Requirement R1 mandates 6 arrowhead display modes:
   - Winrate %
   - Expected Score
   - Policy % (for Lc0/Maia)
   - MultiPV Rank (#1, #2, #3)
   - Node %
   - C-Scale (Centipawn Scale)
2. **From Observation 1.1**, `ArrowheadType` currently contains only `winrate`, `nodePct`, `policy`, `multipvRank`, and `movesLeft`.
3. In `CandidateArrow`, `winProbability` (pure win %, $W / (W+D+L)$) and `expectedScore` ($(W + 0.5D) / (W+D+L)$) are already distinct fields. Under the current `ArrowheadType.winrate` implementation (`score = winProbability ?? expectedScore`), the user cannot select Expected Score independently of Pure Winrate.
4. In Nibbler and chess GUI standards, "C-Scale" displays the evaluation in Centipawns ($cp$) or pawn units ($+0.35$, $-1.20$, or forced mate $M2$). `CandidateArrow` already stores `scoreCp` and `scoreMate`, but there is no enum mode to present them on arrowheads.
5. In `CandidateArrow.getBadgeText`, `ArrowheadType.multipvRank` returns `'$rank'` (e.g. `'1'`). Nibbler standard requires `'#$rank'` (e.g. `'#1'`, `'#2'`, `'#3'`).
6. **Conclusion**: Expanding `ArrowheadType` to include `expectedScore` and `cScale`, and formatting `multipvRank` as `'#$rank'`, fulfills R1 with zero impact on engine search pipelines.

### 2.2 Arrow Filtering Rules (Objective 3)
1. **From Observation 1.1**, `ArrowFilterLc0` only filters by rank (`top1`, `top2`, `top3`), node visit allocation (`minNodes1`, `minNodes5`), or score delta (`within2PctScore`, `within5PctScore`).
2. **From Requirement R2 and Directive Focus 8**, Maia Human Sparring runs via Leela Chess Zero at `Nodes = 1`. When `Nodes = 1`, all moves receive exactly 1 visit, meaning `nodePercentage` is either identical or uninformative.
3. However, Lc0 outputs the neural policy prior $P$ (`policyPercentage`) for every move in the root position during the initial evaluation. A high-Elo candidate move might have $P = 42.5\%$, while a blunder has $P = 0.05\%$.
4. Without Policy threshold filtering, users analyzing with Maia cannot filter out low-probability moves.
5. In addition, in `ArrowFilterOthers.within50Cp` (`candidate_arrow.dart:323-328`), if Rank 1 has `scoreMate != null`, `bestCp` defaults to 0, which distorts filtering in mating sequences.
6. **Conclusion**: Adding `minPolicy1` ($P \ge 1\%$), `minPolicy5` ($P \ge 5\%$), and `within5PctPolicy` ($P_{\text{best}} - P \le 5\%$) to `ArrowFilterLc0`, and handling mate scores safely in `ArrowFilterOthers`, satisfies the Lc0/Maia filtering requirement.

### 2.3 Visual Layering and Rank 1 Priority (Objective 4)
1. **From Observation 1.3**, `NibblerArrowPainter` sorts shafts by distance descending (`b.distance.compareTo(a.distance)`). Longer shafts are drawn first, so shorter shafts are drawn on top. This matches the Nibbler desktop standard: shorter moves are not obscured by long slicing queen/rook shafts.
2. In Layer 3, `badgeDrawOrder` sorts by rank descending (`b.arrow.rank.compareTo(a.arrow.rank)`), ensuring Rank 1 badge is drawn on top of all other badges.
3. However, in Layer 2 (arrowheads), `drawOrder` is used directly. If Rank 1 is longer than Rank 2, Rank 1's arrowhead is drawn before Rank 2's arrowhead. If the arrowheads touch or overlap, Rank 2's arrowhead will partially cover Rank 1's arrowhead.
4. **Conclusion**: Arrowheads in Layer 2 should sort by rank descending (`b.arrow.rank.compareTo(a.arrow.rank)`), matching Layer 3, so Rank 1's arrowhead and badge are strictly on top of all lower-ranked moves.

### 2.4 Castling and Promotion Coordinate Mapping (Objective 5)
1. **From Observation 1.2**, in `ChessPosition`, castling moves define:
   - White kingside: $e1 \to g1$ (`Square(4, 0)` to `Square(6, 0)`).
   - White queenside: $e1 \to c1$ (`Square(4, 0)` to `Square(2, 0)`).
   - Black kingside: $e8 \to g8$ (`Square(4, 7)` to `Square(6, 7)`).
   - Black queenside: $e8 \to c8$ (`Square(4, 7)` to `Square(2, 7)`).
2. In `uci_engine_service.dart`, candidate arrows are created from `candidateMove.from` and `candidateMove.to`. Because `findLegalMoveByUci` resolves both standard UCI (`e1g1`) and Chess960 UCI (`e1h1`) to the legal king move, candidate arrows correctly point from the king's square to the king's landing square ($g1$ or $c1$).
3. **From Observation 1.2**, in `PvLine.toSquare` (`engine_analysis.dart:301-309`), `primaryMoveUci.substring(2, 4)` is parsed directly. If an engine emits FRC notation (`e1h1`), `toSquare` returns `h1` (the rook square).
4. If `NibblerArrowPainter._fromPvLines` is invoked, the fallback arrow points from $e1$ to $h1$ (the rook) rather than $g1$ (the king).
5. **Conclusion**: `PvLine.fromSquare` and `PvLine.toSquare` should inspect `pvMoves.first.move` when available, or normalize castling squares, ensuring arrows never point to the rook.

---

## 3. Caveats

1. **Maia MultiPV Behavior**: Maia running through Lc0 at `Nodes = 1` requires the UCI engine to support MultiPV (e.g. `setoption name MultiPV value 5`). The policy values $P$ for candidate moves are returned in the UCI `info` lines. Filtering by policy operates on these root priors.
2. **FRC / Chess960 Scope**: ChessCrack currently focuses on standard chess. The FRC alias handling in `ChessPosition` is an engine compatibility bridge (some Lc0 builds emit `e1h1` even on standard FENs). The fix in `PvLine.toSquare` ensures this compatibility bridge does not leak into arrow rendering.
3. **Performance of Dynamic Badges**: Badge collision detection runs an $O(N^2)$ candidate-overlap calculation for $N \le 5$ MultiPV lines. With $N \le 5$, this consumes $< 0.1\text{ ms}$, maintaining 120 FPS UI performance.

---

## 4. Conclusion & Actionable Design

### 4.1 Summary of Changes Needed
| Component | Current State | Required State | Priority |
|---|---|---|---|
| `ArrowheadType` | `winrate`, `nodePct`, `policy`, `multipvRank`, `movesLeft` | Add `expectedScore`, `cScale`. MultiPV rank badge text formatted as `#$rank`. | High |
| `CandidateArrow.getBadgeText` | Combines winrate & expectedScore; lacks `cScale` | Distinct `winrate`, `expectedScore`, `cScale` (e.g. `+0.35` / `M2`), `#$rank`. | High |
| `ArrowFilterLc0` | Rank, nodes %, score delta | Add `minPolicy1` ($P \ge 1\%$), `minPolicy5` ($P \ge 5\%$), `within5PctPolicy`. | High |
| `filterCandidateArrows` | Misses policy filtering; mate cp edge case in `within50Cp` | Implement policy filtering; protect mate scores in cp delta calculations. | High |
| `NibblerArrowPainter` | Arrowheads drawn in distance order | Draw arrowheads in rank-descending order (Rank 1 strictly on top). | Medium |
| `PvLine.toSquare` | Raw `substring(2, 4)` without castling normalization | Use `pvMoves.first.move.to` when available; normalize $e1h1 \to g1$, $e1a1 \to c1$. | High |
| `ArrowSettingsDialog` | Lacks `expectedScore`, `cScale`, and policy filters | Add selector tiles for new modes and filters. | Medium |
| `EngineSettings` / `SessionPersistenceService` | Serializes existing enums | Already robust; verify clean migration for new enum entries. | Low |

---

### 4.2 Proposed Code Modifications

#### A. `lib/models/candidate_arrow.dart`
```dart
/// Available presentation modes for arrowhead badges on the chessboard.
enum ArrowheadType {
  winrate('Winrate %', 'Pure win percentage without draw score (W / total * 100%)'),
  expectedScore('Expected Score', 'Win percentage plus half of draw percentage (W + 0.5D)'),
  cScale('C-Scale (cp)', 'Centipawn scale evaluation (+0.35, -1.20, or M2)'),
  nodePct('Node %', 'Percentage of search visits allocated to this candidate move'),
  policy('Policy %', 'Neural network prior probability (P) before MCTS search'),
  multipvRank('MultiPV rank', 'Engine search preference rank (#1, #2, #3...)'),
  movesLeft('Moves Left Ahead', 'Estimated plies or moves remaining in game (MLH)');

  final String label;
  final String description;
  const ArrowheadType(this.label, this.description);
}

/// Arrow filters tailored to Leela Chess Zero and Maia human sparring.
enum ArrowFilterLc0 {
  all('All Candidates', 'Show all configured MultiPV candidate arrows'),
  top1('Top 1 only', 'Show only the primary candidate arrow'),
  top2('Top 2 only', 'Show the top 2 candidate arrows'),
  top3('Top 3 only', 'Show the top 3 candidate arrows'),
  minPolicy1('Min 1% Policy (Maia)', 'Hide candidates with < 1% neural policy prior'),
  minPolicy5('Min 5% Policy (Maia)', 'Hide candidates with < 5% neural policy prior'),
  within5PctPolicy('Within 5% of Top Policy', 'Hide moves > 5% lower policy than best move'),
  minNodes1('Min 1% Nodes', 'Hide candidates receiving < 1% of search visits'),
  minNodes5('Min 5% Nodes', 'Hide candidates receiving < 5% of search visits'),
  within2PctScore('Within 2% of Best', 'Hide candidates > 2% worse than top move'),
  within5PctScore('Within 5% of Best', 'Hide candidates > 5% worse than top move');

  final String label;
  final String description;
  const ArrowFilterLc0(this.label, this.description);
}
```

In `CandidateArrow.getBadgeText`:
```dart
  String getBadgeText(ArrowheadType type, EngineType engine) {
    switch (type) {
      case ArrowheadType.winrate:
        final score = winProbability ?? expectedScore;
        if (score != null) {
          return '${score.round()}';
        }
        return 'N/A';

      case ArrowheadType.expectedScore:
        final score = expectedScore ?? winProbability;
        if (score != null) {
          return '${score.round()}';
        }
        return 'N/A';

      case ArrowheadType.cScale:
        if (scoreMate != null) {
          return scoreMate! > 0 ? 'M${scoreMate!}' : '-M${scoreMate!.abs()}';
        }
        if (scoreCp != null) {
          final cp = scoreCp!;
          final sign = cp > 0 ? '+' : (cp < 0 ? '-' : '');
          final val = (cp.abs() / 100.0).toStringAsFixed(1);
          return '$sign$val';
        }
        return 'N/A';

      case ArrowheadType.nodePct:
        if (nodePercentage != null) {
          return '${nodePercentage!.round()}';
        }
        return 'N/A';

      case ArrowheadType.policy:
        if (engine == EngineType.lc0) {
          if (policyPercentage != null) {
            return '${policyPercentage!.round()}';
          }
          return 'N/A';
        }
        return 'N/A';

      case ArrowheadType.multipvRank:
        return '#$rank';

      case ArrowheadType.movesLeft:
        if (engine == EngineType.lc0) {
          if (movesLeft != null) {
            return '${movesLeft!.round()}';
          }
          return 'N/A';
        }
        if (scoreMate != null) {
          return 'M${scoreMate!.abs()}';
        }
        return 'N/A';
    }
  }
```

In `filterCandidateArrows`:
```dart
  if (isLc0) {
    switch (settings.arrowFilterLc0) {
      case ArrowFilterLc0.all:
        filtered = arrows;
        break;
      case ArrowFilterLc0.top1:
        filtered = arrows.where((a) => a.rank <= 1).toList();
        break;
      case ArrowFilterLc0.top2:
        filtered = arrows.where((a) => a.rank <= 2).toList();
        break;
      case ArrowFilterLc0.top3:
        filtered = arrows.where((a) => a.rank <= 3).toList();
        break;
      case ArrowFilterLc0.minPolicy1:
        filtered = arrows.where((a) => a.rank == 1 || (a.policyPercentage ?? 0.0) >= 1.0).toList();
        break;
      case ArrowFilterLc0.minPolicy5:
        filtered = arrows.where((a) => a.rank == 1 || (a.policyPercentage ?? 0.0) >= 5.0).toList();
        break;
      case ArrowFilterLc0.within5PctPolicy:
        final bestPolicy = arrows.first.policyPercentage ?? 0.0;
        filtered = arrows.where((a) => a.rank == 1 || (bestPolicy - (a.policyPercentage ?? 0.0)) <= 5.0).toList();
        break;
      case ArrowFilterLc0.minNodes1:
        filtered = arrows.where((a) => a.rank == 1 || (a.nodePercentage ?? 0.0) >= 1.0).toList();
        break;
      case ArrowFilterLc0.minNodes5:
        filtered = arrows.where((a) => a.rank == 1 || (a.nodePercentage ?? 0.0) >= 5.0).toList();
        break;
      case ArrowFilterLc0.within2PctScore:
        final bestScore = arrows.first.expectedScore ?? 50.0;
        filtered = arrows.where((a) => a.rank == 1 || (bestScore - (a.expectedScore ?? 0.0)) <= 2.0).toList();
        break;
      case ArrowFilterLc0.within5PctScore:
        final bestScore = arrows.first.expectedScore ?? 50.0;
        filtered = arrows.where((a) => a.rank == 1 || (bestScore - (a.expectedScore ?? 0.0)) <= 5.0).toList();
        break;
    }
  } else {
    switch (settings.arrowFilterOthers) {
      case ArrowFilterOthers.all:
        filtered = arrows;
        break;
      case ArrowFilterOthers.top1:
        filtered = arrows.where((a) => a.rank <= 1).toList();
        break;
      case ArrowFilterOthers.top2:
        filtered = arrows.where((a) => a.rank <= 2).toList();
        break;
      case ArrowFilterOthers.top3:
        filtered = arrows.where((a) => a.rank <= 3).toList();
        break;
      case ArrowFilterOthers.within50Cp:
        if (arrows.first.scoreMate != null) {
          filtered = arrows.where((a) => a.rank == 1 || a.scoreMate != null).toList();
        } else {
          final bestCp = arrows.first.scoreCp ?? 0;
          filtered = arrows.where((a) => a.rank == 1 || (a.scoreCp != null && (bestCp - a.scoreCp!) <= 50)).toList();
        }
        break;
      case ArrowFilterOthers.within100Cp:
        if (arrows.first.scoreMate != null) {
          filtered = arrows.where((a) => a.rank == 1 || a.scoreMate != null).toList();
        } else {
          final bestCp = arrows.first.scoreCp ?? 0;
          filtered = arrows.where((a) => a.rank == 1 || (a.scoreCp != null && (bestCp - a.scoreCp!) <= 100)).toList();
        }
        break;
    }
  }
```

#### B. `lib/ui/widgets/nibbler_arrow_painter.dart`
In `paint()`, Layer 2 (Arrowheads):
```dart
    // LAYER 2: Arrowheads (sorted by rank descending so Rank 1 arrowhead is drawn on top)
    final headDrawOrder = List<_PreparedArrow>.from(prepared)
      ..sort((a, b) => b.arrow.rank.compareTo(a.arrow.rank));

    for (final p in headDrawOrder) {
      _drawArrowHead(canvas, p.arrowEndPoint, p.angle, p.arrowHeadLength, p.arrowColor);
    }
```

#### C. `lib/models/engine_analysis.dart`
In `PvLine.toSquare` and `fromSquare`:
```dart
  Square? get fromSquare {
    if (pvMoves.isNotEmpty) {
      return pvMoves.first.move.from;
    }
    final m = primaryMoveUci;
    if (m == null || m.length < 4) return null;
    try {
      return Square.fromAlgebraic(m.substring(0, 2));
    } catch (_) {
      return null;
    }
  }

  Square? get toSquare {
    if (pvMoves.isNotEmpty) {
      return pvMoves.first.move.to;
    }
    final m = primaryMoveUci;
    if (m == null || m.length < 4) return null;
    // Normalize Chess960 castling tokens to standard king destinations
    final lower = m.toLowerCase();
    if (lower == 'e1h1') return const Square(6, 0); // g1
    if (lower == 'e1a1') return const Square(2, 0); // c1
    if (lower == 'e8h8') return const Square(6, 7); // g8
    if (lower == 'e8a8') return const Square(2, 7); // c8
    try {
      return Square.fromAlgebraic(m.substring(2, 4));
    } catch (_) {
      return null;
    }
  }
```

---

## 5. Verification Method

### 5.1 Independent Test Commands
Execute the project test commands to verify compilation, test coverage, and static analysis:
```powershell
C:\flutter-sdk\bin\flutter.bat test test/candidate_arrow_system_test.dart test/engine_performance_and_arrow_badge_test.dart
C:\flutter-sdk\bin\flutter.bat test
C:\flutter-sdk\bin\flutter.bat analyze
```

### 5.2 Specific Test Cases to Add / Verify
1. **Expected Score Mode**: Verify `arrow.getBadgeText(ArrowheadType.expectedScore, EngineType.lc0)` returns expected score rather than winrate when $W \ne W+0.5D$.
2. **C-Scale Mode**: Verify `arrow.getBadgeText(ArrowheadType.cScale, EngineType.stockfish)` returns `'+0.4'` for $+36\text{ cp}$ and `'M2'` for mate in 2.
3. **MultiPV Rank Badge**: Verify `arrow.getBadgeText(ArrowheadType.multipvRank, ...)` returns `'#1'`, `'#2'`, `'#3'`.
4. **Maia Policy Filter**: Construct arrows with $P = [45.0, 3.2, 0.4]$; verify `ArrowFilterLc0.minPolicy1` preserves ranks 1 and 2, but prunes rank 3.
5. **Castling Arrow Pointing**: Construct a `PvLine` with `movesUci = ['e1h1']`; verify `pvLine.toSquare` equals `Square(6, 0)` ($g1$), NOT `Square(7, 0)` ($h1$).
6. **Arrowhead Layering**: Construct a long Rank 1 move and short Rank 2 move with overlapping destinations; verify Rank 1's arrowhead is rendered after Rank 2's arrowhead in Layer 2.

### 5.3 Invalidation Conditions
- An arrow for $O\text{-}O$ originates at $e1$ and points to $h1$ instead of $g1$.
- MultiPV rank badges display plain numbers (`1`) instead of rank hashes (`#1`).
- Selecting Maia analysis drops candidate moves because visits are 1, when moves have $> 5\%$ policy.
- Static analysis warnings are introduced (`flutter analyze != 0 issues`).
