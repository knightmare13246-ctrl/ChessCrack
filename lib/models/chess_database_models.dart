import 'package:flutter/material.dart';

/// Database Metadata entity for UI display and organization.
class ChessDatabase {
  final int id;
  final String name;
  final String description;
  final String category;
  final int colorValue;
  final String icon;
  final int gameCount;
  final String indexMode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isReference;

  const ChessDatabase({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'custom',
    this.colorValue = 0xFF2196F3,
    this.icon = 'folder',
    this.gameCount = 0,
    this.indexMode = 'balanced',
    required this.createdAt,
    required this.updatedAt,
    this.isReference = false,
  });

  Color get color => Color(colorValue);

  factory ChessDatabase.fromJson(Map<String, dynamic> json) {
    return ChessDatabase(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'custom',
      colorValue: json['color'] as int? ?? 0xFF2196F3,
      icon: json['icon'] as String? ?? 'folder',
      gameCount: json['gameCount'] as int? ?? 0,
      indexMode: json['indexMode'] as String? ?? 'balanced',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int? ?? 0),
      isReference: json['isReference'] as bool? ?? false,
    );
  }
}

/// Compact Game Summary entity for high-speed paginated list views.
class GameSummary {
  final int id;
  final String white;
  final String black;
  final int? whiteElo;
  final int? blackElo;
  final String result;
  final String event;
  final String site;
  final String date;
  final String round;
  final String? eco;
  final String? opening;
  final String? variation;
  final int plyCount;
  final int flags;
  final bool favorite;

  const GameSummary({
    required this.id,
    required this.white,
    required this.black,
    this.whiteElo,
    this.blackElo,
    required this.result,
    required this.event,
    required this.site,
    required this.date,
    required this.round,
    this.eco,
    this.opening,
    this.variation,
    required this.plyCount,
    required this.flags,
    this.favorite = false,
  });

  bool get hasComments => (flags & 1) != 0;
  bool get hasVariations => (flags & 2) != 0;
  bool get hasNags => (flags & 4) != 0;
  bool get hasCustomFen => (flags & 8) != 0;

  int get moveCount => (plyCount + 1) ~/ 2;

  String get year {
    if (date.length >= 4) {
      final y = date.substring(0, 4);
      if (y != '????') return y;
    }
    return '';
  }

  factory GameSummary.fromJson(Map<String, dynamic> json) {
    return GameSummary(
      id: json['id'] as int,
      white: json['white'] as String? ?? '?',
      black: json['black'] as String? ?? '?',
      whiteElo: json['whiteElo'] as int?,
      blackElo: json['blackElo'] as int?,
      result: json['result'] as String? ?? '*',
      event: json['event'] as String? ?? '?',
      site: json['site'] as String? ?? '?',
      date: json['date'] as String? ?? '????.??.??',
      round: json['round'] as String? ?? '?',
      eco: json['eco'] as String?,
      opening: json['opening'] as String?,
      variation: json['variation'] as String?,
      plyCount: json['plyCount'] as int? ?? 0,
      flags: json['flags'] as int? ?? 0,
      favorite: json['favorite'] as bool? ?? false,
    );
  }
}
