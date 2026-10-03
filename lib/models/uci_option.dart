enum UciOptionType {
  check,
  spin,
  combo,
  button,
  string,
}

class UciOption {
  final String name;
  final UciOptionType type;
  final String? defaultValue;
  final int? min;
  final int? max;
  final List<String>? varValues;

  const UciOption({
    required this.name,
    required this.type,
    this.defaultValue,
    this.min,
    this.max,
    this.varValues,
  });

  /// Parses a raw UCI option line:
  /// e.g. "option name UCI_LimitStrength type check default false"
  /// e.g. "option name UCI_Elo type spin default 1320 min 1320 max 3190"
  static UciOption? parse(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('option name ')) return null;

    final regExp = RegExp(r'^option name (.+?) type (check|spin|combo|button|string)(.*)$');
    final match = regExp.firstMatch(trimmed);
    if (match == null) return null;

    final name = match.group(1)!.trim();
    final typeStr = match.group(2)!;
    final rest = match.group(3) ?? '';

    UciOptionType type;
    switch (typeStr) {
      case 'check':
        type = UciOptionType.check;
        break;
      case 'spin':
        type = UciOptionType.spin;
        break;
      case 'combo':
        type = UciOptionType.combo;
        break;
      case 'button':
        type = UciOptionType.button;
        break;
      case 'string':
      default:
        type = UciOptionType.string;
        break;
    }

    String? defaultValue;
    int? minVal;
    int? maxVal;
    List<String>? vars;

    final defaultMatch = RegExp(r'default\s+(\S+)').firstMatch(rest);
    if (defaultMatch != null) {
      defaultValue = defaultMatch.group(1);
    }

    final minMatch = RegExp(r'min\s+(-?\d+)').firstMatch(rest);
    if (minMatch != null) {
      minVal = int.tryParse(minMatch.group(1)!);
    }

    final maxMatch = RegExp(r'max\s+(-?\d+)').firstMatch(rest);
    if (maxMatch != null) {
      maxVal = int.tryParse(maxMatch.group(1)!);
    }

    final varMatches = RegExp(r'var\s+(\S+)').allMatches(rest);
    if (varMatches.isNotEmpty) {
      vars = varMatches.map((m) => m.group(1)!).toList();
    }

    return UciOption(
      name: name,
      type: type,
      defaultValue: defaultValue,
      min: minVal,
      max: maxVal,
      varValues: vars,
    );
  }

  @override
  String toString() =>
      'UciOption($name, type: $type, default: $defaultValue, min: $min, max: $max)';
}
