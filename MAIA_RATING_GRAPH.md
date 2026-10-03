# MAIA "MOVES BY RATING" GRAPH SPECIFICATION
## Mathematical Formulation, Data Ingestion & Rendering Pipeline

---

### 1. Architectural Concept & Purpose

The **Moves by Rating** graph in ChessCrack visualizes human chess psychology across skill levels for a **single, fixed chess position** ($s = \text{FEN}$).

Unlike depth, time, nodes, or engine NPS charts, the graph plots:
- **X-Axis:** Rating Condition ($r \in [600, 2600]$ in steps of $100$, yielding $21$ discrete evaluation points).
- **Y-Axis:** Probability $P(\text{move} \mid s, r)$ formatted as a percentage $[0.0\%, 100.0\%]$.
- **Curves:** Top candidate moves showing how human likelihood evolves as skill level increases.

```
Probability (%)
100 ┌
    │
 60 │                      ╭─────── e4 (Master preference)
    │                  ╭───╯
 40 │              ╭───╯
    │  d4 ─────────╯────────────── d4 (Solid standard)
 20 │   \
    │    ╰─────── Bc4 (Beginner favorite, fades at 1800+)
  0 └───────────────────────────────────────────────────
     600  800  1000 1200 1400 1600 1800 2000 2200 2400 2600  (Rating)
```

---

### 2. Upstream Reference & Behavioral Parity

Based on research into the official Maia platform (`CSSLab/maia-platform-frontend`, specifically `MovesByRating.tsx`, `useEngineAnalysis.ts`, `useMoveRecommendations.ts`, and `maia.ts`):
1. **Inference Batching:** The official web client batches 21 requests of the same FEN with varying $(eloSelf, eloOpp)$ to a WebAssembly/ONNX Maia-3 model.
2. **Policy Logit Softmax:** Probabilities are derived from model output logits via softmax over legal moves:
   $$P(m \mid s, r) = \frac{e^{z_m(s, r)}}{\sum_{k \in \text{Legal}(s)} e^{z_k(s, r)}}$$
3. **Candidate Move Selection:** Lines on the graph are not drawn for all legal moves (which would clutter the display). Instead, a unified candidate set is constructed:
   - Top 3 moves from the active/selected rating.
   - Top 3 moves from Stockfish objective evaluation.
   - Peak move from each rating tier across the 21 points.
   - Deduplicated and capped to the top 4–6 salient moves.
4. **Color Mapping:** Line colors are mapped semantically using Stockfish move evaluation categories (e.g., Best Move = Cyan/Teal, Good/Solid = Amber/Green, Dubious/Inaccuracy = Orange/Rose) or distinct palette hues for visual clarity.

---

### 3. ChessCrack Implementation Details

#### A. Model Architecture: `MaiaRatingSweep` and `RatingMoveProbability`
Located in `lib/models/maia_rating_sweep.dart`:
- `MaiaRatingPoint`: Holds `rating` ($600 \le r \le 2600$) and `moveProbabilities` (`Map<String, double>`).
- `MaiaRatingSweep`: Encapsulates the complete 21-point evaluation dataset for a given FEN. Provides:
  - `candidateMoves`: Salient moves for graphing.
  - `getCurve(String uciMove)`: Ordered list of $(x, y)$ coordinates across all ratings.
  - `probabilityAt(String uciMove, int rating)`: Interpolated or exact probability.
  - `peakRating(String uciMove)`: Rating at which a move achieves maximum human popularity.

#### B. Canvas Rendering: `MovesByRatingChart`
Located in `lib/ui/widgets/moves_by_rating_chart.dart`:
- **Monotonic Cubic Curves:** Uses smooth Bézier curves (`Path.cubicTo`) between rating data points to avoid erratic oscillations.
- **Translucent Area Fill:** Renders an underlying gradient/semi-transparent area below curves for depth and legibility.
- **Vertical Clamping & Collision Prevention:** Endpoint labels are strictly clamped within canvas boundaries (`topPad + 4` to `topPad + chartH - 4`) with collision relaxation to ensure SAN text never clips or overlaps.
- **Responsive Layout:** Header title and controls utilize `Flexible` and `TextOverflow.ellipsis` to prevent `RenderFlex` overflows on small viewports (e.g., 360dp screens).

#### C. Interactive Features & Board Synchronization
- **Interactive Scrubber / Touch Tooltip:**
  - Touching or dragging across the chart displays a vertical guide line at the nearest rating point ($600, 700, \dots, 2600$).
  - An inspection card appears displaying the exact rating and candidate move breakdown:
    $$\text{SAN Move}: XX.X\%$$
- **Curve Selection & Move Highlighting:**
  - Tapping a move chip or curve highlights that move in high contrast.
  - Simultaneously dispatches `onHighlightMove(uciMove)` to the analysis controller.
  - **Draft Variation Projection:** Mounts a non-destructive draft preview arrow/piece onto the main chessboard, allowing instant visual exploration of the move.

---

### 4. Zero-Faking Policy & Engine Isolation

1. **Explicit Architecture Separation:**
   - **Lc0 Discrete Networks (`maia-1100.pb.gz` .. `maia-1900.pb.gz`):** Used strictly for fixed-rating sparring and single-point policy evaluation.
   - **Unified Skill-Conditioned Model:** Used for the 21-point rating sweep.
2. **Graceful Fallback:** If unified rating sweep inference is pending or unavailable, ChessCrack displays a clean loading or configuration state rather than synthesizing artificial numbers.
3. **Background Worker Execution:** Engine evaluations are conducted in asynchronous isolates and background processes, ensuring 60fps UI rendering and responsive piece drag-and-drop.
