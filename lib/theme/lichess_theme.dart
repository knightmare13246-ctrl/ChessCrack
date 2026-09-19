import 'package:flutter/material.dart';

/// Exact color tokens from the official Lichess repository (lichess-mobile/src/styles/lichess_colors.dart).
class LichessColors {
  LichessColors._();

  // Primary: Lichess Blue
  static const Color primary = Color(0xFF1B78D0);
  static const Color primaryLight = Color(0xFF5FA1DE);
  static const Color primaryDark = Color(0xFF105BBE);

  // Secondary: Lichess Green
  static const Color secondary = Color(0xFF629924);
  static const Color green = secondary;
  static const Color good = secondary;

  // Accent: Lichess Orange
  static const Color accent = Color(0xFFD64F00);

  // Error / Red
  static const Color red = Color(0xFFCC3333);
  static const Color error = red;

  // Warning / Brag
  static const Color brag = Color(0xFFBF811D);
  static const Color warn = brag;

  // Fancy Pink
  static const Color fancy = Color(0xFFB72FC6);

  // Analysis / Quality annotations
  static const Color cyan = Color(0xFF56B4E9);
  static const Color blue = Color(0xFF0072B2);
  static const Color purple = Color(0xFF8572FF);

  static const Color inaccuracy = cyan;
  static const Color mistake = Color(0xFFE69F00);
  static const Color blunder = Color(0xFFDF5353);

  // Lichess Dark Theme Backgrounds & Surfaces
  static const Color darkBackground = Color(0xFF161512);
  static const Color darkSurface = Color(0xFF24221E);
  static const Color darkSurfaceHigh = Color(0xFF2E2C28);
  static const Color darkSurfaceHighest = Color(0xFF383632);
  static const Color darkBorder = Color(0xFF3B3935);
  static const Color darkTextMuted = Color(0xFF9E9A93);
  static const Color darkText = Color(0xFFE3E1DE);
}

/// Layout and typography tokens from the official Lichess repository.
class LichessStyles {
  LichessStyles._();

  static const cardBorderRadius = BorderRadius.all(Radius.circular(12.0));
  static const boardBorderRadius = BorderRadius.all(Radius.circular(5.0));

  static const TextStyle title = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.bold,
    color: LichessColors.darkText,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    color: LichessColors.darkTextMuted,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13.0,
    color: LichessColors.darkText,
  );
}

/// Official board theme definition, supporting solid colors and textured JPEG/WebP backgrounds.
class BoardThemeData {
  final String id;
  final String name;
  final Color lightSquare;
  final Color darkSquare;
  final Color coordinateColor;
  final Color selectedHighlight;
  final Color lastMoveHighlight;
  final Color validMovesColor;
  final String? imageAssetPath;

  const BoardThemeData({
    required this.id,
    required this.name,
    required this.lightSquare,
    required this.darkSquare,
    required this.coordinateColor,
    required this.selectedHighlight,
    required this.lastMoveHighlight,
    required this.validMovesColor,
    this.imageAssetPath,
  });

  bool get isTexture => imageAssetPath != null;
}

/// Exact board definitions from `flutter-chessground/lib/src/board_color_scheme.dart`.
class LichessBoardThemes {
  LichessBoardThemes._();

  static const brown = BoardThemeData(
    id: 'brown',
    name: 'Classic Brown',
    lightSquare: Color(0xFFF0D9B6),
    darkSquare: Color(0xFFB58863),
    coordinateColor: Color(0xFFB58863),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
  );

