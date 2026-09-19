import 'package:shared_preferences/shared_preferences.dart';
import '../models/draft_variation.dart';
import '../models/engine_analysis.dart';
import '../models/chess_position.dart';

class PersistedSession {
  final String? fen;
  final String? pgn;
  final EngineType? activeEngine;
  final bool? isLiveAnalysisActive;
  final int? multiPv;
  final int? threads;
  final int? hashSizeMb;
  final ArrowheadType? arrowheadType;
  final ArrowFilterLc0? arrowFilterLc0;
  final ArrowFilterOthers? arrowFilterOthers;
  final bool? isFlipped;
  final int? selectedTab;
  final bool isDraftActive;
  final String? draftStartFen;
  final List<String>? draftPvMovesUci;
  final int? draftSelectedMoveIndex;

  const PersistedSession({
    this.fen,
    this.pgn,
    this.activeEngine,
    this.isLiveAnalysisActive,
    this.multiPv,
    this.threads,
    this.hashSizeMb,
    this.arrowheadType,
    this.arrowFilterLc0,
    this.arrowFilterOthers,
    this.isFlipped,
    this.selectedTab,
    this.isDraftActive = false,
    this.draftStartFen,
    this.draftPvMovesUci,
    this.draftSelectedMoveIndex,
  });

