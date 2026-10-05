import 'package:flutter/material.dart';
import 'candidate_arrow.dart';
import 'engine_analysis.dart';

/// Clean, typed configuration model dedicated strictly to Nibbler Candidate Arrows.
///
/// Modifying candidate arrow settings affects ONLY candidate arrows and never
/// leaks into maneuver/plan arrows or user interaction arrows.
class NibblerCandidateArrowConfig {
  final bool enabled;
  final ArrowheadType arrowheadType;
  final ArrowFilterLc0 arrowFilterLc0;
  final ArrowFilterOthers arrowFilterOthers;
  final double arrowOpacity;
  final double curveAmount;
  final double minStrokeWidth;
  final bool showActualMove;
  final bool actualMoveUniqueColor;
  final bool actualMoveOutline;

  const NibblerCandidateArrowConfig({
    this.enabled = true,
    this.arrowheadType = ArrowheadType.winrate,
    this.arrowFilterLc0 = ArrowFilterLc0.all,
    this.arrowFilterOthers = ArrowFilterOthers.all,
    this.arrowOpacity = 0.95,
    this.curveAmount = 1.0,
    this.minStrokeWidth = 3.2,
    this.showActualMove = false,
    this.actualMoveUniqueColor = false,
    this.actualMoveOutline = false,
  });

  NibblerCandidateArrowConfig copyWith({
    bool? enabled,
    ArrowheadType? arrowheadType,
    ArrowFilterLc0? arrowFilterLc0,
    ArrowFilterOthers? arrowFilterOthers,
    double? arrowOpacity,
    double? curveAmount,
    double? minStrokeWidth,
    bool? showActualMove,
    bool? actualMoveUniqueColor,
    bool? actualMoveOutline,
  }) {
    return NibblerCandidateArrowConfig(
      enabled: enabled ?? this.enabled,
      arrowheadType: arrowheadType ?? this.arrowheadType,
      arrowFilterLc0: arrowFilterLc0 ?? this.arrowFilterLc0,
      arrowFilterOthers: arrowFilterOthers ?? this.arrowFilterOthers,
      arrowOpacity: arrowOpacity ?? this.arrowOpacity,
      curveAmount: curveAmount ?? this.curveAmount,
      minStrokeWidth: minStrokeWidth ?? this.minStrokeWidth,
      showActualMove: showActualMove ?? this.showActualMove,
      actualMoveUniqueColor: actualMoveUniqueColor ?? this.actualMoveUniqueColor,
      actualMoveOutline: actualMoveOutline ?? this.actualMoveOutline,
    );
  }
}

/// Clean, typed configuration dedicated strictly to Piece Maneuver / Continuation Plan Arrows.
///
/// Isolated completely from MultiPV candidate settings, filters, and arrowhead modes.
class PieceManeuverConfig {
  final bool enabled;
  final int depthPlies;
  final PvContinuationFilter filter;
  final double opacity;
  final bool showStepNumbers;
  final Color opponentColor;

  const PieceManeuverConfig({
    this.enabled = false,
    this.depthPlies = 4,
    this.filter = PvContinuationFilter.all,
    this.opacity = 0.85,
    this.showStepNumbers = true,
    this.opponentColor = const Color(0xFFFFB74D),
  });

  PieceManeuverConfig copyWith({
    bool? enabled,
    int? depthPlies,
    PvContinuationFilter? filter,
    double? opacity,
    bool? showStepNumbers,
    Color? opponentColor,
  }) {
    return PieceManeuverConfig(
      enabled: enabled ?? this.enabled,
      depthPlies: depthPlies ?? this.depthPlies,
      filter: filter ?? this.filter,
      opacity: opacity ?? this.opacity,
      showStepNumbers: showStepNumbers ?? this.showStepNumbers,
      opponentColor: opponentColor ?? this.opponentColor,
    );
  }
}

/// Clean, typed configuration for user manual interaction drawings.
class UserArrowConfig {
  final bool enabled;
  final Color defaultColor;
  final double strokeWidth;

  const UserArrowConfig({
    this.enabled = true,
    this.defaultColor = const Color(0xFF00D2BE),
    this.strokeWidth = 4.0,
  });

  UserArrowConfig copyWith({
    bool? enabled,
    Color? defaultColor,
    double? strokeWidth,
  }) {
    return UserArrowConfig(
      enabled: enabled ?? this.enabled,
      defaultColor: defaultColor ?? this.defaultColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }
}
