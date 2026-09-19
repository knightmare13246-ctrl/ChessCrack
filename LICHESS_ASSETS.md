# Lichess Assets Manifest

This manifest documents all visual, board, piece, and audio assets integrated directly from official Lichess repositories into this application with 100% asset fidelity.

---

## 1. Upstream Sources
- **`lichess-org/flutter-chessground`** (GitHub: `https://github.com/lichess-org/flutter-chessground`): Canonical high-DPI piece sets (WebP 1x, 2x, 3x, 4x), official board textures (JPEG/WebP), and exact `ChessboardColorScheme` definitions.
- **`lichess-org/mobile`** (GitHub: `https://github.com/lichess-org/mobile`): Canonical chess sounds (`standard`, `futuristic`, `nes`, `piano`, `sfx`), theme variables (`LichessColors`, `Styles`), and dark/light UI tokens.

---

## 2. Integrated Asset Mapping

| Original Lichess Repository Path | Local Project Path | Asset Type | Purpose / Usage | Consuming Component |
|---|---|---|---|---|
| `flutter-chessground/assets/piece_sets/cburnett/` | `assets/piece_sets/cburnett/` | WebP Images (1x, 2x, 3x, 4x) | Default official Lichess piece set by Colin M.L. Burnett | `PieceWidget`, `NibblerBoard`, `PromotionDialog` |
| `flutter-chessground/assets/piece_sets/merida/` | `assets/piece_sets/merida/` | WebP Images (1x, 2x, 3x, 4x) | Popular classical Lichess piece set | `PieceWidget`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/piece_sets/alpha/` | `assets/piece_sets/alpha/` | WebP Images (1x, 2x, 3x, 4x) | Clean modern alpha piece set | `PieceWidget`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/piece_sets/staunty/` | `assets/piece_sets/staunty/` | WebP Images (1x, 2x, 3x, 4x) | Traditional Staunton piece set | `PieceWidget`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/piece_sets/anarcandy/` | `assets/piece_sets/anarcandy/` | WebP Images (1x, 2x, 3x, 4x) | Fun vibrant Lichess candy piece set | `PieceWidget`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/piece_sets/california/` | `assets/piece_sets/california/` | WebP Images (1x, 2x, 3x, 4x) | American classic wood-style piece set | `PieceWidget`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/piece_sets/cardinal/` | `assets/piece_sets/cardinal/` | WebP Images (1x, 2x, 3x, 4x) | Elegant Cardinal piece set | `PieceWidget`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/piece_sets/tatiana/` | `assets/piece_sets/tatiana/` | WebP Images (1x, 2x, 3x, 4x) | Tatiana stylized piece set | `PieceWidget`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/canvas2.jpg` | `assets/boards/canvas2.jpg` | JPEG Texture (1024x1024) | Canvas board theme background texture | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/wood.jpg` | `assets/boards/wood.jpg` | JPEG Texture (1024x1024) | Classic Lichess wood board texture | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/wood2.jpg` | `assets/boards/wood2.jpg` | JPEG Texture (1024x1024) | Wood 2 walnut board texture | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/wood3.jpg` | `assets/boards/wood3.jpg` | JPEG Texture (1024x1024) | Wood 3 ash board texture | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/wood4.jpg` | `assets/boards/wood4.jpg` | JPEG Texture (1024x1024) | Wood 4 warm oak board texture | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/leather.jpg` | `assets/boards/leather.jpg` | JPEG Texture (1024x1024) | Textured leather chessboard | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/marble.jpg` | `assets/boards/marble.jpg` | JPEG Texture (1024x1024) | Green marble polished chessboard | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/metal.jpg` | `assets/boards/metal.jpg` | JPEG Texture (1024x1024) | Brushed industrial metal chessboard | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/grey.jpg` | `assets/boards/grey.jpg` | JPEG Texture (1024x1024) | Neutral grey textured board | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/maple.jpg` | `assets/boards/maple.jpg` | JPEG Texture (1024x1024) | Natural maple wood chessboard | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/blue2.jpg` | `assets/boards/blue2.jpg` | JPEG Texture (1024x1024) | Blue textured board | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/blue3.jpg` | `assets/boards/blue3.jpg` | JPEG Texture (1024x1024) | Deep blue tournament board | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/blue-marble.jpg` | `assets/boards/blue-marble.jpg` | JPEG Texture (1024x1024) | Blue veined marble board | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/green-plastic.webp` | `assets/boards/green-plastic.webp` | WebP Image | Tournament green plastic board | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/horsey.jpg` | `assets/boards/horsey.jpg` | JPEG Image | Community favorite Horsey meme board | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/newspaper.webp` | `assets/boards/newspaper.webp` | WebP Image | Vintage newsprint board | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/olive.jpg` | `assets/boards/olive.jpg` | JPEG Image | Olive wood grain board | `NibblerBoard`, `ThemeSettingsDialog` |
| `flutter-chessground/assets/boards/purple.webp` | `assets/boards/purple.webp` | WebP Image | Vibrant purple board | `NibblerBoard`, `ThemeSettingsDialog` |
| `lichess-mobile/assets/sounds/standard/` | `assets/sounds/standard/` | Audio MP3 | Official default sound pack (`move`, `capture`, `confirmation`, `dong`, `error`, `lowTime`, `puzzleStormEnd`, `explosion`) | `SoundService` |
| `lichess-mobile/assets/sounds/futuristic/` | `assets/sounds/futuristic/` | Audio MP3 | Modern sci-fi sound pack | `SoundService`, `ThemeSettingsDialog` |
| `lichess-mobile/assets/sounds/nes/` | `assets/sounds/nes/` | Audio MP3 | 8-bit retro gaming sound pack | `SoundService`, `ThemeSettingsDialog` |
| `lichess-mobile/assets/sounds/piano/` | `assets/sounds/piano/` | Audio MP3 | Acoustic piano chords sound pack | `SoundService`, `ThemeSettingsDialog` |
| `lichess-mobile/assets/sounds/sfx/` | `assets/sounds/sfx/` | Audio MP3 | Arcade sound effects pack | `SoundService`, `ThemeSettingsDialog` |
| `flutter-chessground/lib/src/board_color_scheme.dart` | `lib/theme/lichess_theme.dart` | Dart Colors / Schemes | Exact square hex values, highlight detail colors, and move dots | `NibblerBoard`, `ThemeService` |
| `lichess-mobile/lib/src/styles/lichess_colors.dart` | `lib/theme/lichess_theme.dart` | Dart Design Tokens | Canonical Lichess UI colors (Primary `#1B78D0`, Secondary `#629924`, Accent `#D64F00`, Red `#CC3333`, Dark `#161512`) | App theme, headers, eval bars, dialogs |
| `lichess-mobile/lib/src/styles/styles.dart` | `lib/theme/lichess_theme.dart` | Dart Layout Tokens | Typography, card border radius (12.0), board radius (5.0), paddings | All UI screens & widgets |
