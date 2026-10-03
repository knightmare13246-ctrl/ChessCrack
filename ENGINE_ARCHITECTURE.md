# ENGINE ARCHITECTURE & UCI INTEGRATION
## Subprocess Lifecycle, Thread Isolation, and Telemetry Pipelines

---

### 1. Architectural Overview

ChessCrack communicates with chess engines via the Universal Chess Interface (UCI) protocol running strictly on the host system or device. There are zero cloud microservices or remote evaluation dependencies.

```
┌─────────────────────────────────────────────────────────────┐
│                       Flutter UI Layer                      │
│     (ChessAnalysisScreen, BoardWidget, EngineAnalysisPanel) │
└──────────────┬───────────────────────────────▲──────────────┘
               │ User actions                  │ Analysis streams
               ▼                               │
┌─────────────────────────────────────────────────────────────┐
│                  EngineAnalysisController                   │
│     - FEN change deduplication & debouncing                 │
│     - Draft Variation management                            │
│     - Engine lifecycle state machine                        │
└──────────────┬───────────────────────────────▲──────────────┘
               │                               │
       ┌───────┴───────────────┐       ┌───────┴───────────────┐
       ▼                       ▼       ▼                       ▼
┌───────────────┐       ┌───────────────┐       ┌───────────────┐
│StockfishEngine│       │   Lc0Engine   │       │ MaiaEngineSvc │
│  (C++ Binary) │       │ (C++/OpenCL)  │       │ (Rating Sweep)│
└───────┬───────┘       └───────┬───────┘       └───────┬───────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│                     OS Subprocess Layer                     │
│  - Stdio Streams (stdin pipe, stdout pipe, stderr pipe)     │
│  - Process exit watchers & signal handling                  │
│  - Out-of-memory & crash boundary isolation                 │
└─────────────────────────────────────────────────────────────┘
```

---

### 2. Supported Engine Implementations

#### A. Stockfish Engine (`StockfishEngineService`)
- **Protocol:** Standard UCI alpha-beta tree search with NNUE neural network evaluation.
- **Commands Dispatched:**
  - `uci` $\to$ Waits for `uciok`.
  - `setoption name MultiPV value <N>`.
  - `setoption name Threads value <T>`.
  - `setoption name Hash value <M>`.
  - `isready` $\to$ Waits for `readyok`.
  - `position fen <FEN>`.
  - `go infinite` or `go depth <D>`.
- **Telemetry Parsing:**
  - Real-time extraction of `depth`, `seldepth`, `score cp` / `score mate`, `multipv`, `nodes`, `nps`, `time`, and `pv` tokens.
  - Zero synthetic values: if NPS is unavailable or 0 during startup, formatted as `N/s: —` rather than fake data. Comma-separated node counters (`1,234,567`).

#### B. Lc0 Engine (`Lc0EngineService` / Maia Sparring)
- **Protocol:** Leela Chess Zero (Lc0) running neural weights (e.g. `maia-1100.pb.gz` through `maia-1900.pb.gz`).
- **Configuration:**
  - `setoption name WeightsFile value <path/to/weights.pb.gz>`.
  - `setoption name Threads value 1`.
  - `setoption name MinibatchSize value 1`.
  - `setoption name MaxPrefetch value 0`.
- **Search Command:** Dispatches `go nodes 1` to extract pure policy head evaluations without deep Monte Carlo Tree Search expansion.
- **Handling Invariants:** Lc0 does not produce traditional alpha-beta NPS; if NPS is null or 0, it displays `N/s: N/A` without corrupting UI layout.

---

### 3. Thread Isolation and UI Protection

1. **Subprocess Isolation:** Engine executables execute as distinct OS processes spawned via `Process.start`. If an engine suffers a segfault or aborts due to hardware incompatibility (e.g. unsupported NEON/AVX instructions), the host Flutter process survives unscathed.
2. **Asynchronous Non-Blocking IO:** `stdout` is streamed line-by-line via asynchronous stream subscriptions. Engine parsing operates outside UI animation frames.
3. **Queue Coordination:** FEN transitions trigger atomic engine cancellation (`stop` followed by new `position fen`). If the user scrubs through moves quickly, intermediate FENs are canceled promptly to avoid compute lag.

---

### 4. Binary Discovery and Path Resolution

Binary locations are resolved in order of priority:
1. **User Custom Binary:** Explicit file selected via settings file picker.
2. **App Internal Directory:** `/data/user/0/org.chesscrack.app/files/engines/` on Android; application support directory on desktop.
3. **Fallback Android Executables:** `/data/local/tmp/` for development testing with execution permissions (`chmod 755`).
4. **System PATH:** Fallback search on desktop environments.