  static const blue = BoardThemeData(
    id: 'blue',
    name: 'Blue',
    lightSquare: Color(0xFFDEE3E6),
    darkSquare: Color(0xFF8CA2AD),
    coordinateColor: Color(0xFF8CA2AD),
    lastMoveHighlight: Color(0x809BC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
  );

  static const green = BoardThemeData(
    id: 'green',
    name: 'Green (Tournament)',
    lightSquare: Color(0xFFFFFFDD),
    darkSquare: Color(0xFF86A666),
    coordinateColor: Color(0xFF86A666),
    lastMoveHighlight: Color.fromRGBO(0, 155, 199, 0.41),
    selectedHighlight: Color.fromRGBO(216, 85, 0, 0.3),
    validMovesColor: Color.fromRGBO(0, 0, 0, 0.20),
  );

  static const ic = BoardThemeData(
    id: 'ic',
    name: 'IC / Grey',
    lightSquare: Color(0xFFECECEC),
    darkSquare: Color(0xFFC1C18E),
    coordinateColor: Color(0xFFC1C18E),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
  );

  // Official Lichess Texture Boards
  static const wood = BoardThemeData(
    id: 'wood',
    name: 'Wood',
    lightSquare: Color(0xFFD8A45B),
    darkSquare: Color(0xFF9B4D0F),
    coordinateColor: Color(0xFF9B4D0F),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/wood.jpg',
  );

  static const wood2 = BoardThemeData(
    id: 'wood2',
    name: 'Wood 2 (Walnut)',
    lightSquare: Color(0xFFA38B5D),
    darkSquare: Color(0xFF6C5017),
    coordinateColor: Color(0xFF6C5017),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/wood2.jpg',
  );

  static const wood3 = BoardThemeData(
    id: 'wood3',
    name: 'Wood 3 (Ash)',
    lightSquare: Color(0xFFD0CECA),
    darkSquare: Color(0xFF755839),
    coordinateColor: Color(0xFF755839),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/wood3.jpg',
  );

  static const wood4 = BoardThemeData(
    id: 'wood4',
    name: 'Wood 4 (Oak)',
    lightSquare: Color(0xFFCAAF7D),
    darkSquare: Color(0xFF7B5330),
    coordinateColor: Color(0xFF7B5330),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/wood4.jpg',
  );

  static const canvas = BoardThemeData(
    id: 'canvas',
    name: 'Canvas',
    lightSquare: Color(0xFFD7DAEB),
    darkSquare: Color(0xFF547388),
    coordinateColor: Color(0xFF547388),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/canvas2.jpg',
  );

  static const leather = BoardThemeData(
    id: 'leather',
    name: 'Leather',
    lightSquare: Color(0xFFD1D1C9),
    darkSquare: Color(0xFFC28E16),
    coordinateColor: Color(0xFFC28E16),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/leather.jpg',
  );

  static const marble = BoardThemeData(
    id: 'marble',
    name: 'Marble',
    lightSquare: Color(0xFF93AB91),
    darkSquare: Color(0xFF4F644E),
    coordinateColor: Color(0xFF4F644E),
    lastMoveHighlight: Color.fromRGBO(0, 155, 199, 0.41),
    selectedHighlight: Color.fromRGBO(216, 85, 0, 0.3),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/marble.jpg',
  );

  static const metal = BoardThemeData(
    id: 'metal',
    name: 'Metal',
    lightSquare: Color(0xFFC9C9C9),
    darkSquare: Color(0xFF727272),
    coordinateColor: Color(0xFF727272),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/metal.jpg',
  );

  static const grey = BoardThemeData(
    id: 'grey',
    name: 'Grey',
    lightSquare: Color(0xFFB8B8B8),
    darkSquare: Color(0xFF7D7D7D),
    coordinateColor: Color(0xFF7D7D7D),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/grey.jpg',
  );

  static const maple = BoardThemeData(
    id: 'maple',
    name: 'Maple',
    lightSquare: Color(0xFFE8CEAB),
    darkSquare: Color(0xFFBC7944),
    coordinateColor: Color(0xFFBC7944),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/maple.jpg',
  );

  static const blue2 = BoardThemeData(
    id: 'blue2',
    name: 'Blue 2',
    lightSquare: Color(0xFF97B2C7),
    darkSquare: Color(0xFF546F82),
    coordinateColor: Color(0xFF546F82),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/blue2.jpg',
  );

  static const blue3 = BoardThemeData(
    id: 'blue3',
    name: 'Blue 3',
    lightSquare: Color(0xFFD9E0E6),
    darkSquare: Color(0xFF315991),
    coordinateColor: Color(0xFF315991),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/blue3.jpg',
  );

  static const blueMarble = BoardThemeData(
    id: 'blueMarble',
    name: 'Blue Marble',
    lightSquare: Color(0xFFEAE6DD),
    darkSquare: Color(0xFF7C7F87),
    coordinateColor: Color(0xFF7C7F87),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/blue-marble.jpg',
  );

  static const greenPlastic = BoardThemeData(
    id: 'greenPlastic',
    name: 'Green Plastic',
    lightSquare: Color(0xFFF2F9BB),
    darkSquare: Color(0xFF59935D),
    coordinateColor: Color(0xFF59935D),
    lastMoveHighlight: Color.fromRGBO(0, 155, 199, 0.41),
    selectedHighlight: Color.fromRGBO(216, 85, 0, 0.3),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/green-plastic.webp',
  );

  static const newspaper = BoardThemeData(
    id: 'newspaper',
    name: 'Newspaper',
    lightSquare: Color(0xFFFFFFFF),
    darkSquare: Color(0xFF8D8D8D),
    coordinateColor: Color(0xFF8D8D8D),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/newspaper.webp',
  );

  static const olive = BoardThemeData(
    id: 'olive',
    name: 'Olive',
    lightSquare: Color(0xFFB8B19F),
    darkSquare: Color(0xFF6D6655),
    coordinateColor: Color(0xFF6D6655),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/olive.jpg',
  );

  static const purple = BoardThemeData(
    id: 'purple',
    name: 'Purple',
    lightSquare: Color(0xFF9F90B0),
    darkSquare: Color(0xFF7D4A8D),
    coordinateColor: Color(0xFF7D4A8D),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/purple.webp',
  );

  static const horsey = BoardThemeData(
    id: 'horsey',
    name: 'Horsey',
    lightSquare: Color(0xFFF0D9B5),
    darkSquare: Color(0xFF946F51),
    coordinateColor: Color(0xFF946F51),
    lastMoveHighlight: Color(0x809CC700),
    selectedHighlight: Color(0x6014551E),
    validMovesColor: Color(0x4014551E),
    imageAssetPath: 'assets/boards/horsey.jpg',
  );

  static const List<BoardThemeData> allThemes = [
    brown,
    green,
    blue,
    ic,
    wood,
    wood2,
    wood3,
    wood4,
    canvas,
    leather,
    marble,
    metal,
    grey,
    maple,
    blue2,
    blue3,
    blueMarble,
    greenPlastic,
    newspaper,
    olive,
    purple,
    horsey,
  ];

  static BoardThemeData getTheme(String id) {
    return allThemes.firstWhere(
      (t) => t.id.toLowerCase() == id.toLowerCase(),
      orElse: () => brown,
    );
  }
}

/// Builds the canonical Lichess Dark ThemeData for the Flutter application.
ThemeData makeLichessDarkTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: LichessColors.primary,
    onPrimary: Colors.white,
    secondary: LichessColors.secondary,
    onSecondary: Colors.white,
    error: LichessColors.red,
    onError: Colors.white,
    surface: LichessColors.darkBackground,
    onSurface: LichessColors.darkText,
    surfaceContainer: LichessColors.darkSurface,
    surfaceContainerHigh: LichessColors.darkSurfaceHigh,
    surfaceContainerHighest: LichessColors.darkSurfaceHighest,
    outline: LichessColors.darkBorder,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: LichessColors.darkBackground,
    canvasColor: LichessColors.darkBackground,
    cardTheme: const CardThemeData(
      color: LichessColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: LichessStyles.cardBorderRadius),
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: LichessColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: LichessStyles.cardBorderRadius),
      titleTextStyle: LichessStyles.title,
    ),
    dividerTheme: const DividerThemeData(
      color: LichessColors.darkBorder,
      thickness: 1,
      space: 1,
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: LichessColors.primary,
      labelColor: LichessColors.primary,
      unselectedLabelColor: LichessColors.darkTextMuted,
      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
    ),
  );
}
