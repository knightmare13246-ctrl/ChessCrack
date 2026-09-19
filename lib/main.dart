import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/lichess_theme.dart';
import 'ui/screens/chess_analysis_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: LichessColors.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ChessCrackApp());
}

class ChessCrackApp extends StatelessWidget {
  const ChessCrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChessCrack',
      debugShowCheckedModeBanner: false,
      theme: makeLichessDarkTheme(),
      home: const ChessAnalysisScreen(),
    );
  }
}
