import 'dart:math' as math;

class WinRateCalculator {
  // Converts Lc0 WDL per-mille (win, draw, loss) to win percentage
  static double wdlToWinPercentage(int win, int draw, int loss) {
    final total = win + draw + loss;
    if (total <= 0) return 50.0;
    final winScore = (win + (draw * 0.5)) / total * 100.0;
    return winScore.clamp(0.0, 100.0);
  }

  // Converts Stockfish centipawns to win percentage using the official Stockfish logistic curve
  static double cpToWinPercentage(int cp) {
    const double k = 0.00368208;
    final double winProb = 2.0 / (1.0 + math.exp(-k * cp)) - 1.0;
    final double winPct = 50.0 + (50.0 * winProb);
    return winPct.clamp(0.0, 100.0);
  }

  // Converts mate distance in moves to win percentage
  static double mateToWinPercentage(int mateInMoves) {
    if (mateInMoves > 0) {
      return math.max(98.0, 100.0 - (mateInMoves * 0.2));
    } else if (mateInMoves < 0) {
      return math.min(2.0, (mateInMoves.abs() * 0.2));
    }
    return 50.0;
  }

  // Converts relative side-to-move win% to White's perspective
  static double toWhitePerspective(double winPercentage, bool isWhiteTurn) {
    return isWhiteTurn ? winPercentage : (100.0 - winPercentage);
  }

  // Pure ARGB 32-bit integer color calculation
  static int getArrowColorValue(double winPercentage) {
    final pct = winPercentage.clamp(0.0, 100.0);

    const int colorGreen = 0xFF00D2BE;   // Teal/Emerald for >= 70%
    const int colorLime = 0xFF8CD600;    // Bright Lime for ~60%
    const int colorYellow = 0xFFF1C40F;  // Yellow for ~50%
    const int colorOrange = 0xFFE67E22;  // Orange for ~40%
    const int colorRed = 0xFFE74C3C;     // Red for <= 30%

    if (pct >= 70.0) {
      final t = ((pct - 70.0) / 30.0).clamp(0.0, 1.0);
      return _lerpColor(colorLime, colorGreen, t);
    } else if (pct >= 55.0) {
      final t = ((pct - 55.0) / 15.0).clamp(0.0, 1.0);
      return _lerpColor(colorYellow, colorLime, t);
    } else if (pct >= 45.0) {
      final t = ((pct - 45.0) / 10.0).clamp(0.0, 1.0);
      return _lerpColor(colorOrange, colorYellow, t);
    } else if (pct >= 30.0) {
      final t = ((pct - 30.0) / 15.0).clamp(0.0, 1.0);
      return _lerpColor(colorRed, colorOrange, t);
    } else {
      return colorRed;
    }
  }

  static int _lerpColor(int a, int b, double t) {
    final aA = (a >> 24) & 0xFF;
    final aR = (a >> 16) & 0xFF;
    final aG = (a >> 8) & 0xFF;
    final aB = a & 0xFF;

    final bA = (b >> 24) & 0xFF;
    final bR = (b >> 16) & 0xFF;
    final bG = (b >> 8) & 0xFF;
    final bB = b & 0xFF;

    final rA = (aA + (bA - aA) * t).round().clamp(0, 255);
    final rR = (aR + (bR - aR) * t).round().clamp(0, 255);
    final rG = (aG + (bG - aG) * t).round().clamp(0, 255);
    final rB = (aB + (bB - aB) * t).round().clamp(0, 255);

    return (rA << 24) | (rR << 16) | (rG << 8) | rB;
  }

  // Arrow thickness based on visits percentage or PV rank
  static double getArrowWidth(int multipv, double? visitPct) {
    if (visitPct != null) {
      return (2.5 + (visitPct / 100.0) * 5.0).clamp(2.5, 7.0);
    }
    switch (multipv) {
      case 1:
        return 5.5;
      case 2:
        return 4.0;
      case 3:
        return 3.2;
      default:
        return 2.5;
    }
  }

  // Arrow opacity based on visits percentage or PV rank
  static double getArrowOpacity(int multipv, double? visitPct) {
    if (visitPct != null) {
      return (0.45 + (visitPct / 100.0) * 0.55).clamp(0.45, 0.95);
    }
    switch (multipv) {
      case 1:
        return 0.92;
      case 2:
        return 0.75;
      case 3:
        return 0.65;
      default:
        return 0.50;
    }
  }
}
