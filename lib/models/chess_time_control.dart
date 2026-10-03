class ChessTimeControl {
  final String name;
  final int baseSeconds;
  final int incrementSeconds;
  final bool isUnlimited;

  const ChessTimeControl({
    required this.name,
    required this.baseSeconds,
    this.incrementSeconds = 0,
    this.isUnlimited = false,
  });

  const ChessTimeControl.unlimited()
      : name = 'Unlimited',
        baseSeconds = 0,
        incrementSeconds = 0,
        isUnlimited = true;

  factory ChessTimeControl.custom({
    required int baseMinutes,
    int incrementSeconds = 0,
  }) {
    return ChessTimeControl(
      name: '$baseMinutes+$incrementSeconds',
      baseSeconds: baseMinutes * 60,
      incrementSeconds: incrementSeconds,
    );
  }

  String get displayName {
    if (isUnlimited) return 'Unlimited';
    final mins = baseSeconds ~/ 60;
    final secs = baseSeconds % 60;
    if (secs == 0) {
      return incrementSeconds > 0 ? '$mins+$incrementSeconds' : '$mins min';
    } else {
      return incrementSeconds > 0 ? '${baseSeconds}s+$incrementSeconds' : '${baseSeconds}s';
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'baseSeconds': baseSeconds,
        'incrementSeconds': incrementSeconds,
        'isUnlimited': isUnlimited,
      };

  factory ChessTimeControl.fromJson(Map<String, dynamic> json) {
    if (json['isUnlimited'] == true) {
      return const ChessTimeControl.unlimited();
    }
    return ChessTimeControl(
      name: json['name'] as String? ?? 'Custom',
      baseSeconds: json['baseSeconds'] as int? ?? 300,
      incrementSeconds: json['incrementSeconds'] as int? ?? 0,
      isUnlimited: json['isUnlimited'] as bool? ?? false,
    );
  }

  static const ChessTimeControl hyperbullet30s = ChessTimeControl(
    name: '30s',
    baseSeconds: 30,
    incrementSeconds: 0,
  );

  static const ChessTimeControl bullet1_0 = ChessTimeControl(
    name: '1+0',
    baseSeconds: 60,
    incrementSeconds: 0,
  );

  static const ChessTimeControl bullet1_1 = ChessTimeControl(
    name: '1+1',
    baseSeconds: 60,
    incrementSeconds: 1,
  );

  static const ChessTimeControl bullet2_1 = ChessTimeControl(
    name: '2+1',
    baseSeconds: 120,
    incrementSeconds: 1,
  );

  static const ChessTimeControl blitz3_0 = ChessTimeControl(
    name: '3+0',
    baseSeconds: 180,
    incrementSeconds: 0,
  );

  static const ChessTimeControl blitz3_2 = ChessTimeControl(
    name: '3+2',
    baseSeconds: 180,
    incrementSeconds: 2,
  );

  static const ChessTimeControl blitz5_0 = ChessTimeControl(
    name: '5+0',
    baseSeconds: 300,
    incrementSeconds: 0,
  );

  static const ChessTimeControl blitz5_3 = ChessTimeControl(
    name: '5+3',
    baseSeconds: 300,
    incrementSeconds: 3,
  );

  static const ChessTimeControl rapid10_0 = ChessTimeControl(
    name: '10+0',
    baseSeconds: 600,
    incrementSeconds: 0,
  );

  static const ChessTimeControl rapid10_5 = ChessTimeControl(
    name: '10+5',
    baseSeconds: 600,
    incrementSeconds: 5,
  );

  static const ChessTimeControl rapid15_10 = ChessTimeControl(
    name: '15+10',
    baseSeconds: 900,
    incrementSeconds: 10,
  );

  static const ChessTimeControl unlimitedPreset = ChessTimeControl.unlimited();

  static const List<ChessTimeControl> standardPresets = [
    hyperbullet30s,
    bullet1_0,
    bullet1_1,
    bullet2_1,
    blitz3_0,
    blitz3_2,
    blitz5_0,
    blitz5_3,
    rapid10_0,
    rapid10_5,
    rapid15_10,
    unlimitedPreset,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessTimeControl &&
          runtimeType == other.runtimeType &&
          baseSeconds == other.baseSeconds &&
          incrementSeconds == other.incrementSeconds &&
          isUnlimited == other.isUnlimited;

  @override
  int get hashCode =>
      baseSeconds.hashCode ^ incrementSeconds.hashCode ^ isUnlimited.hashCode;
}
