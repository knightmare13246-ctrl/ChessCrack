import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chess_position.dart';
import '../models/draft_variation.dart';
import '../models/engine_analysis.dart';
import '../models/engine_download_model.dart';

typedef PersistedSession = PersistedAppState;

class PersistedAppState {
  // Schema
  final int schemaVersion;

  // Appearance
  final String boardThemeId;
  final String pieceSet;
  final bool showCoordinates;
  final bool isFlipped;
  final int pieceAnimationMs;

  // Audio
  final bool soundEnabled;
  final String soundTheme;
  final double soundVolume;
  final bool hapticsEnabled;

  // Analysis
  final EngineType activeEngine;
  final bool isLiveAnalysisActive;
  final int multiPv;
  final ArrowheadType arrowheadType;
  final ArrowFilterLc0 arrowFilterLc0;
  final ArrowFilterOthers arrowFilterOthers;
  final Set<String> infoboxStats;

  // Engine Profiles: Stockfish
  final int stockfishThreads;
  final int stockfishHashMb;

  // Engine Profiles: Lc0 & Maia
  final String? selectedMaiaId;
  final String? selectedNetworkPath;
  final String lc0Backend;
  final int lc0Threads;
  final int lc0HashMb;
  final Map<String, MaiaProfile> maiaProfiles;

  // Game / Session
  final String fen;
  final String? pgn;
  final int selectedTab;
  final bool isDraftActive;
  final String? draftStartFen;
  final List<String>? draftPvMovesUci;
  final int? draftSelectedMoveIndex;

