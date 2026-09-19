# Lichess Sound Assets & Attribution Manifest

This document records all audio sound assets integrated into ChessCrack from official upstream Lichess repositories, providing complete attribution, licensing verification, and event-to-sound dispatch mapping.

---

## 1. Upstream Sources & Repositories

All sound effects utilized in ChessCrack originate directly from official Lichess open-source repositories:
- **`lichess-org/lila`** (`https://github.com/lichess-org/lila`): Canonical Lichess web client sound system (`ui/site/src/sound.ts`).
- **`lichess-org/mobile`** (`https://github.com/lichess-org/mobile`): Official Lichess mobile client sound packs and assets (`assets/sounds/`).

Lichess audio assets are distributed under open-source and Creative Commons licenses (GPLv3 / CC-BY-SA / CC0), making them freely available for open chess software development with attribution.

---

## 2. Integrated Audio Assets Catalog

All audio files are packaged locally inside `assets/sounds/` and bundled into the self-contained ChessCrack application:

| Theme Folder | File Name | Size (Bytes) | Upstream Canonical Purpose |
|---|---|---|---|
| `standard/` | `move.mp3` | 2,214 | Standard piece movement sound on wooden/vinyl board |
| `standard/` | `capture.mp3` | 3,049 | Piece capture acoustic impact sound |
| `standard/` | `check.mp3` | 8,011 | King in check notification cue |
| `standard/` | `castle.mp3` | 2,547 | Castling move acoustic cue |
| `standard/` | `promote.mp3` | 3,432 | Pawn promotion cue |
| `standard/` | `dong.mp3` | 11,159 | Canonical game start / game end / checkmate / stalemate chime |
| `standard/` | `confirmation.mp3` | 3,493 | Action confirmation / variation commit cue |
| `standard/` | `error.mp3` | 1,689 | Illegal move / error acoustic cue |
| `standard/` | `lowTime.mp3` | 3,122 | Time warning audio cue |
| `standard/` | `explosion.mp3` | 26,688 | Atomic chess / explosion sound effect |
| `standard/` | `puzzleStormEnd.mp3` | 65,200 | Analysis complete / puzzle sequence fanfare |
| `futuristic/` | `move.mp3`, `capture.mp3`, `dong.mp3`, `lowTime.mp3`, `explosion.mp3` | Varies | Modern sci-fi synthesizer chess audio theme |
| `nes/` | `move.mp3`, `capture.mp3`, `dong.mp3`, `lowTime.mp3`, `explosion.mp3` | Varies | 8-bit retro gaming audio theme |
| `piano/` | `move.mp3`, `capture.mp3`, `dong.mp3`, `lowTime.mp3`, `explosion.mp3` | Varies | Acoustic piano chord progressions theme |
| `sfx/` | `move.mp3`, `capture.mp3`, `explosion.mp3`, `lowTime.mp3` | Varies | Arcade sound effects audio theme |
| `lisp/` | `move.mp3`, `capture.mp3`, `dong.mp3`, `confirmation.mp3`, `error.mp3` | Varies | Playful synthetic sound effects theme |

---

## 3. Authentic Event-to-Sound Dispatch Architecture

Sound playback is centralized in `ChessSoundService` (`lib/services/chess_sound_service.dart`) and dispatches deterministic audio cues based on the chess move semantics and resulting board state:

```text
                                 [Chess Move Committed]
                                           │
                                ┌──────────┴──────────┐
                                │ Checkmate / GameEnd? │ ─── YES ───► playSound(checkmate) -> dong.mp3
                                └──────────┬──────────┘
                                           │ NO
                                ┌──────────┴──────────┐
                                │     Stalemate?      │ ─── YES ───► playSound(stalemate) -> dong.mp3
                                └──────────┬──────────┘
                                           │ NO
                                ┌──────────┴──────────┐
                                │   King in Check?    │ ─── YES ───► playSound(check) -> check.mp3
                                └──────────┬──────────┘
                                           │ NO
                                ┌──────────┴──────────┐
                                │     Castling?       │ ─── YES ───► playSound(castle) -> castle.mp3
                                └──────────┬──────────┘
                                           │ NO
                                ┌──────────┴──────────┐
                                │     Promotion?      │ ─── YES ───► playSound(promote) -> promote.mp3
                                └──────────┬──────────┘
                                           │ NO
                                ┌──────────┴──────────┐
                                │      Capture?       │ ─── YES ───► playSound(capture) -> capture.mp3
                                └──────────┬──────────┘
                                           │ NO
                                           ▼
                                 playSound(move) -> move.mp3
```

### Strict Non-Interference Invariants
1. **Engine Analysis Stream Is 100% Silent**: The high-frequency engine UCI `info` stream (evals, depths, nodes, nps, PV candidate arrows) does **NOT** trigger sound effects.
2. **Move & Navigation Audio Only**: Audio cues trigger only on explicit user moves, forward/backward game navigation, variation navigation, and variation auto-play.
3. **Mute & Volume Control**: Users can toggle sound ON/OFF at any time in the settings dialog or adjust volume from 0% to 100%.

---

## 4. Licenses and Attributions

- **Lichess.org**: All sound assets originate from Lichess.org, created and curated by Thibault Duplessis and the Lichess development community.
- **Colin M.L. Burnett**: Piece set graphics.
- **Audio Creators**: Sound effects created for Lichess and open-source chess applications under CC-BY-SA 4.0 / CC0 Public Domain.
