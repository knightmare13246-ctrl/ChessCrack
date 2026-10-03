# COMPREHENSIVE TESTING MATRIX & VERIFICATION SUITE
## Test Architecture, Invariants, and Automated Coverage

---

### 1. Test Architecture Overview

ChessCrack maintains a test suite (200 automated tests) ensuring rock-solid stability across chess algorithms, engine subprocesses, telemetry parsing, and UI rendering:

```
┌───────────────────────────────────────────────────────────┐
│               ChessCrack Automated Test Suite             │
│                       (200 / 200 Passing)                 │
└─────────────────────────────┬─────────────────────────────┘
                              │
  ┌───────────────────────────┼───────────────────────────┐
  ▼                           ▼                           ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   Unit & Logic   │  │Engine & Telemetry│  │  UI & Rendering  │
│  - Chess rules   │  │  - UCI parsers   │  │  - Moves chart   │
│  - SAN / FEN     │  │  - NPS / nodes   │  │  - Candidate arr │
│  - PGN tree      │  │  - Lc0 invariants│  │  - Eval bar      │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

---

### 2. Test Subsystems and Invariants

| Test Suite File | Test Count | Key Invariants Verified |
| :--- | :---: | :--- |
| `chess_logic_test.dart` | 24 | Move generation, check/checkmate detection, castling rights, en passant, promotion, FEN reconstruction. |
| `evaluation_system_test.dart` | 18 | MultiPV sorting, mate score formatting (`#M1`, `#-M2`), centipawn formatting, score inversion for black to move. |
| `moves_by_rating_test.dart` | 5 | 21-point Elo domain (600..2600), probability bounds ($0.0\% \le P \le 100.0\%$), cubic interpolation, peak rating detection. |
| `candidate_arrow_system_test.dart` | 14 | Arrow delta computation, knight Bézier curves, multi-arrow ordering, badge placement. |
| `telemetry_adversarial_challenge_test.dart` | 42 | Zero/null NPS formatting (`N/s: —` vs `N/s: N/A`), comma-grouped nodes up to trillions, crash-free widget rendering under null telemetry. |
| `artifact_deletion_lifecycle_e2e_test.dart` | 6 | Asset downloads, atomic temp writing, pause/resume, SHA-256 verification, safe unlinking, storage accounting. |
| `maia_sparring_e2e_test.dart` | 12 | Discrete sparring networks (1100–1900), `go nodes 1` policy execution, non-destructive sparring moves. |
| `widget_test.dart` | 7 | Eval bar rendering, theme selector, arrow settings dialog, responsive chart layouts. |

---

### 3. Adversarial Invariants & Regression Prevention

1. **Zero Fake Telemetry:**
   - Under no circumstances does the engine layer inject artificial nodes, NPS, or depths.
   - If Lc0 does not emit NPS, the UI displays `N/s: N/A` without breaking layouts.
   - If Stockfish starts up or search begins before NPS calculation, the UI displays `N/s: —`.
2. **Subprocess Survival:**
   - Unexpected engine exit triggers clean state resets without causing Flutter application crashes or freezing the UI thread.
3. **Safe Memory & Thread Management:**
   - Rapid move scrubbing throttles and cancels outdated engine searches, preventing subprocess pileups and out-of-memory errors on resource-constrained mobile hardware.