  const PersistedAppState({
    this.schemaVersion = 2,
    this.boardThemeId = 'brown',
    this.pieceSet = 'cburnett',
    this.showCoordinates = true,
    this.isFlipped = false,
    this.pieceAnimationMs = 200,
    this.soundEnabled = true,
    this.soundTheme = 'standard',
    this.soundVolume = 1.0,
    this.hapticsEnabled = true,
    this.activeEngine = EngineType.stockfish,
    this.isLiveAnalysisActive = true,
    this.multiPv = 3,
    this.arrowheadType = ArrowheadType.winrate,
    this.arrowFilterLc0 = ArrowFilterLc0.all,
    this.arrowFilterOthers = ArrowFilterOthers.all,
    this.infoboxStats = const {
      'winrate',
      'nodePct',
      'policy',
      'multipv',
      'movesLeft',
      'depth',
      'nodes',
      'nps',
      'wdl',
    },
    this.stockfishThreads = 1,
    this.stockfishHashMb = 16,
    this.selectedMaiaId,
    this.selectedNetworkPath,
    this.lc0Backend = 'auto',
    this.lc0Threads = 1,
    this.lc0HashMb = 16,
    this.maiaProfiles = const {},
    this.fen = ChessPosition.initialFen,
    this.pgn,
    this.selectedTab = 0,
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

  MaiaProfile getProfileForMaia(String maiaId, int elo) {
    if (maiaProfiles.containsKey(maiaId)) {
      return maiaProfiles[maiaId]!;
    }
    return MaiaProfile(
      modelId: maiaId,
      approximateElo: elo,
      nodes: 1, // Official requirement: Run at Nodes = 1
      backend: 'auto',
      threads: 1,
    );
  }
}

class SessionPersistenceService {
  static const int currentSchemaVersion = 2;

  // Keys
  static const _kSchemaVersion = 'chesscrack_schema_version';
  static const _kBoardTheme = 'chesscrack_board_theme';
  static const _kPieceSet = 'chesscrack_piece_set';
  static const _kShowCoords = 'chesscrack_show_coords';
  static const _kIsFlipped = 'chesscrack_is_flipped';
  static const _kAnimMs = 'chesscrack_anim_ms';

  static const _kSoundEnabled = 'chesscrack_sound_enabled';
  static const _kSoundTheme = 'chesscrack_sound_theme';
  static const _kSoundVolume = 'chesscrack_sound_volume';
  static const _kHapticsEnabled = 'chesscrack_haptics_enabled';

  static const _kActiveEngine = 'chesscrack_active_engine';
  static const _kEngineActive = 'chesscrack_engine_active';
  static const _kMultiPv = 'chesscrack_multipv';
  static const _kArrowhead = 'chesscrack_arrowhead';
  static const _kArrowFilterLc0 = 'chesscrack_arrow_filter_lc0';
  static const _kArrowFilterOthers = 'chesscrack_arrow_filter_others';
  static const _kInfoboxStats = 'chesscrack_infobox_stats';

  static const _kSfThreads = 'chesscrack_sf_threads';
  static const _kSfHash = 'chesscrack_sf_hash';

  static const _kLc0MaiaId = 'chesscrack_lc0_maia_id';
  static const _kLc0NetworkPath = 'chesscrack_lc0_network_path';
  static const _kLc0Backend = 'chesscrack_lc0_backend';
  static const _kLc0Threads = 'chesscrack_lc0_threads';
  static const _kLc0Hash = 'chesscrack_lc0_hash';
  static const _kMaiaProfilesJson = 'chesscrack_maia_profiles_json';

  static const _kFen = 'chesscrack_fen';
  static const _kPgn = 'chesscrack_pgn';
  static const _kSelectedTab = 'chesscrack_selected_tab';
  static const _kDraftActive = 'chesscrack_draft_active';
  static const _kDraftStartFen = 'chesscrack_draft_start_fen';
  static const _kDraftPvMoves = 'chesscrack_draft_pv_moves';
  static const _kDraftMoveIndex = 'chesscrack_draft_move_index';

  static Future<void> saveAppState(PersistedAppState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kSchemaVersion, currentSchemaVersion);

      // Appearance
      await prefs.setString(_kBoardTheme, state.boardThemeId);
      await prefs.setString(_kPieceSet, state.pieceSet);
      await prefs.setBool(_kShowCoords, state.showCoordinates);
      await prefs.setBool(_kIsFlipped, state.isFlipped);
      await prefs.setInt(_kAnimMs, state.pieceAnimationMs);

      // Audio
      await prefs.setBool(_kSoundEnabled, state.soundEnabled);
      await prefs.setString(_kSoundTheme, state.soundTheme);
      await prefs.setDouble(_kSoundVolume, state.soundVolume);
      await prefs.setBool(_kHapticsEnabled, state.hapticsEnabled);

      // Analysis
      await prefs.setString(_kActiveEngine, state.activeEngine.name);
      await prefs.setBool(_kEngineActive, state.isLiveAnalysisActive);
      await prefs.setInt(_kMultiPv, state.multiPv);
      await prefs.setString(_kArrowhead, state.arrowheadType.name);
      await prefs.setString(_kArrowFilterLc0, state.arrowFilterLc0.name);
      await prefs.setString(_kArrowFilterOthers, state.arrowFilterOthers.name);
      await prefs.setStringList(_kInfoboxStats, state.infoboxStats.toList());

      // Engine Profiles
      await prefs.setInt(_kSfThreads, state.stockfishThreads);
      await prefs.setInt(_kSfHash, state.stockfishHashMb);

      if (state.selectedMaiaId != null) {
        await prefs.setString(_kLc0MaiaId, state.selectedMaiaId!);
      } else {
        await prefs.remove(_kLc0MaiaId);
      }

      if (state.selectedNetworkPath != null) {
        await prefs.setString(_kLc0NetworkPath, state.selectedNetworkPath!);
      } else {
        await prefs.remove(_kLc0NetworkPath);
      }

      await prefs.setString(_kLc0Backend, state.lc0Backend);
      await prefs.setInt(_kLc0Threads, state.lc0Threads);
      await prefs.setInt(_kLc0Hash, state.lc0HashMb);

      // Per-Maia profiles map serialized to JSON
      final profilesMap = <String, dynamic>{};
      for (final entry in state.maiaProfiles.entries) {
        profilesMap[entry.key] = entry.value.toJson();
      }
      await prefs.setString(_kMaiaProfilesJson, jsonEncode(profilesMap));

      // Game / Session
      await prefs.setString(_kFen, state.fen);
      if (state.pgn != null && state.pgn!.isNotEmpty) {
        await prefs.setString(_kPgn, state.pgn!);
      }
      await prefs.setInt(_kSelectedTab, state.selectedTab);

      if (state.isDraftActive && state.draftStartFen != null && state.draftPvMovesUci != null) {
        await prefs.setBool(_kDraftActive, true);
        await prefs.setString(_kDraftStartFen, state.draftStartFen!);
        await prefs.setStringList(_kDraftPvMoves, state.draftPvMovesUci!);
        await prefs.setInt(_kDraftMoveIndex, state.draftSelectedMoveIndex ?? 0);
      } else {
        await prefs.setBool(_kDraftActive, false);
        await prefs.remove(_kDraftStartFen);
        await prefs.remove(_kDraftPvMoves);
        await prefs.remove(_kDraftMoveIndex);
      }
    } catch (_) {}
  }

