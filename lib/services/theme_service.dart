import '../theme/lichess_theme.dart';
export '../theme/lichess_theme.dart' show BoardThemeData, LichessColors, LichessBoardThemes;

class ThemeService {
  static List<BoardThemeData> get boardThemes => LichessBoardThemes.allThemes;

  static const List<String> pieceSets = [
    'cburnett',
    'merida',
    'alpha',
    'staunty',
    'anarcandy',
    'california',
    'cardinal',
    'tatiana',
  ];

  static const List<String> soundThemes = [
    'standard',
    'futuristic',
    'nes',
    'piano',
    'sfx',
    'silent',
  ];

  BoardThemeData activeBoard = LichessBoardThemes.brown;
  String activePieceSet = 'cburnett';
  String activeSoundTheme = 'standard';
  bool soundEnabled = true;
  int pieceAnimationMs = 200;

  BoardThemeData getBoardTheme(String id) {
    return LichessBoardThemes.getTheme(id);
  }
}
