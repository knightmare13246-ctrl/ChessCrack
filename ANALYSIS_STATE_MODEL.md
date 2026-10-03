# ANALYSIS STATE MODEL & GAME TREE
## Data Structures, Reactive Pipelines, and Variation State

---

### 1. State Model Architecture

The ChessCrack state architecture is decoupled into three primary models:
1. **Game Tree Model (`GameTree`, `MoveNode`):** Represents the historical, branching PGN move structure.
2. **Engine Analysis State (`EngineAnalysisState`, `PvLine`):** Represents live, reactive engine output for the current board position.
3. **Draft Variation Model (`DraftVariation`):** Represents provisional, non-destructive exploratory move sequences.

```
┌────────────────────────────────────────────────────────┐
│                        GameTree                        │
│  - rootNode (Initial FEN)                              │
│  - currentNode (Active ply in tree)                    │
│  - branches: List<MoveNode> (Mainline & Subvariations) │
└───────────────────────────┬────────────────────────────┘
                            │
              FEN Update on Navigation
                            ▼
┌────────────────────────────────────────────────────────┐
│                  EngineAnalysisState                   │
│  - currentFen: String                                  │
│  - isAnalyzing: bool                                   │
│  - activeEngine: EngineType                            │
│  - lines: List<PvLine> (MultiPV sorted 1..N)           │
│  - depth: int, seldepth: int                           │
│  - totalNodes: int, nps: int                           │
│  - maiaRatingSweep: MaiaRatingSweep?                   │
└───────────────────────────┬────────────────────────────┘
                            │ User taps Move/PV Line/Curve
                            ▼
┌────────────────────────────────────────────────────────┐
│                     DraftVariation                     │
│  - rootPosition: Position (Snapshot at branch point)   │
│  - moves: List<PvMoveItem> (Provisional PV sequence)   │
│  - activeIndex: int (Cursor within provisional line)   │
│  - isCommitted: bool (Promoted to GameTree or Cleared) │
└────────────────────────────────────────────────────────┘
```

---

### 2. Core Data Entities

#### A. `PvLine` and `PvMoveItem`
Located in `lib/models/engine_analysis_state.dart`:
- `multipv`: Numerical rank ($1, 2, \dots, N$).
- `score`: Numeric centipawn evaluation or mate in $M$ value.
- `isMate`: Boolean flag indicating forced checkmate line.
- `depth`: Engine search depth.
- `pvMoves`: List of individual `PvMoveItem` instances containing UCI string (`e2e4`), SAN string (`e4`), piece type, source square, target square, and whether capture/check occurred.
- `formattedScore`: Clean presentation string (e.g. `+0.42`, `-1.15`, `#M3`).

#### B. `DraftVariation` Lifecycle
- **Mounting:** Triggered when the user taps a candidate arrow on the board, clicks a PV line in the engine panel, or selects a curve on the Moves by Rating graph.
- **Visual Feedback:** Pieces previewed along the draft line render with distinctive visual styling (ghosting/opacity) so the user never confuses exploratory lines with confirmed board moves.
- **Non-Destructive Guarantee:** Navigation or tapping elsewhere instantly discards the draft variation without generating orphan nodes in the PGN structure.
- **Commit Promotion:** The user can tap "Commit Line" to promote the exploratory sequence into a permanent branch in the `GameTree`.

#### C. `MaiaRatingSweep` and `RatingMoveProbability`
Located in `lib/models/maia_rating_sweep.dart`:
- Encapsulates the 21-point Elo distribution ($600 \dots 2600$).
- Directly binds to the `MovesByRatingChart` widget.
- Cleanly preserves candidate moves across rating updates.