  static Future<PersistedAppState> loadAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Legacy migration: check old keys if new keys are missing
      final storedSchema = prefs.getInt(_kSchemaVersion) ?? 1;

      // Appearance
      final boardTheme = prefs.getString(_kBoardTheme) ?? 'brown';
      final pieceSet = prefs.getString(_kPieceSet) ?? 'cburnett';
      final showCoords = prefs.getBool(_kShowCoords) ?? true;
      final isFlipped = prefs.getBool(_kIsFlipped) ?? prefs.getBool('session_flipped') ?? false;
      final animMs = prefs.getInt(_kAnimMs) ?? 200;

      // Audio
      final soundEnabled = prefs.getBool(_kSoundEnabled) ?? true;
      final soundTheme = prefs.getString(_kSoundTheme) ?? 'standard';
      final soundVolume = prefs.getDouble(_kSoundVolume) ?? 1.0;
      final hapticsEnabled = prefs.getBool(_kHapticsEnabled) ?? true;

      // Analysis
      final engineStr = prefs.getString(_kActiveEngine) ?? prefs.getString('session_engine');
      final activeEngine = EngineType.values.firstWhere(
        (e) => e.name == engineStr,
        orElse: () => EngineType.stockfish,
      );

      final isEngineActive = prefs.getBool(_kEngineActive) ?? prefs.getBool('session_engine_active') ?? true;
      final multiPv = prefs.getInt(_kMultiPv) ?? prefs.getInt('session_multipv') ?? 3;

      final arrowStr = prefs.getString(_kArrowhead) ?? prefs.getString('session_arrowhead');
      final arrowhead = ArrowheadType.values.firstWhere(
        (a) => a.name == arrowStr,
        orElse: () => ArrowheadType.winrate,
      );

      final filterLc0Str = prefs.getString(_kArrowFilterLc0) ?? prefs.getString('session_arrow_filter_lc0');
      final filterLc0 = ArrowFilterLc0.values.firstWhere(
        (f) => f.name == filterLc0Str,
        orElse: () => ArrowFilterLc0.all,
      );

      final filterOthersStr = prefs.getString(_kArrowFilterOthers) ?? prefs.getString('session_arrow_filter_others');
      final filterOthers = ArrowFilterOthers.values.firstWhere(
        (f) => f.name == filterOthersStr,
        orElse: () => ArrowFilterOthers.all,
      );

      final infoStatsList = prefs.getStringList(_kInfoboxStats);
      final infoboxStats = infoStatsList != null
          ? Set<String>.from(infoStatsList)
          : const {
              'winrate',
              'nodePct',
              'policy',
              'multipv',
              'movesLeft',
              'depth',
              'nodes',
              'nps',
              'wdl',
            };

      // Engine Profiles
      final sfThreads = prefs.getInt(_kSfThreads) ?? prefs.getInt('session_threads') ?? 1;
      final sfHash = prefs.getInt(_kSfHash) ?? prefs.getInt('session_hash_mb') ?? 16;

      final lc0MaiaId = prefs.getString(_kLc0MaiaId);
      final lc0NetworkPath = prefs.getString(_kLc0NetworkPath);
      final lc0Backend = prefs.getString(_kLc0Backend) ?? 'auto';
      final lc0Threads = prefs.getInt(_kLc0Threads) ?? 1;
      final lc0Hash = prefs.getInt(_kLc0Hash) ?? 16;

