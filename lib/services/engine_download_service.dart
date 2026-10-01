import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/engine_analysis.dart';
import '../models/engine_download_model.dart';
import 'native_engine_runner.dart';

class EngineDownloadService extends ChangeNotifier {
  static final EngineDownloadService _instance = EngineDownloadService._internal();
  factory EngineDownloadService() => _instance;
  EngineDownloadService._internal();

  bool _initialized = false;
  String _deviceAbi = 'armeabi-v7a';
  String get deviceAbi => _deviceAbi;

  EngineArtifactInfo stockfishInfo = EngineArtifactInfo(
    id: 'stockfish_19',
    name: 'Stockfish',
    version: '19',
    filename: 'stockfish',
    officialSourceUrl: 'https://github.com/official-stockfish/Stockfish/releases/tag/sf_19',
    downloadUrl: '',
    localExecutablePath: '',
    metadataPath: '',
    abi: 'detecting...',
    expectedSizeBytes: 80 * 1024 * 1024,
  );

  EngineArtifactInfo lc0Info = EngineArtifactInfo(
    id: 'lc0_0_32_1',
    name: 'Leela Chess Zero',
    version: 'v0.32.1',
    filename: 'lc0',
    officialSourceUrl: 'https://github.com/LeelaChessZero/lc0/releases/tag/v0.32.1',
    downloadUrl: '',
    localExecutablePath: '',
    metadataPath: '',
    abi: 'detecting...',
    expectedSizeBytes: 40 * 1024 * 1024,
  );

  final Map<String, MaiaModelInfo> maiaModels = {};

  final Map<String, HttpClientRequest> _activeRequests = {};
  final Map<String, Completer<bool>> _activeCompleters = {};

