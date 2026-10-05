import 'dart:math' as math;
import 'dart:ui';
import '../models/candidate_arrow.dart';
import '../models/chess_move.dart';
import '../models/chess_position.dart';
import 'board_geometry.dart';

/// Request input for an arrow's badge placement calculation.
class BadgeLayoutRequest {
  final CandidateArrow arrow;
  final Offset arrowStart;
  final Offset arrowEnd;
  final Offset arrowMid;
  final double arrowAngle;
  final double arrowHeadLength;
  final double arrowHeadWidth;
  final double badgeRadius;
  final double width;
  final double height;
  final Path? arrowPath;

  BadgeLayoutRequest({
    required this.arrow,
    required this.arrowStart,
    required this.arrowEnd,
    required this.arrowMid,
    required this.arrowAngle,
    required this.arrowHeadLength,
    required this.arrowHeadWidth,
    required this.badgeRadius,
    required this.width,
    required this.height,
    this.arrowPath,
  });
}

/// The collision-resolved placement for a badge.
class SolvedBadgePlacement {
  final CandidateArrow arrow;
  final Offset center;
  final Rect boundingBox;
  final double radius;
  final double width;
  final double height;
  final Offset leaderStart;
  final bool hasLeader;

  SolvedBadgePlacement({
    required this.arrow,
    required this.center,
    required this.boundingBox,
    required this.radius,
    required this.width,
    required this.height,
    required this.leaderStart,
    required this.hasLeader,
  });
}

/// Dedicated collision-aware layout engine for Nibbler candidate arrow badges.
///
/// Features:
/// 1. Prioritized placement by arrow rank (PV1 gets preferred anchor first).
/// 2. Multi-tier concentric candidate search around destination square and arrow shaft.
/// 3. Strict bounding box non-overlap guarantees between all badges.
/// 4. Strict board boundary containment (badges never clip edges).
/// 5. Piece-avoidance penalty so badges don't needlessly obscure pieces.
/// 6. Automatic subtle leader line connecting offset badges back to the arrow tip.
/// 7. Completely deterministic: zero random numbers, identical layouts for identical inputs.
class NibblerBadgeLayoutEngine {
  /// Solves non-overlapping badge positions for a set of candidate arrows.
  static List<SolvedBadgePlacement> layoutBadges({
    required List<BadgeLayoutRequest> requests,
    required BoardGeometry geometry,
    required ChessPosition position,
    double boardPadding = 4.0,
  }) {
    if (requests.isEmpty) return const [];

    final boardBounds = Rect.fromLTWH(
      boardPadding,
      boardPadding,
      geometry.boardSize - (boardPadding * 2.0),
      geometry.boardSize - (boardPadding * 2.0),
    );

    // Compute occupied piece bounding boxes (shrunk slightly to represent the piece visual footprint)
    final occupiedPieceRects = <Rect>[];
    for (int i = 0; i < 64; i++) {
      final sq = Square.fromIndex(i);
      if (position.pieceAt(sq) != null) {
        final sqRect = geometry.getSquareRect(sq);
        // Piece visual footprint: center 75% of square
        occupiedPieceRects.add(Rect.fromCenter(
          center: sqRect.center,
          width: sqRect.width * 0.75,
          height: sqRect.height * 0.75,
        ));
      }
    }

    // Sort requests by rank (PV1 first, then PV2, etc.) so best move gets top priority
    final sortedRequests = List<BadgeLayoutRequest>.from(requests)
      ..sort((a, b) => a.arrow.rank.compareTo(b.arrow.rank));

    final placed = <SolvedBadgePlacement>[];

    for (final req in sortedRequests) {
      final placement = _solveSingleBadge(
        req: req,
        placed: placed,
        boardBounds: boardBounds,
        occupiedPieceRects: occupiedPieceRects,
        allRequests: requests,
        geometry: geometry,
      );
      placed.add(placement);
    }

    return placed;
  }

