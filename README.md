# ChessCrack

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-green.svg)](https://flutter.dev)
[![Category: Productivity](https://img.shields.io/badge/Category-Productivity%20%2F%20Education-orange.svg)]()

**ChessCrack** is a high-performance, offline chess analysis workbench and neural network exploration tool for Android. Inspired by desktop analysis tools like Nibbler and DroidFish, ChessCrack turns your mobile device into a dedicated chess research laboratory for deep positional analysis, move-tree branching, and human-like sparring evaluations.

---

## ⚠️ Important Note: Analysis Workbench, Not a Game

ChessCrack is an **analytical utility and chess study workbench**, not a casual chess game:
- It does **not** feature game matchmaking, player rankings, lobbies, or gamified mechanics.
- It is designed specifically for opening preparation, post-mortem game review, blunder checking, endgame tablebase study, and evaluating chess positions using native Universal Chess Interface (UCI) engines and neural networks.

---

## Zero-Binary Base Packaging (No Bundled Engines/Weights)

To maintain a minimal footprint and respect user bandwidth and storage:
- The base application contains **no bundled engine executables** (Stockfish/Lc0) and **no bundled neural network weights** (Maia/Leela).
- The base APK is kept strictly under store limits (< 20 MB).
- Through the built-in **Engine & Network Manager**, users select and download only the engines and weights they need directly from verified, official upstream releases:
  - **Stockfish**: Official releases from [official-stockfish/Stockfish](https://github.com/official-stockfish/Stockfish/releases)
  - **Leela Chess Zero (Lc0)**: Official native Android packages from [LeelaChessZero/lc0](https://github.com/LeelaChessZero/lc0/releases)
  - **Maia Human Sparring Networks**: Official models (1100–2200) from [lczero.org](https://lczero.org/play/networks/sparring-nets/)

All downloads are verified with checksums and extracted into the app's sandboxed private storage.

---

## Key Features

- **Dual UCI Engine Support**: Run classical alpha-beta evaluation (Stockfish) or deep neural network Monte Carlo tree search (Lc0).
- **Human Sparring Networks**: Test and analyze positions against Maia neural networks trained on human play at various Elo ratings (1100 to 2200 at `Nodes = 1`).
- **Interactive Move Tree**: Full branching variation explorer. Navigate sidelines, promote variations, and inspect engine evaluations at every node.
- **Dynamic PV Visualization**: Multi-PV candidate moves rendered as directional arrows directly on the board with customizable thickness, arrowhead types, and color thresholds.
- **Comprehensive PGN & FEN Support**: Import and export standard PGN files, paste positions, and copy FENs with a single tap.
- **Engine Diagnostics & Telemetry**: Monitor nodes per second (NPS), search depth, selective depth, hash table utilization, and multi-PV variations in real time.
- **Full Privacy & Offline Capability**: Once engines are downloaded, all analysis executes 100% offline on-device. No telemetry, no tracking, and no external network traffic.

---

## Android Permissions

ChessCrack requests only the absolute minimum permissions required for operation:

| Permission | Reason |
|---|---|
| `android.permission.INTERNET` | Strictly required to download user-selected engines (Stockfish/Lc0) and Maia neural network weights from official sources. The analysis itself runs entirely offline. |
| `android.permission.VIBRATE` | Provides subtle haptic feedback when making moves on the board. |

*No external storage, camera, contacts, or location permissions are requested or used.*

---

## Building from Source

### Prerequisites
- **Flutter SDK**: `>=3.10.0 <4.0.0` (channel stable)
- **Dart SDK**: `>=3.0.0 <4.0.0`
- **Android SDK**: API 35 (Android 15) with build-tools `36.0.0`
- **Java Development Kit**: JDK 17

### Build Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/knightmare13246-ctrl/ChessCrack.git
   cd ChessCrack
   ```

2. **Fetch Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify code quality:**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Build release APK (per ABI):**
   ```bash
   flutter build apk --split-per-abi
   ```
   The resulting split APKs will be located in `build/app/outputs/flutter-apk/`:
   - `app-arm64-v8a-release.apk`
   - `app-armeabi-v7a-release.apk`
   - `app-x86_64-release.apk`

---

## Upstream Credits & Third-Party Licenses

ChessCrack is built upon open-source chess software and creative assets:

- **Stockfish**: The Stockfish developers — [stockfishchess.org](https://stockfishchess.org) (GPLv3)
- **Leela Chess Zero (Lc0)**: The Lc0 authors — [lczero.org](https://lczero.org) (GPLv3)
- **Maia Chess**: CSSLab, University of Toronto — [maiachess.com](https://maiachess.com) (GPLv3 / CC-BY-SA)
- **Nibbler GUI**: Desktop inspiration by Tomas Rokicki — [github.com/rooklift/nibbler](https://github.com/rooklift/nibbler) (GPLv3)
- **Chess Pieces & Sounds**: Sourced from [Lichess.org](https://lichess.org) under Creative Commons licenses (cburnett, merida, alpha, staunty, etc.)

---

## License

ChessCrack is free and open-source software licensed under the **GNU General Public License v3.0 (GPL-3.0-or-later)**. See the [LICENSE](LICENSE) file for the complete license text.
