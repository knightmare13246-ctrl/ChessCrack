# ARROW RENDERING & CANDIDATE VISUALIZATION SYSTEM
## Geometric Computation, Color Semantics, and Interactive Hit-Testing

---

### 1. Visual Paradigm: Nibbler-Style MultiPV Arrows

ChessCrack implements a Nibbler-inspired multi-arrow visualization engine capable of rendering candidate moves directly onto the chessboard:
- **Relative Quality Scaling:** Arrows are prioritized and sized based on evaluation margin ($\Delta$ score compared to the best move) or policy probability.
- **Knight Move Geometry:** Knight paths render with curved, dogleg Bézier splines rather than straight diagonal lines, clarifying piece intent.
- **Non-Obtrusive Styling:** Arrow opacity, thickness, and badge placement are dynamically calculated to maintain clear visibility of board squares and pieces beneath.

---

### 2. Color Palettes and Semantic Categorization

Arrows are styled according to analysis mode and quality classification:

#### A. Stockfish Evaluation Delta Palette ($\Delta \text{cp}$)
- **Best Move ($\Delta = 0$):** Vibrant Cyan / Electric Teal (`#00E5FF`).
- **Excellent ($\Delta \le 25 \text{ cp}$):** Mint Green (`#00E676`).
- **Good / Playable ($\Delta \le 75 \text{ cp}$):** Amber / Gold (`#FFD600`).
- **Inaccuracy ($\Delta \le 150 \text{ cp}$):** Warm Orange (`#FF9100`).
- **Mistake / Blunder ($\Delta > 150 \text{ cp}$):** Crimson Red (`#FF1744`).

#### B. Maia Human Policy Palette
- High-probability human candidate moves scale from deep Indigo to bright Magenta/Violet, clearly distinguishing behavioral likelihood from objective engine evaluation.

---

### 3. Geometric Formulation & Badge Placement

Located in `lib/ui/widgets/board_overlay_painter.dart`:
- **Shaft Geometry:** Calculated using normal unit vectors perpendicular to the move vector $(dx, dy)$ to generate symmetrical polygons.
- **Head Geometry:** Equilateral or isosceles arrowheads with configurable setback angles to prevent clipping onto adjacent pieces.
- **MultiPV Badges:** Compact circular or rounded pill badges rendered near the destination square or midpoint showing:
  - MultiPV rank number ($1, 2, 3$).
  - Delta score or centipawn evaluation.
  - Maia move probability percentage ($XX\%$).
- **Anti-Overlap Offsetting:** When multiple arrows target the same square or cross identical vectors, subtle transverse offsets are applied to prevent visual collision.

---

### 4. Interactive Hit-Testing & Draft Variations

- Each arrow registers a polygon path for hit-testing in touch/mouse pointer events.
- Tapping an arrow selects the candidate line, highlights its corresponding row in the MultiPV list, and mounts a non-destructive **Draft Variation** preview on the board.