  static SolvedBadgePlacement _solveSingleBadge({
    required BadgeLayoutRequest req,
    required List<SolvedBadgePlacement> placed,
    required Rect boardBounds,
    required List<Rect> occupiedPieceRects,
    required List<BadgeLayoutRequest> allRequests,
    required BoardGeometry geometry,
  }) {
    final badgeW = req.width;
    final badgeH = req.height;
    final badgeRadius = req.badgeRadius;

    final dx = req.arrowEnd.dx - req.arrowStart.dx;
    final dy = req.arrowEnd.dy - req.arrowStart.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final uX = dist > 0 ? dx / dist : 0.0;
    final uY = dist > 0 ? dy / dist : 0.0;
    final nX = -uY;
    final nY = uX;

    // Default anchor: positioned neatly near destination square without obscuring departure piece or arrowhead tip
    // If the arrow length is short (e.g. 1 square like e2-e3 or d2-d3), placing backwards along shaft can land on the departure piece.
    // Instead, anchor around 0.65..0.75 of the distance, or offset laterally if space is tight.
    final headClearance = req.arrowHeadLength + (badgeH * 0.45);
    final defaultT = dist > 0 ? (1.0 - (headClearance / dist)).clamp(0.40, 0.85) : 0.60;

    final oneMinusT = 1.0 - defaultT;
    final defaultAnchor = Offset(
      oneMinusT * oneMinusT * req.arrowStart.dx +
          2 * oneMinusT * defaultT * req.arrowMid.dx +
          defaultT * defaultT * req.arrowEnd.dx,
      oneMinusT * oneMinusT * req.arrowStart.dy +
          2 * oneMinusT * defaultT * req.arrowMid.dy +
          defaultT * defaultT * req.arrowEnd.dy,
    );

    // Generate candidate positions
    final candidates = <Offset>[];

    // Priority 0: Ideal shaft anchor
    candidates.add(defaultAnchor);

    // Priority 1: Perpendicular offsets from shaft anchor (both sides)
    final perpStep = badgeH * 0.95;
    candidates.add(Offset(defaultAnchor.dx + nX * perpStep, defaultAnchor.dy + nY * perpStep));
    candidates.add(Offset(defaultAnchor.dx - nX * perpStep, defaultAnchor.dy - nY * perpStep));

    // Priority 2: Radial offsets around arrow tip / destination square
    final tip = req.arrowEnd;
    final ringDistances = [
      badgeH * 0.95,
      badgeH * 1.50,
      badgeH * 2.10,
      badgeH * 2.80,
    ];

    // 8 cardinal and diagonal directions
    final angles = [
      0.0,
      math.pi / 4,
      math.pi / 2,
      3 * math.pi / 4,
      math.pi,
      -3 * math.pi / 4,
      -math.pi / 2,
      -math.pi / 4,
    ];

    for (final r in ringDistances) {
      for (final a in angles) {
        candidates.add(Offset(tip.dx + r * math.cos(a), tip.dy + r * math.sin(a)));
      }
    }

    // Priority 3: Along arrow shaft backwards towards start
    final shaftSteps = [0.65, 0.50, 0.35];
    for (final t in shaftSteps) {
      final omT = 1.0 - t;
      final shaftPt = Offset(
        omT * omT * req.arrowStart.dx + 2 * omT * t * req.arrowMid.dx + t * t * req.arrowEnd.dx,
        omT * omT * req.arrowStart.dy + 2 * omT * t * req.arrowMid.dy + t * t * req.arrowEnd.dy,
      );
      candidates.add(shaftPt);
      candidates.add(Offset(shaftPt.dx + nX * perpStep, shaftPt.dy + nY * perpStep));
      candidates.add(Offset(shaftPt.dx - nX * perpStep, shaftPt.dy - nY * perpStep));
    }

    Offset bestCenter = defaultAnchor;
    Rect bestRect = Rect.fromCenter(center: defaultAnchor, width: badgeW, height: badgeH);
    double lowestCost = double.infinity;

    for (int i = 0; i < candidates.length; i++) {
      final rawPt = candidates[i];
      // Board containment clamp
      final clampedX = rawPt.dx.clamp(
        boardBounds.left + badgeW / 2.0,
        boardBounds.right - badgeW / 2.0,
      );
      final clampedY = rawPt.dy.clamp(
        boardBounds.top + badgeH / 2.0,
        boardBounds.bottom - badgeH / 2.0,
      );
      final candidateCenter = Offset(clampedX, clampedY);
      final candidateRect = Rect.fromCenter(
        center: candidateCenter,
        width: badgeW,
        height: badgeH,
      );

      // 1. HARD CONSTRAINT: Must not overlap previously placed badges
      bool hasBadgeOverlap = false;
      double badgeOverlapArea = 0.0;
      for (final p in placed) {
        final intersection = candidateRect.intersect(p.boundingBox);
        if (intersection.width > 0 && intersection.height > 0) {
          hasBadgeOverlap = true;
          badgeOverlapArea += intersection.width * intersection.height;
        }
      }

      // If there is badge overlap, add a huge penalty
      double cost = 0.0;
      if (hasBadgeOverlap) {
        cost += 100000.0 + (badgeOverlapArea * 50.0);
      }

      // 2. SOFT PENALTY: Distance from defaultAnchor and destination tip
      final distToDefault = (candidateCenter - defaultAnchor).distance;
      final distToTip = (candidateCenter - tip).distance;
      cost += distToDefault * 1.5;
      cost += distToTip * 0.8;

      // Candidate index penalty (prefer earlier candidates)
      cost += i * 1.8;

      // 3. PIECE OVERLAP PENALTY: Avoid covering pieces
      bool overlapsPiece = false;
      for (final pieceRect in occupiedPieceRects) {
        final intersect = candidateRect.intersect(pieceRect);
        if (intersect.width > 0 && intersect.height > 0) {
          overlapsPiece = true;
          cost += 600.0 + (intersect.width * intersect.height * 0.8);
        }
      }

      // 4. TIP SHIELD PENALTY: Do not obscure the arrow's own arrowhead tip or notch!
      final tipDist = (candidateCenter - tip).distance;
      if (tipDist < req.arrowHeadLength * 0.65) {
        cost += 500.0;
      }

      // 5. EDGE PENALTY: Discourage placing badges flush against outer borders
      final distToEdgeX = math.min(candidateCenter.dx - boardBounds.left, boardBounds.right - candidateCenter.dx);
      final distToEdgeY = math.min(candidateCenter.dy - boardBounds.top, boardBounds.bottom - candidateCenter.dy);
      if (distToEdgeX < badgeW * 0.4 || distToEdgeY < badgeH * 0.4) {
        cost += 80.0;
      }

      if (cost < lowestCost) {
        lowestCost = cost;
        bestCenter = candidateCenter;
        bestRect = candidateRect;
        // Perfect non-overlapping candidate found in early pool with no piece overlap
        if (!hasBadgeOverlap && !overlapsPiece && i < 3) {
          break;
        }
      }
    }

    // Determine if leader line is warranted
    final offsetFromDefault = (bestCenter - defaultAnchor).distance;
    final hasLeader = offsetFromDefault > badgeRadius * 0.85;

    // Leader line connects from arrowhead base / tip towards closest edge of badge
    final leaderStart = req.arrowEnd;

    return SolvedBadgePlacement(
      arrow: req.arrow,
      center: bestCenter,
      boundingBox: bestRect,
      radius: badgeRadius,
      width: badgeW,
      height: badgeH,
      leaderStart: leaderStart,
      hasLeader: hasLeader,
    );
  }
}