  bool get isAnyDownloading {
    if (!_initialized) return false;
    return stockfishInfo.isDownloading ||
        lc0Info.isDownloading ||
        maiaModels.values.any((m) => m.isDownloading);
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _deviceAbi = await NativeEngineRunner.getDeviceAbi();
    final baseDir = await getApplicationDocumentsDirectory();

    // 1. Stockfish 19
    final sfDir = Directory('${baseDir.path}/engines/stockfish/19');
    if (!sfDir.existsSync()) sfDir.createSync(recursive: true);
    final sfExeName = Platform.isWindows ? 'stockfish.exe' : 'stockfish';
    final sfExePath = '${sfDir.path}/$sfExeName';
    final sfMetaPath = '${sfDir.path}/metadata.json';

    final sfDownloadUrl = _resolveStockfishUrl(_deviceAbi);
    final sfFilename = sfDownloadUrl.split('/').last;

    stockfishInfo = EngineArtifactInfo(
      id: 'stockfish_19',
      name: 'Stockfish',
      version: '19',
      filename: sfFilename,
      officialSourceUrl: 'https://github.com/official-stockfish/Stockfish/releases/tag/sf_19',
      downloadUrl: sfDownloadUrl,
      localExecutablePath: sfExePath,
      metadataPath: sfMetaPath,
      abi: _deviceAbi,
      expectedSizeBytes: 80 * 1024 * 1024,
    );
    _checkInstalledStatus(stockfishInfo);

    // 2. Leela Chess Zero v0.32.1
    final lc0Dir = Directory('${baseDir.path}/engines/lc0/0.32.1');
    if (!lc0Dir.existsSync()) lc0Dir.createSync(recursive: true);
    final lc0ExeName = Platform.isWindows ? 'lc0.exe' : 'lc0';
    final lc0ExePath = '${lc0Dir.path}/$lc0ExeName';
    final lc0MetaPath = '${lc0Dir.path}/metadata.json';

    final lc0DownloadUrl = Platform.isWindows
        ? 'https://github.com/LeelaChessZero/lc0/releases/download/v0.32.1/lc0-v0.32.1-windows-cpu-dnnl.zip'
        : 'https://github.com/LeelaChessZero/lc0/releases/download/v0.32.1/lc0-v0.32.1-android.apk';

    lc0Info = EngineArtifactInfo(
      id: 'lc0_0.32.1',
      name: 'Leela Chess Zero',
      version: 'v0.32.1',
      filename: lc0DownloadUrl.split('/').last,
      officialSourceUrl: 'https://github.com/LeelaChessZero/lc0/releases/tag/v0.32.1',
      downloadUrl: lc0DownloadUrl,
      localExecutablePath: lc0ExePath,
      metadataPath: lc0MetaPath,
      abi: _deviceAbi,
      expectedSizeBytes: 39 * 1024 * 1024,
    );
    _checkInstalledStatus(lc0Info);

    // 3. Official Maia Human Sparring Networks (10 models from official lczero.org)
    final networksDir = Directory('${baseDir.path}/networks/maia');
    if (!networksDir.existsSync()) networksDir.createSync(recursive: true);

    final officialMaiaList = [
      (1100, 'maia-1100.pb.gz', 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-1100.pb.gz', 'University of Toronto CSSLab'),
      (1200, 'maia-1200.pb.gz', 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-1200.pb.gz', 'University of Toronto CSSLab'),
      (1300, 'maia-1300.pb.gz', 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-1300.pb.gz', 'University of Toronto CSSLab'),
      (1400, 'maia-1400.pb.gz', 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-1400.pb.gz', 'University of Toronto CSSLab'),
      (1500, 'maia-1500.pb.gz', 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-1500.pb.gz', 'University of Toronto CSSLab'),
      (1600, 'maia-1600.pb.gz', 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-1600.pb.gz', 'University of Toronto CSSLab'),
      (1700, 'maia-1700.pb.gz', 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-1700.pb.gz', 'University of Toronto CSSLab'),
      (1800, 'maia-1800.pb.gz', 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-1800.pb.gz', 'University of Toronto CSSLab'),
      (1900, 'maia-1900.pb.gz', 'https://github.com/CSSLab/maia-chess/releases/download/v1.0/maia-1900.pb.gz', 'University of Toronto CSSLab'),
      (2200, 'maia-2200.pb.gz', 'https://github.com/CallOn84/LeelaNets/raw/refs/heads/main/Nets/Maia%202200/maia-2200.pb.gz', '@CallOn84'),
    ];

    for (final item in officialMaiaList) {
      final elo = item.$1;
      final filename = item.$2;
      final url = item.$3;
      final credit = item.$4;
      final id = 'maia_$elo';

      final modelDir = Directory('${networksDir.path}/$elo');
      if (!modelDir.existsSync()) modelDir.createSync(recursive: true);

      final localPath = '${modelDir.path}/$filename';
      final metaPath = '${modelDir.path}/metadata.json';

      final modelInfo = MaiaModelInfo(
        id: id,
        name: 'Maia $elo',
        approximateElo: elo,
        filename: filename,
        officialSourceUrl: 'https://lczero.org/play/networks/sparring-nets/',
        downloadUrl: url,
        checksum: 'unavailable',
        localPath: localPath,
        metadataPath: metaPath,
        estimatedSizeBytes: 12 * 1024 * 1024,
        credit: credit,
        notes: 'Run at Nodes = 1',
      );
      _checkMaiaInstalledStatus(modelInfo);
      maiaModels[id] = modelInfo;
    }

    _initialized = true;
    notifyListeners();
  }

  void _checkInstalledStatus(EngineArtifactInfo info) {
    final file = File(info.localExecutablePath);
    if (file.existsSync() && file.lengthSync() > 100000) {
      info.status = DownloadStatus.installed;
      info.installedSizeBytes = file.lengthSync();
    } else {
      info.status = DownloadStatus.notInstalled;
      info.installedSizeBytes = 0;
    }
  }

  void _checkMaiaInstalledStatus(MaiaModelInfo info) {
    final file = File(info.localPath);
    if (file.existsSync() && file.lengthSync() > 100000) {
      info.status = DownloadStatus.installed;
      info.installedSizeBytes = file.lengthSync();
    } else {
      info.status = DownloadStatus.notInstalled;
      info.installedSizeBytes = 0;
    }
  }

  String _resolveStockfishUrl(String abi) {
    if (Platform.isWindows) {
      return 'https://github.com/official-stockfish/Stockfish/releases/download/sf_19/stockfish-windows-x86-64-universal.zip';
    }
    if (abi == 'arm64-v8a') {
      return 'https://github.com/official-stockfish/Stockfish/releases/download/sf_19/stockfish-android-arm64-universal.tar.gz';
    } else if (abi == 'x86_64') {
      return 'https://github.com/official-stockfish/Stockfish/releases/download/sf_19/stockfish-linux-x86-64-universal.tar.gz';
    } else {
      // Default to armv7 neon for 32-bit ARM (e.g. armeabi-v7a)
      return 'https://github.com/official-stockfish/Stockfish/releases/download/sf_19/stockfish-android-armv7-neon.tar.gz';
    }
  }

  bool isEngineInstalled(EngineType type) {
    if (type == EngineType.stockfish) {
      return stockfishInfo.isInstalled;
    } else {
      return lc0Info.isInstalled;
    }
  }

  MaiaModelInfo? getMaiaModel(String id) {
    return maiaModels[id];
  }

  EngineStorageSummary getStorageSummary() {
    int sf = stockfishInfo.isInstalled ? stockfishInfo.installedSizeBytes : 0;
    int lc = lc0Info.isInstalled ? lc0Info.installedSizeBytes : 0;
    int maia = 0;
    for (final m in maiaModels.values) {
      if (m.isInstalled) maia += m.installedSizeBytes;
    }
    return EngineStorageSummary(
      stockfishBytes: sf,
      lc0Bytes: lc,
      maiaBytes: maia,
    );
  }

  // --- DOWNLOAD FLOWS WITH DEDUPLICATION ---

  Future<bool> downloadStockfish({Function(double progress, String status)? onProgress}) async {
    if (stockfishInfo.isInstalled) return true;
    if (stockfishInfo.isDownloading && _activeCompleters.containsKey(stockfishInfo.id)) {
      return _activeCompleters[stockfishInfo.id]!.future;
    }

    final completer = Completer<bool>();
    _activeCompleters[stockfishInfo.id] = completer;

    stockfishInfo.status = DownloadStatus.downloading;
    stockfishInfo.progress = 0.0;
    stockfishInfo.bytesReceived = 0;
    stockfishInfo.errorMessage = null;
    notifyListeners();

    final targetArchive = File('${stockfishInfo.localExecutablePath}.download');
    try {
      final success = await _downloadFile(
        stockfishInfo.id,
        stockfishInfo.downloadUrl,
        targetArchive,
        (progress, received, total) {
          stockfishInfo.progress = progress;
          stockfishInfo.bytesReceived = received;
          stockfishInfo.totalBytes = total;
          onProgress?.call(progress, 'Downloading: ${(progress * 100).toStringAsFixed(1)}%');
          notifyListeners();
        },
      );

      if (!success) {
        throw Exception('Download failed or cancelled');
      }

      stockfishInfo.status = DownloadStatus.installing;
      onProgress?.call(0.95, 'Extracting and verifying binary...');
      notifyListeners();

      // Extract archive
      final archiveBytes = await targetArchive.readAsBytes();
      final exeBytes = _extractStockfishBinary(archiveBytes, stockfishInfo.filename);
      if (exeBytes == null || exeBytes.isEmpty) {
        throw Exception('Failed to extract Stockfish executable from archive');
      }

      final targetExe = File(stockfishInfo.localExecutablePath);
      await targetExe.writeAsBytes(exeBytes, flush: true);
      await targetArchive.delete();

      // Mark executable permissions
      await NativeEngineRunner.setExecutable(targetExe.path);

      // Verify startup via UCI handshake
      stockfishInfo.status = DownloadStatus.verifying;
      onProgress?.call(0.98, 'Verifying engine UCI response...');
      notifyListeners();

      final verifyOk = await _verifyEngineStartup(targetExe.path, 'Stockfish 19');
      if (!verifyOk) {
        if (targetExe.existsSync()) targetExe.deleteSync();
        throw Exception('UCI handshake verification failed for Stockfish 19');
      }

      // Save metadata.json
      final meta = {
        'id': stockfishInfo.id,
        'name': stockfishInfo.name,
        'version': stockfishInfo.version,
        'abi': stockfishInfo.abi,
        'installedDate': DateTime.now().toIso8601String(),
        'fileSize': targetExe.lengthSync(),
        'executable': targetExe.path,
      };
      await File(stockfishInfo.metadataPath).writeAsString(jsonEncode(meta));

      stockfishInfo.status = DownloadStatus.installed;
      stockfishInfo.installedSizeBytes = targetExe.lengthSync();
      stockfishInfo.progress = 1.0;
      notifyListeners();
      completer.complete(true);
      return true;
    } catch (e) {
      if (targetArchive.existsSync()) targetArchive.deleteSync();
      stockfishInfo.status = stockfishInfo.status == DownloadStatus.cancelled
          ? DownloadStatus.cancelled
          : DownloadStatus.error;
      stockfishInfo.errorMessage = e.toString();
      notifyListeners();
      completer.complete(false);
      return false;
    } finally {
      _activeRequests.remove(stockfishInfo.id);
      _activeCompleters.remove(stockfishInfo.id);
    }
  }

  Future<bool> downloadLc0({Function(double progress, String status)? onProgress}) async {
    if (lc0Info.isInstalled) return true;
    if (lc0Info.isDownloading && _activeCompleters.containsKey(lc0Info.id)) {
      return _activeCompleters[lc0Info.id]!.future;
    }

    final completer = Completer<bool>();
    _activeCompleters[lc0Info.id] = completer;

    lc0Info.status = DownloadStatus.downloading;
    lc0Info.progress = 0.0;
    lc0Info.bytesReceived = 0;
    lc0Info.errorMessage = null;
    notifyListeners();

    final targetArchive = File('${lc0Info.localExecutablePath}.download');
    try {
      final success = await _downloadFile(
        lc0Info.id,
        lc0Info.downloadUrl,
        targetArchive,
        (progress, received, total) {
          lc0Info.progress = progress;
          lc0Info.bytesReceived = received;
          lc0Info.totalBytes = total;
          onProgress?.call(progress, 'Downloading: ${(progress * 100).toStringAsFixed(1)}%');
          notifyListeners();
        },
      );

      if (!success) {
        throw Exception('Download failed or cancelled');
      }

      lc0Info.status = DownloadStatus.installing;
      onProgress?.call(0.95, 'Extracting Lc0 native engine...');
      notifyListeners();

      final archiveBytes = await targetArchive.readAsBytes();
      final exeBytes = _extractLc0Binary(archiveBytes, _deviceAbi);
      if (exeBytes == null || exeBytes.isEmpty) {
        throw Exception('Could not extract native Lc0 executable for ABI: $_deviceAbi');
      }

      final targetExe = File(lc0Info.localExecutablePath);
      await targetExe.writeAsBytes(exeBytes, flush: true);
      await targetArchive.delete();

      // Make executable
      await NativeEngineRunner.setExecutable(targetExe.path);

      // Verify UCI startup
      lc0Info.status = DownloadStatus.verifying;
      onProgress?.call(0.98, 'Verifying Lc0 UCI response...');
      notifyListeners();

      final verifyOk = await _verifyEngineStartup(targetExe.path, 'Lc0');
      if (!verifyOk) {
        if (targetExe.existsSync()) targetExe.deleteSync();
        throw Exception('UCI handshake verification failed for Lc0');
      }

      // Save metadata
      final meta = {
        'id': lc0Info.id,
        'name': lc0Info.name,
        'version': lc0Info.version,
        'abi': lc0Info.abi,
        'installedDate': DateTime.now().toIso8601String(),
        'fileSize': targetExe.lengthSync(),
        'executable': targetExe.path,
      };
      await File(lc0Info.metadataPath).writeAsString(jsonEncode(meta));

      lc0Info.status = DownloadStatus.installed;
      lc0Info.installedSizeBytes = targetExe.lengthSync();
      lc0Info.progress = 1.0;
      notifyListeners();
      completer.complete(true);
      return true;
    } catch (e) {
      if (targetArchive.existsSync()) targetArchive.deleteSync();
      lc0Info.status = lc0Info.status == DownloadStatus.cancelled
          ? DownloadStatus.cancelled
          : DownloadStatus.error;
      lc0Info.errorMessage = e.toString();
      notifyListeners();
      completer.complete(false);
      return false;
    } finally {
      _activeRequests.remove(lc0Info.id);
      _activeCompleters.remove(lc0Info.id);
    }
  }

  Future<bool> downloadMaiaModel(String modelId, {Function(double progress, String status)? onProgress}) async {
    final model = maiaModels[modelId];
    if (model == null) return false;
    if (model.isInstalled) return true;
    if (model.isDownloading && _activeCompleters.containsKey(modelId)) {
      return _activeCompleters[modelId]!.future;
    }

    final completer = Completer<bool>();
    _activeCompleters[modelId] = completer;

    model.status = DownloadStatus.downloading;
    model.progress = 0.0;
    model.bytesReceived = 0;
    model.errorMessage = null;
    notifyListeners();

    final targetFile = File(model.localPath);
    final tempFile = File('${model.localPath}.download');

    try {
      final success = await _downloadFile(
        modelId,
        model.downloadUrl,
        tempFile,
        (progress, received, total) {
          model.progress = progress;
          model.bytesReceived = received;
          model.totalBytes = total;
          onProgress?.call(progress, 'Downloading: ${(progress * 100).toStringAsFixed(1)}%');
          notifyListeners();
        },
      );

      if (!success) {
        throw Exception('Download failed or cancelled');
      }

      model.status = DownloadStatus.verifying;
      notifyListeners();

      // Check gzip header integrity
      final bytes = await tempFile.readAsBytes();
      if (bytes.length < 10 || bytes[0] != 0x1f || bytes[1] != 0x8b) {
        throw Exception('Invalid gzip neural network weights file');
      }

      await tempFile.rename(targetFile.path);

      // Save metadata
      final meta = model.toJson();
      await File(model.metadataPath).writeAsString(jsonEncode(meta));

      model.status = DownloadStatus.installed;
      model.installedSizeBytes = targetFile.lengthSync();
      model.progress = 1.0;
      notifyListeners();
      completer.complete(true);
      return true;
    } catch (e) {
      if (tempFile.existsSync()) tempFile.deleteSync();
      model.status = model.status == DownloadStatus.cancelled
          ? DownloadStatus.cancelled
          : DownloadStatus.error;
      model.errorMessage = e.toString();
      notifyListeners();
      completer.complete(false);
      return false;
    } finally {
      _activeRequests.remove(modelId);
      _activeCompleters.remove(modelId);
    }
  }

  void cancelDownload(String id) {
    if (_activeRequests.containsKey(id)) {
      _activeRequests[id]?.abort();
      _activeRequests.remove(id);
    }
    if (id == stockfishInfo.id) {
      stockfishInfo.status = DownloadStatus.cancelled;
      stockfishInfo.errorMessage = 'Cancelled by user';
    } else if (id == lc0Info.id) {
      lc0Info.status = DownloadStatus.cancelled;
      lc0Info.errorMessage = 'Cancelled by user';
    } else if (maiaModels.containsKey(id)) {
      maiaModels[id]?.status = DownloadStatus.cancelled;
      maiaModels[id]?.errorMessage = 'Cancelled by user';
    }
    notifyListeners();
  }

  // --- SAFE ENGINE & NETWORK REMOVAL ---

  Future<void> removeStockfish({Future<void> Function()? onBeforeDelete}) async {
    await onBeforeDelete?.call();
    try {
      final exe = File(stockfishInfo.localExecutablePath);
      if (exe.existsSync()) exe.deleteSync();
      final meta = File(stockfishInfo.metadataPath);
      if (meta.existsSync()) meta.deleteSync();
    } catch (_) {}
    stockfishInfo.status = DownloadStatus.notInstalled;
    stockfishInfo.installedSizeBytes = 0;
    stockfishInfo.progress = 0.0;
    notifyListeners();
  }

  Future<void> removeLc0({Future<void> Function()? onBeforeDelete}) async {
    await onBeforeDelete?.call();
    try {
      final exe = File(lc0Info.localExecutablePath);
      if (exe.existsSync()) exe.deleteSync();
      final meta = File(lc0Info.metadataPath);
      if (meta.existsSync()) meta.deleteSync();
    } catch (_) {}
    lc0Info.status = DownloadStatus.notInstalled;
    lc0Info.installedSizeBytes = 0;
    lc0Info.progress = 0.0;
    notifyListeners();
  }

  Future<void> removeMaiaModel(String modelId, {Future<void> Function()? onBeforeDelete}) async {
    final model = maiaModels[modelId];
    if (model == null) return;
    await onBeforeDelete?.call();
    try {
      final f = File(model.localPath);
      if (f.existsSync()) f.deleteSync();
      final meta = File(model.metadataPath);
      if (meta.existsSync()) meta.deleteSync();
    } catch (_) {}
    model.status = DownloadStatus.notInstalled;
    model.installedSizeBytes = 0;
    model.progress = 0.0;
    notifyListeners();
  }

  // --- INTERNAL UTILITIES ---

  Future<bool> _downloadFile(
    String id,
    String url,
    File destFile,
    Function(double progress, int received, int total) onProgress,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);

    try {
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      _activeRequests[id] = request;

      final response = await request.close();
      if (response.statusCode != 200) {
        // Follow redirect if 301, 302, 307, 308
        if (response.isRedirect || response.statusCode == 302 || response.statusCode == 301) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location != null) {
            return await _downloadFile(id, location, destFile, onProgress);
          }
        }
        throw HttpException('HTTP Error: ${response.statusCode} ${response.reasonPhrase}');
      }

      final contentLength = response.contentLength;
      int received = 0;
      final sink = destFile.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        final prog = contentLength > 0 ? (received / contentLength).clamp(0.0, 1.0) : 0.5;
        onProgress(prog, received, contentLength);
      }

      await sink.flush();
      await sink.close();
      return true;
    } catch (e) {
      if (destFile.existsSync()) destFile.deleteSync();
      rethrow;
    } finally {
      client.close();
    }
  }

  List<int>? _extractStockfishBinary(List<int> archiveBytes, String archiveName) {
    if (archiveName.endsWith('.zip')) {
      final zip = ZipDecoder().decodeBytes(archiveBytes);
      for (final file in zip) {
        if (file.isFile && (file.name.endsWith('.exe') || !file.name.contains('.'))) {
          return file.content as List<int>;
        }
      }
    } else {
      // .tar.gz
      final gz = const GZipDecoder().decodeBytes(archiveBytes);
      final tar = TarDecoder().decodeBytes(gz);
      for (final file in tar) {
        if (file.isFile && file.name.contains('stockfish-')) {
          return file.content as List<int>;
        }
      }
    }
    return null;
  }

  List<int>? _extractLc0Binary(List<int> archiveBytes, String abi) {
    final zip = ZipDecoder().decodeBytes(archiveBytes);
    if (Platform.isWindows) {
      for (final file in zip) {
        if (file.isFile && file.name.endsWith('lc0.exe')) {
          return file.content as List<int>;
        }
      }
    } else {
      // APK is a zip. Extract lib/<abi>/liblc0.so
      final targetPath = 'lib/$abi/liblc0.so';
      for (final file in zip) {
        if (file.isFile && file.name == targetPath) {
          return file.content as List<int>;
        }
      }
      // Fallback: search for any liblc0.so matching abi
      for (final file in zip) {
        if (file.isFile && file.name.contains(abi) && file.name.endsWith('liblc0.so')) {
          return file.content as List<int>;
        }
      }
    }
    return null;
  }

  Future<bool> _verifyEngineStartup(String binaryPath, String expectedKeyword) async {
    try {
      final process = await Process.start(binaryPath, []);
      final completer = Completer<bool>();
      bool ok = false;

      final sub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.contains('id name') && line.toLowerCase().contains(expectedKeyword.toLowerCase())) {
          ok = true;
        }
        if (line.trim() == 'uciok') {
          if (!completer.isCompleted) completer.complete(ok);
        }
      });

      process.stdin.writeln('uci');

      final result = await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => ok,
      );

      process.stdin.writeln('quit');
      await sub.cancel();
      try {
        await process.exitCode.timeout(const Duration(milliseconds: 300));
      } catch (_) {
        process.kill();
      }
      return result;
    } catch (_) {
      return false;
    }
  }
}