      // Maia profiles
      final Map<String, MaiaProfile> maiaProfiles = {};
      final profilesJsonStr = prefs.getString(_kMaiaProfilesJson);
      if (profilesJsonStr != null) {
        try {
          final decoded = jsonDecode(profilesJsonStr) as Map<String, dynamic>;
          for (final entry in decoded.entries) {
            maiaProfiles[entry.key] = MaiaProfile.fromJson(entry.value as Map<String, dynamic>);
          }
        } catch (_) {}
      }

      // Game / Session
      final fen = prefs.getString(_kFen) ?? prefs.getString('session_fen') ?? ChessPosition.initialFen;
      final pgn = prefs.getString(_kPgn) ?? prefs.getString('session_pgn');
      final selectedTab = prefs.getInt(_kSelectedTab) ?? prefs.getInt('session_tab') ?? 0;

      final draftActive = prefs.getBool(_kDraftActive) ?? prefs.getBool('session_draft_active') ?? false;
      final draftStartFen = prefs.getString(_kDraftStartFen) ?? prefs.getString('session_draft_start_fen');
      final draftPvMoves = prefs.getStringList(_kDraftPvMoves) ?? prefs.getStringList('session_draft_pv_moves');
      final draftMoveIndex = prefs.getInt(_kDraftMoveIndex) ?? prefs.getInt('session_draft_move_index');

      return PersistedAppState(
        schemaVersion: storedSchema,
        boardThemeId: boardTheme,
        pieceSet: pieceSet,
        showCoordinates: showCoords,
        isFlipped: isFlipped,
        pieceAnimationMs: animMs,
        soundEnabled: soundEnabled,
        soundTheme: soundTheme,
        soundVolume: soundVolume,
        hapticsEnabled: hapticsEnabled,
        activeEngine: activeEngine,
        isLiveAnalysisActive: isEngineActive,
        multiPv: multiPv,
        arrowheadType: arrowhead,
        arrowFilterLc0: filterLc0,
        arrowFilterOthers: filterOthers,
        infoboxStats: infoboxStats,
        stockfishThreads: sfThreads,
        stockfishHashMb: sfHash,
        selectedMaiaId: lc0MaiaId,
        selectedNetworkPath: lc0NetworkPath,
        lc0Backend: lc0Backend,
        lc0Threads: lc0Threads,
        lc0HashMb: lc0Hash,
        maiaProfiles: maiaProfiles,
        fen: fen,
        pgn: pgn,
        selectedTab: selectedTab,
        isDraftActive: draftActive,
        draftStartFen: draftStartFen,
        draftPvMovesUci: draftPvMoves,
        draftSelectedMoveIndex: draftMoveIndex,
      );
    } catch (_) {
      return const PersistedAppState();
    }
  }

  /// Legacy helper for test compatibility
  static Future<void> saveSession({
    required String fen,
    String? pgn,
    required EngineType activeEngine,
    required bool isLiveAnalysisActive,
    required int multiPv,
    required ArrowheadType arrowheadType,
    required ArrowFilterLc0 arrowFilterLc0,
    required ArrowFilterOthers arrowFilterOthers,
    required bool isFlipped,
    required int selectedTab,
    required DraftVariation? draftVariation,
  }) async {
    final state = PersistedAppState(
      fen: fen,
      pgn: pgn,
      activeEngine: activeEngine,
      isLiveAnalysisActive: isLiveAnalysisActive,
      multiPv: multiPv,
      arrowheadType: arrowheadType,
      arrowFilterLc0: arrowFilterLc0,
      arrowFilterOthers: arrowFilterOthers,
      isFlipped: isFlipped,
      selectedTab: selectedTab,
      isDraftActive: draftVariation != null,
      draftStartFen: draftVariation?.startFen,
      draftPvMovesUci: draftVariation?.pvLine.movesUci,
      draftSelectedMoveIndex: draftVariation?.selectedMoveIndex,
    );
    await saveAppState(state);
  }

  /// Legacy helper for test compatibility
  static Future<PersistedAppState?> loadSession() async {
    return await loadAppState();
  }
}