  /// Reconstructs a [DraftVariation] deterministically from persisted primitives.
  DraftVariation? reconstructDraftVariation() {
    if (!isDraftActive || draftStartFen == null || draftPvMovesUci == null || draftPvMovesUci!.isEmpty) {
      return null;
    }

    try {
      final rootPos = ChessPosition.fromFen(draftStartFen!);
      final pvItems = SANFormatter.parsePvLine(rootPos, draftPvMovesUci!);
      if (pvItems.isEmpty) return null;

      final pvLine = PvLine(
        multipv: 1,
        scoreCp: null,
        scoreMate: null,
        winPercentage: 50.0,
        whiteWinPercentage: 50.0,
        expectedScore: 50.0,
        whiteExpectedScore: 50.0,
        wdl: null,
        movesUci: draftPvMovesUci!,
        movesSan: pvItems.map((m) => m.san).toList(),
        pvMoves: pvItems,
        startFen: draftStartFen!,
        depth: 0,
        seldepth: 0,
        nodes: 0,
        nps: 0,
      );

      return DraftVariation(
        startFen: draftStartFen!,
        rootPosition: rootPos,
        pvLine: pvLine,
        selectedMoveIndex: draftSelectedMoveIndex ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class SessionPersistenceService {
  static const _kFen = 'session_fen';
  static const _kPgn = 'session_pgn';
  static const _kEngine = 'session_engine';
  static const _kEngineActive = 'session_engine_active';
  static const _kMultiPv = 'session_multipv';
  static const _kThreads = 'session_threads';
  static const _kHashMb = 'session_hash_mb';
  static const _kArrowhead = 'session_arrowhead';
  static const _kArrowFilterLc0 = 'session_arrow_filter_lc0';
  static const _kArrowFilterOthers = 'session_arrow_filter_others';
  static const _kFlipped = 'session_flipped';
  static const _kSelectedTab = 'session_tab';
  static const _kDraftActive = 'session_draft_active';
  static const _kDraftStartFen = 'session_draft_start_fen';
  static const _kDraftPvMoves = 'session_draft_pv_moves';
  static const _kDraftMoveIndex = 'session_draft_move_index';

  static Future<void> saveSession({
    required String fen,
    String? pgn,
    required EngineType activeEngine,
    required bool isLiveAnalysisActive,
    required int multiPv,
    int? threads,
    int? hashSizeMb,
    required ArrowheadType arrowheadType,
    required ArrowFilterLc0 arrowFilterLc0,
    required ArrowFilterOthers arrowFilterOthers,
    required bool isFlipped,
    required int selectedTab,
    DraftVariation? draftVariation,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFen, fen);
      if (pgn != null && pgn.isNotEmpty) {
        await prefs.setString(_kPgn, pgn);
      }
      await prefs.setString(_kEngine, activeEngine.name);
      await prefs.setBool(_kEngineActive, isLiveAnalysisActive);
      await prefs.setInt(_kMultiPv, multiPv);
      if (threads != null) await prefs.setInt(_kThreads, threads);
      if (hashSizeMb != null) await prefs.setInt(_kHashMb, hashSizeMb);
      await prefs.setString(_kArrowhead, arrowheadType.name);
      await prefs.setString(_kArrowFilterLc0, arrowFilterLc0.name);
      await prefs.setString(_kArrowFilterOthers, arrowFilterOthers.name);
      await prefs.setBool(_kFlipped, isFlipped);
      await prefs.setInt(_kSelectedTab, selectedTab);

      if (draftVariation != null) {
        await prefs.setBool(_kDraftActive, true);
        await prefs.setString(_kDraftStartFen, draftVariation.startFen);
        await prefs.setStringList(_kDraftPvMoves, draftVariation.pvLine.movesUci);
        await prefs.setInt(_kDraftMoveIndex, draftVariation.selectedMoveIndex);
      } else {
        await prefs.setBool(_kDraftActive, false);
        await prefs.remove(_kDraftStartFen);
        await prefs.remove(_kDraftPvMoves);
        await prefs.remove(_kDraftMoveIndex);
      }
    } catch (_) {
      // Non-blocking persistence failure
    }
  }

  static Future<PersistedSession?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fen = prefs.getString(_kFen);
      if (fen == null) return null;

      final pgn = prefs.getString(_kPgn);
      final engineName = prefs.getString(_kEngine);
      final isEngineActive = prefs.getBool(_kEngineActive);
      final multiPv = prefs.getInt(_kMultiPv);
      final threads = prefs.getInt(_kThreads);
      final hashSizeMb = prefs.getInt(_kHashMb);
      final arrowheadName = prefs.getString(_kArrowhead);
      final arrowFilterLc0Name = prefs.getString(_kArrowFilterLc0);
      final arrowFilterOthersName = prefs.getString(_kArrowFilterOthers);
      final isFlipped = prefs.getBool(_kFlipped);
      final selectedTab = prefs.getInt(_kSelectedTab);

      EngineType? engine;
      if (engineName != null) {
        for (final e in EngineType.values) {
          if (e.name == engineName) {
            engine = e;
            break;
          }
        }
      }

      ArrowheadType? arrowhead;
      if (arrowheadName != null) {
        for (final a in ArrowheadType.values) {
          if (a.name == arrowheadName) {
            arrowhead = a;
            break;
          }
        }
      }

      ArrowFilterLc0? filterLc0;
      if (arrowFilterLc0Name != null) {
        for (final f in ArrowFilterLc0.values) {
          if (f.name == arrowFilterLc0Name) {
            filterLc0 = f;
            break;
          }
        }
      }

      ArrowFilterOthers? filterOthers;
      if (arrowFilterOthersName != null) {
        for (final f in ArrowFilterOthers.values) {
          if (f.name == arrowFilterOthersName) {
            filterOthers = f;
            break;
          }
        }
      }

      final draftActive = prefs.getBool(_kDraftActive) ?? false;
      final draftStartFen = prefs.getString(_kDraftStartFen);
      final draftPvMoves = prefs.getStringList(_kDraftPvMoves);
      final draftMoveIndex = prefs.getInt(_kDraftMoveIndex);

      return PersistedSession(
        fen: fen,
        pgn: pgn,
        activeEngine: engine,
        isLiveAnalysisActive: isEngineActive,
        multiPv: multiPv,
        threads: threads,
        hashSizeMb: hashSizeMb,
        arrowheadType: arrowhead,
        arrowFilterLc0: filterLc0,
        arrowFilterOthers: filterOthers,
        isFlipped: isFlipped,
        selectedTab: selectedTab,
        isDraftActive: draftActive,
        draftStartFen: draftStartFen,
        draftPvMovesUci: draftPvMoves,
        draftSelectedMoveIndex: draftMoveIndex,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kFen);
      await prefs.remove(_kPgn);
      await prefs.remove(_kDraftActive);
      await prefs.remove(_kDraftStartFen);
      await prefs.remove(_kDraftPvMoves);
      await prefs.remove(_kDraftMoveIndex);
    } catch (_) {}
  }
}
