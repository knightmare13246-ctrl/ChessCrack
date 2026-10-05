import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// Native function typedefs
typedef _CcOpenC = ffi.Int64 Function(ffi.Pointer<Utf8> path);
typedef _CcOpenDart = int Function(ffi.Pointer<Utf8> path);

typedef _CcRequestC = ffi.Pointer<Utf8> Function(ffi.Int64 handle, ffi.Pointer<Utf8> jsonReq);
typedef _CcRequestDart = ffi.Pointer<Utf8> Function(int handle, ffi.Pointer<Utf8> jsonReq);

typedef _CcLastErrorC = ffi.Pointer<Utf8> Function();
typedef _CcLastErrorDart = ffi.Pointer<Utf8> Function();

typedef _CcCloseC = ffi.Void Function(ffi.Int64 handle);
typedef _CcCloseDart = void Function(int handle);

typedef _CcFreeC = ffi.Void Function(ffi.Pointer<Utf8> ptr);
typedef _CcFreeDart = void Function(ffi.Pointer<Utf8> ptr);

/// High-performance FFI bridge to `chesscrack_core`.
///
/// Features:
/// - Coarse-grained JSON messages (zero chatty FFI roundtrips)
/// - Asynchronous jobs with cancellation & polled progress
/// - Single persistent SQLite database for the entire library
/// - Safe crash/panic isolation with structured error propagation
class ChessCrackCore {
  static final ChessCrackCore instance = ChessCrackCore._internal();
  ChessCrackCore._internal();

  ffi.DynamicLibrary? _lib;
  _CcOpenDart? _ccOpen;
  _CcRequestDart? _ccRequest;
  _CcLastErrorDart? _ccLastError;
  _CcCloseDart? _ccClose;
  _CcFreeDart? _ccFree;

  int _handle = 0;
  bool _initialized = false;
  String? _dbPath;

  bool get isAvailable => _lib != null && _handle > 0;
  bool get isInitialized => _initialized && _handle > 0;
  String? get dbPath => _dbPath;

