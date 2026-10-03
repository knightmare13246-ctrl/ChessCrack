# CHESSCRACK: Personal Offline Chess Analysis Laboratory
## Product Vision & Technical Architecture Specification

---

### 1. Executive Summary & Philosophy

**ChessCrack** is a personal, offline-first chess analysis laboratory designed for deep positional inquiry, human behavioral comparison, and sovereign engine operation.

Unlike conventional chess GUIs that treat analysis as a single-number output (`+0.42, 1. e4`) or tether the user to cloud servers and paid subscriptions, ChessCrack delivers:

1. **Objective Chess Truth:** High-performance, offline calculation powered by Stockfish (with Multi-PV evaluation, PV lines, exact engine telemetry, and tactical threat detection).
2. **Human Chess Behavior:** Neural policy evaluation powered by Maia Chess (discrete rating-band sparring models and unified skill-conditioned distributions), predicting what human players of different rating tiers will actually play.
3. **Visual Position Exploration:** Nibbler-style multi-arrow visualization, interactive draft variation previews, interactive policy heatmaps, and dynamic moves-by-rating curves.
4. **Sovereign Engine Control:** Zero cloud tethering. Binaries (Stockfish, Lc0) and neural networks (Maia weights) run locally on device hardware, supporting custom binary linking, tunable threads/hash, and offline asset management.

---

### 2. Dual-Engine Architecture: Objective vs. Behavioral

ChessCrack orchestrates two distinct analysis engines concurrently or independently:

| Dimension | Stockfish (Objective Engine) | Maia / Lc0 (Behavioral Engine) |
| :--- | :--- | :--- |
| **Primary Question** | *"What is the mathematically optimal move?"* | *"What will humans at rating $R$ actually play?"* |
| **Core Technology** | Alpha-beta tree search, NNUE evaluation | Neural policy head ($P(\text{move} \mid s)$) via Lc0 engine |
| **Search Depth** | Deep lookahead (15–35+ plies) | Low/single-ply policy evaluation (`nodes 1`) |
| **Output Metrics** | Centipawn score / Mate in $N$, MultiPV lines, NPS, Nodes | Move probability distribution (0–100%), Win/Draw/Loss expectation |
| **Arrow Representation** | Color-coded by score differential ($\Delta$ cp from best) | Color-coded by human move likelihood or rating bracket |
| **Psychological Value** | Prevents blunders, spots tactical refutations | Reveals psychological traps, natural candidate moves, and rating transitions |

---

### 3. The Maia Human Behavior System

ChessCrack supports two complementary Maia paradigms:

#### A. Discrete Sparring Networks (Maia 1100–1900+)
- Evaluated via local Lc0 binary using dedicated `.pb.gz` network weights trained on Lichess rating bands.
- Serves as an interactive sparring partner or fixed-skill sparring coach.
- Emulates the typical move selection and blind spots of specific rating tiers.

#### B. Moves by Rating (Skill-Conditioned Rating Sweep)
- Evaluates the current board state across a 21-point Elo spectrum: **600 to 2600 in steps of 100**.
- Plots $P(\text{move} \mid \text{position}, \text{rating})$ on an interactive Cartesian area chart.
- Answers: *"At what skill level does a human stop playing the natural mistake and start playing the positional master move?"*
- Candidate moves are aggregated across top Maia moves at selected rating, top Stockfish moves, and top rating peaks.

---

### 4. Non-Destructive Interactive Exploration: Draft Variations

- **Ghost Variations:** Tapping any candidate arrow, engine PV line, or Moves-by-Rating curve activates a non-destructive **Draft Variation**.
- **Visual Distinction:** Draft moves are projected onto the board with visual ghost cues (e.g., semi-transparent pieces, directional breadcrumb arrows).
- **Zero Tree Corruption:** Exploring a draft variation never modifies the user's master PGN game tree unless the user explicitly taps **Commit Move**. Deselecting or tapping elsewhere instantly restores the active position.

---

### 5. Offline Autonomy & Device Sovereignty

- **Complete Local Execution:** All engine UCI protocols communicate through local stdio pipelines.
- **Robust Crash Isolation:** Engine crashes or process terminations are isolated in background services; the UI remains responsive, reporting failure states gracefully.
- **Asset Integrity:** Downloadable engine binaries and neural nets are verified via SHA-256 checksums, with granular download pause/resume, cancel, and disk storage tracking.
- **Persistent Preferences:** User settings (board themes, piece sets, MultiPV count, CPU threads, Hash size, arrow opacity, sound effects) persist locally via secure JSON storage.
