# CHESSCRACK FEATURE INVENTORY
## Complete Capabilities, UI Components, and Engine Integrations

---

### 1. Board & Interactive Experience

- **High-Performance Chessboard:** Fluid drag-and-drop and tap-to-move piece interaction with legal move indicators and capture highlights.
- **Visual Customization:**
  - Multiple piece sets (e.g. Cburnett, Merida, Alpha, Maestro).
  - Multiple board themes (e.g. Wood, Blue, Slate, Emerald, Classic).
  - Coordinate overlays (ranks 1–8, files a–h) with adaptive font sizing.
- **Audio Feedback:** Authentic move, capture, check, and castling sound effects with local offline audio synthesis.
- **Board Orientation & Controls:** Instant board flipping, starting position reset, and FEN copying/pasting.

---

### 2. Objective Engine Analysis (Stockfish)

- **Local UCI Subprocess:** Direct execution of compiled Stockfish binaries (x86_64, ARMv7, ARM64) with zero cloud dependencies.
- **MultiPV Candidate Lines:** Configurable MultiPV (1 to 5+ simultaneous evaluation lines) displaying score, depth, seldepth, and principal variation (PV).
- **Nibbler-Style Evaluation Bar:** Smooth, responsive vertical evaluation bar calibrated with non-linear sigmoid scaling for intuitive advantage perception.
- **Authentic Telemetry:** Real-time metrics including comma-grouped node counts (`1,452,890`), true engine NPS (`1.4M N/s`), and depth counters with zero synthetic faking.
- **Engine Tuning:** Full user control over UCI parameters: CPU Threads, Hash Memory (MB), and MultiPV limits.

---

### 3. Human Behavioral Analysis (Maia Chess)

- **Discrete Sparring Networks:** Local evaluation of official Maia models (Maia 1100 through 1900+) via Leela Chess Zero (Lc0).
- **Moves by Rating Chart:**
  - 21-point Elo evaluation sweep ($600 \le \text{Rating} \le 2600$ in steps of 100).
  - Smooth monotonic Bézier curves representing candidate move probabilities ($0\% \dots 100\%$).
  - Clamped, collision-free endpoint labels showing move SANs.
  - Interactive touch scrubber and hover tooltip revealing move likelihood breakdowns at any rating.
- **Rating Transition Discovery:** Identifies peak skill ratings for candidate moves, showing where human blunders peak and where grandmaster techniques emerge.

---

### 4. Visual Exploration & Draft Variations

- **Nibbler Candidate Arrows:**
  - Color-coded arrows rendered directly on the board based on centipawn score differential ($\Delta$ cp) or Maia policy percentage.
  - Curvilinear Bézier dogleg geometry for knight moves.
  - Badges displaying rank and delta evaluation.
  - User-configurable arrow count, opacity, and threshold filters.
- **Draft Variations:**
  - Non-destructive variation previews activated by tapping arrows, PV lines, or rating curves.
  - Visual ghosting of previewed pieces and provisional move arrows.
  - One-tap "Commit Line" promotion to permanent PGN tree, or instantaneous cancellation upon deselecting.

---

### 5. Game Tree & PGN Management

- **Hierarchical Game Tree:** Full support for branching variations, sub-variations, and mainline moves.
- **Navigation Controls:** First ply, previous ply, next ply, last ply, and auto-play controls with smooth animations.
- **PGN Import & Export:** Full PGN parsing including headers, moves, comments, and NAG annotations.

---

### 6. Sovereign Offline Asset Management

- **Independent Asset Lifecycle:** In-app download manager for engine binaries and neural network weights directly from verified upstream releases.
- **Integrity Validation:** Automated SHA-256 digest validation with atomic staging (`.tmp` to permanent destination).
- **Storage Accounting:** Real-time visibility into disk usage by engines and models, with instant one-tap uninstallation and clean temp file garbage collection.
- **Custom Binary Linking:** Ability to link existing user-supplied binaries from local storage.