  /// Loads the native library and initializes the library database.
  Future<void> init([String? customDbPath]) async {
    if (_initialized && _handle > 0) return;

    try {
      _lib = _loadLibrary();
      _ccOpen = _lib!.lookupFunction<_CcOpenC, _CcOpenDart>('cc_open');
      _ccRequest = _lib!.lookupFunction<_CcRequestC, _CcRequestDart>('cc_request');
      _ccLastError = _lib!.lookupFunction<_CcLastErrorC, _CcLastErrorDart>('cc_last_error');
      _ccClose = _lib!.lookupFunction<_CcCloseC, _CcCloseDart>('cc_close');
      _ccFree = _lib!.lookupFunction<_CcFreeC, _CcFreeDart>('cc_free');

      String path = customDbPath ?? '';
      if (path.isEmpty) {
        final docs = await getApplicationDocumentsDirectory();
        final dbDir = Directory('${docs.path}${Platform.pathSeparator}database');
        if (!dbDir.existsSync()) {
          dbDir.createSync(recursive: true);
        }
        path = '${dbDir.path}${Platform.pathSeparator}chesscrack_library.db';
      }
      _dbPath = path;

      final pathPtr = path.toNativeUtf8();
      try {
        _handle = _ccOpen!(pathPtr);
      } finally {
        calloc.free(pathPtr);
      }

      if (_handle == 0) {
        final errPtr = _ccLastError!();
        final errStr = errPtr.toDartString();
        _ccFree!(errPtr);
        throw StateError('Failed to open ChessCrack core database: $errStr');
      }

      _initialized = true;

      // Ensure default "My Games" database exists
      await _ensureDefaultDatabase();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ChessCrackCore] Failed to load/open native core: $e\n$st');
      }
      rethrow;
    }
  }

  static ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      try {
        return ffi.DynamicLibrary.open('libchesscrack_core.so');
      } catch (_) {
        return ffi.DynamicLibrary.process();
      }
    } else if (Platform.isWindows) {
      // Check adjacent target paths during development/tests
      final candidatePaths = [
        'rust/chesscrack_core/target/release/chesscrack_core.dll',
        'rust/chesscrack_core/target/debug/chesscrack_core.dll',
        'chesscrack_core.dll',
      ];
      for (final p in candidatePaths) {
        if (File(p).existsSync()) {
          return ffi.DynamicLibrary.open(p);
        }
      }
      return ffi.DynamicLibrary.open('chesscrack_core.dll');
    } else if (Platform.isLinux) {
      return ffi.DynamicLibrary.open('libchesscrack_core.so');
    } else if (Platform.isMacOS || Platform.isIOS) {
      return ffi.DynamicLibrary.process();
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Sends a synchronous request to the Rust core on the shared handle.
  dynamic request(Map<String, dynamic> req) {
    if (_handle == 0 || _ccRequest == null || _ccFree == null) {
      throw StateError('ChessCrack core is not initialized');
    }

    final jsonStr = jsonEncode(req);
    final reqPtr = jsonStr.toNativeUtf8();
    ffi.Pointer<Utf8>? resPtr;
    try {
      resPtr = _ccRequest!(_handle, reqPtr);
      final resStr = resPtr.toDartString();
      final decoded = jsonDecode(resStr) as Map<String, dynamic>;
      if (decoded.containsKey('error')) {
        throw StateError(decoded['error'].toString());
      }
      return decoded['ok'];
    } finally {
      calloc.free(reqPtr);
      if (resPtr != null) {
        _ccFree!(resPtr);
      }
    }
  }

  // --- Convenience API Methods ---

  Future<void> _ensureDefaultDatabase() async {
    final dbs = await listDatabases();
    if (dbs.isEmpty) {
      await createDatabase(
        name: 'My Games',
        category: 'my_games',
        color: 0xFF2196F3, // Vibrant Blue
        icon: 'person',
        description: 'Personal games, analysis and training',
      );
    }
  }

  Future<List<Map<String, dynamic>>> listDatabases() async {
    final res = request({'op': 'list_databases'});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<int> createDatabase({
    required String name,
    String category = 'custom',
    int color = 0xFF4CAF50,
    String icon = 'folder',
    String description = '',
  }) async {
    final res = request({
      'op': 'create_database',
      'name': name,
      'category': category,
      'color': color,
      'icon': icon,
      'description': description,
    });
    return (res as Map)['id'] as int;
  }

  Future<void> renameDatabase(int dbId, String newName) async {
    request({'op': 'rename_database', 'id': dbId, 'name': newName});
  }

  Future<void> styleDatabase(int dbId, {required int color, required String icon, required String category}) async {
    request({
      'op': 'style_database',
      'id': dbId,
      'color': color,
      'icon': icon,
      'category': category,
    });
  }

  Future<void> setReferenceDatabase(int? dbId) async {
    request({'op': 'set_reference', 'id': dbId});
  }

  Future<int?> getReferenceDatabase() async {
    final res = request({'op': 'get_reference'});
    return res as int?;
  }

  Future<int> startDeleteDatabase(int dbId) async {
    final res = request({'op': 'start_delete_database', 'dbId': dbId});
    return (res as Map)['jobId'] as int;
  }

  Future<void> deleteDatabase(int dbId) async {
    try {
      final jobId = await startDeleteDatabase(dbId);
      final startTime = DateTime.now();
      while (true) {
        await Future.delayed(const Duration(milliseconds: 50));
        final status = pollJobStatus(jobId);
        final state = status['state'];
        if (state == 'done') return;
        if (state == 'failed') {
          final err = status['error']?.toString() ?? 'Delete failed';
          if (err.contains('locked') || err.contains('busy')) {
            request({'op': 'delete_database', 'dbId': dbId});
            return;
          }
          throw Exception(err);
        }
        if (DateTime.now().difference(startTime).inSeconds > 60) {
          cancelJob(jobId);
          request({'op': 'delete_database', 'dbId': dbId});
          return;
        }
      }
    } catch (e) {
      if (e.toString().contains('locked') || e.toString().contains('busy')) {
        request({'op': 'delete_database', 'dbId': dbId});
        return;
      }
      rethrow;
    }
  }

  Future<int> countGames(int dbId, [Map<String, dynamic>? filter]) async {
    final res = request({
      'op': 'count_games',
      'dbId': dbId,
      'filter': filter ?? {},
    });
    return res as int;
  }

  Future<List<Map<String, dynamic>>> searchGames({
    required int dbId,
    Map<String, dynamic>? filter,
    String sort = 'date',
    bool desc = true,
    int offset = 0,
    int limit = 50,
  }) async {
    final res = request({
      'op': 'search_games',
      'dbId': dbId,
      'filter': filter ?? {},
      'sort': sort,
      'desc': desc,
      'offset': offset,
      'limit': limit,
    });
    final rows = (res as Map)['rows'] as List;
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String> getGamePgn(int gameId) async {
    final res = request({'op': 'get_game', 'id': gameId});
    return (res as Map)['pgn'] as String;
  }

  Future<Map<String, dynamic>> savePgn({
    required int dbId,
    required String pgn,
    String indexMode = 'balanced',
  }) async {
    final res = request({
      'op': 'save_pgn',
      'dbId': dbId,
      'pgn': pgn,
      'indexMode': indexMode,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> setFavorite(int gameId, bool isFavorite) async {
    request({'op': 'favorite', 'id': gameId, 'value': isFavorite});
  }

  Future<int> deleteGames(List<int> gameIds) async {
    final res = request({'op': 'delete_games', 'ids': gameIds});
    return res as int;
  }

  Future<Map<String, dynamic>> copyGames({
    required List<int> gameIds,
    required int targetDbId,
    bool deleteSource = false,
  }) async {
    final op = deleteSource ? 'move_games' : 'copy_games';
    final res = request({'op': op, 'ids': gameIds, 'target': targetDbId});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> positionSearch({
    required int dbId,
    required String fen,
    int offset = 0,
    int limit = 50,
  }) async {
    final res = request({
      'op': 'position_search',
      'dbId': dbId,
      'fen': fen,
      'offset': offset,
      'limit': limit,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> getStats(int dbId) async {
    final res = request({'op': 'stats', 'dbId': dbId});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> checkIntegrity() async {
    final res = request({'op': 'integrity_check'});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> vacuum() async {
    request({'op': 'vacuum'});
  }

  Future<int> startImport({
    required int dbId,
    required String filePath,
    int batchSize = 1000,
    String indexMode = 'balanced',
    int? resumeJob,
  }) async {
    final res = request({
      'op': 'start_import',
      'dbId': dbId,
      'path': filePath,
      'batchSize': batchSize,
      'indexMode': indexMode,
      'resumeJob': resumeJob,
    });
    return (res as Map)['jobId'] as int;
  }

  Future<int> startExport({
    required int dbId,
    required String filePath,
    List<int>? gameIds,
  }) async {
    final res = request({
      'op': 'start_export',
      'dbId': dbId,
      'path': filePath,
      if (gameIds != null) 'ids': gameIds,
    });
    return (res as Map)['jobId'] as int;
  }

  Map<String, dynamic> pollJobStatus(int jobId) {
    final res = request({'op': 'job_status', 'jobId': jobId});
    return Map<String, dynamic>.from(res as Map);
  }

  void cancelJob(int jobId) {
    request({'op': 'cancel_job', 'jobId': jobId});
  }

  Future<List<Map<String, dynamic>>> getImportErrors(int jobId, {int limit = 100}) async {
    final res = request({'op': 'import_errors', 'jobId': jobId, 'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getUnfinishedImports() async {
    final res = request({'op': 'unfinished_imports'});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  void dispose() {
    if (_handle > 0 && _ccClose != null) {
      _ccClose!(_handle);
      _handle = 0;
      _initialized = false;
    }
  }
}
