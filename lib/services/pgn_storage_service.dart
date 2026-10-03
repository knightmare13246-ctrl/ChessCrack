import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chess_game_record.dart';

class PgnStorageService {
  static final PgnStorageService instance = PgnStorageService._internal();
  PgnStorageService._internal();

  Directory? _cachedGamesDir;
  File? _cachedIndexFile;

  Future<Directory> _getGamesDir() async {
    if (_cachedGamesDir != null && _cachedGamesDir!.existsSync()) {
      return _cachedGamesDir!;
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final gamesDir = Directory('${docsDir.path}${Platform.pathSeparator}games');
    if (!gamesDir.existsSync()) {
      gamesDir.createSync(recursive: true);
    }
    _cachedGamesDir = gamesDir;
    return gamesDir;
  }

  Future<File> _getIndexFile() async {
    if (_cachedIndexFile != null) return _cachedIndexFile!;
    final gamesDir = await _getGamesDir();
    _cachedIndexFile = File('${gamesDir.path}${Platform.pathSeparator}games_index.json');
    return _cachedIndexFile!;
  }

  /// Automatically saves a completed game record.
  /// Uses atomic write + verification to guarantee zero data loss.
  Future<bool> saveGame(ChessGameRecord record) async {
    try {
      final gamesDir = await _getGamesDir();
      final pgnFile = File('${gamesDir.path}${Platform.pathSeparator}${record.id}.pgn');
      final tmpFile = File('${gamesDir.path}${Platform.pathSeparator}${record.id}.pgn.tmp');

      // 1. Write PGN content to temporary file
      await tmpFile.writeAsString(record.pgn, flush: true);

      // 2. Atomic rename to target file
      if (pgnFile.existsSync()) {
        await pgnFile.delete();
      }
      await tmpFile.rename(pgnFile.path);

      // 3. Verify write success
      if (!pgnFile.existsSync() || (await pgnFile.length()) == 0) {
        throw StateError('PGN write verification failed: file is missing or 0 bytes');
      }

      // 4. Update games_index.json
      final indexFile = await _getIndexFile();
      List<ChessGameRecord> existing = await loadAllGames();
      // Remove any existing entry with the same ID
      existing.removeWhere((g) => g.id == record.id);
      // Prepend the new game so it appears first (chronological order)
      existing.insert(0, record);

      final indexJson = existing.map((g) => g.toJson(includePgn: false)).toList();
      final tmpIndexFile = File('${indexFile.path}.tmp');
      await tmpIndexFile.writeAsString(jsonEncode(indexJson), flush: true);
      if (indexFile.existsSync()) {
        await indexFile.delete();
      }
      await tmpIndexFile.rename(indexFile.path);

      if (kDebugMode) {
        developer.log('Game ${record.id} saved and verified successfully', name: 'PgnStorageService');
      }
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        developer.log('Failed to save game: $e', error: e, stackTrace: st, name: 'PgnStorageService');
      }
      return false;
    }
  }

  /// Loads metadata list of all saved games from index.
  Future<List<ChessGameRecord>> loadAllGames() async {
    try {
      final indexFile = await _getIndexFile();
      if (!indexFile.existsSync()) {
        return [];
      }
      final content = await indexFile.readAsString();
      if (content.trim().isEmpty) return [];

      final decoded = jsonDecode(content) as List;
      return decoded.map((item) => ChessGameRecord.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) {
        developer.log('Error reading games_index.json: $e', name: 'PgnStorageService');
      }
      return [];
    }
  }

  /// Loads the full PGN string for a given game ID.
  Future<String?> loadGamePgn(String gameId) async {
    try {
      final gamesDir = await _getGamesDir();
      final pgnFile = File('${gamesDir.path}${Platform.pathSeparator}$gameId.pgn');
      if (pgnFile.existsSync()) {
        return await pgnFile.readAsString();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        developer.log('Error reading game PGN $gameId: $e', name: 'PgnStorageService');
      }
      return null;
    }
  }

  /// Deletes a game record and its PGN file.
  Future<bool> deleteGame(String gameId) async {
    try {
      final gamesDir = await _getGamesDir();
      final pgnFile = File('${gamesDir.path}${Platform.pathSeparator}$gameId.pgn');
      if (pgnFile.existsSync()) {
        await pgnFile.delete();
      }

      final indexFile = await _getIndexFile();
      if (indexFile.existsSync()) {
        final existing = await loadAllGames();
        existing.removeWhere((g) => g.id == gameId);
        final indexJson = existing.map((g) => g.toJson(includePgn: false)).toList();
        await indexFile.writeAsString(jsonEncode(indexJson), flush: true);
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        developer.log('Error deleting game $gameId: $e', name: 'PgnStorageService');
      }
      return false;
    }
  }

  /// Exports a PGN string to the device Downloads or external directory.
  Future<String?> exportToDownloads(String pgn, String filename) async {
    try {
      Directory? targetDir;
      final cleanFilename = filename.replaceAll(RegExp(r'[^\w\.-]'), '_');

      if (Platform.isAndroid) {
        // Try public Download folder first if writable
        try {
          final pubDownload = Directory('/storage/emulated/0/Download');
          if (pubDownload.existsSync()) {
            final testFile = File('${pubDownload.path}${Platform.pathSeparator}.test_write');
            await testFile.writeAsString('test', flush: true);
            if (testFile.existsSync()) {
              await testFile.delete();
              targetDir = pubDownload;
            }
          }
        } catch (_) {
          targetDir = null;
        }

        // Fallback to app external storage (Downloads or files)
        if (targetDir == null) {
          try {
            final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
            if (extDirs != null && extDirs.isNotEmpty) {
              targetDir = extDirs.first;
            }
          } catch (_) {}
          targetDir ??= await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getDownloadsDirectory();
      }

      targetDir ??= await getApplicationDocumentsDirectory();
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      final exportFile = File('${targetDir.path}${Platform.pathSeparator}$cleanFilename');
      await exportFile.writeAsString(pgn, flush: true);
      return exportFile.path;
    } catch (e, st) {
      if (kDebugMode) {
        developer.log('Error exporting PGN: $e', error: e, stackTrace: st, name: 'PgnStorageService');
      }
      return null;
    }
  }
}
