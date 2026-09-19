import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/engine_analysis.dart';

class NativeEngineRunner {
  static const MethodChannel _channel =
      MethodChannel('org.chesscrack.app/native');

  static Future<String?> getNativeLibraryDir() async {
    if (!Platform.isAndroid) return null;
    try {
      final String? dir =
          await _channel.invokeMethod<String>('getNativeLibraryDir');
      return dir;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getEngineExecutablePath(EngineType engineType) async {
    if (Platform.isWindows) {
      if (engineType == EngineType.stockfish) {
        const winPath =
            r'C:\Users\Quantum\Downloads\stockfish-windows-x86-64-universal\stockfish\stockfish-windows-x86-64-universal.exe';
        if (File(winPath).existsSync()) return winPath;

        const localWinPath = 'stockfish.exe';
        if (File(localWinPath).existsSync()) return localWinPath;
      } else if (engineType == EngineType.lc0) {
        const winPath =
            r'C:\Users\Quantum\Downloads\lc0-v0.32.1-windows-cpu-dnnl\lc0.exe';
        if (File(winPath).existsSync()) return winPath;

        const localLc0 = 'lc0.exe';
        if (File(localLc0).existsSync()) return localLc0;
      }
    } else if (Platform.isAndroid) {
      final binaryName =
          engineType == EngineType.stockfish ? 'libstockfish.so' : 'liblc0.so';
      final rawName =
          engineType == EngineType.stockfish ? 'libstockfish' : 'liblc0';

      // 1. Query official Android nativeLibraryDir via MethodChannel
      final nativeDir = await getNativeLibraryDir();
      if (nativeDir != null) {
        final path = '$nativeDir/$binaryName';
        if (File(path).existsSync()) return path;
        final rawPath = '$nativeDir/$rawName';
        if (File(rawPath).existsSync()) return rawPath;
      }

      // 2. Standard Android native library locations for installed packages
      final commonPaths = [
        '/data/data/org.chesscrack.app/lib/$binaryName',
        '/data/user/0/org.chesscrack.app/lib/$binaryName',
        '/data/data/com.chesscrack.chesscrack/lib/$binaryName',
        '/data/user/0/com.chesscrack.chesscrack/lib/$binaryName',
        '/data/local/tmp/$rawName',
        '/data/local/tmp/$binaryName',
      ];

      for (final p in commonPaths) {
        if (File(p).existsSync()) return p;
      }
    }

    return null;
  }

  /// Automatically provisions bundled Lc0 weights so user never needs to download anything.
  static Future<String?> getBundledWeightsPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final weightsDir = Directory('${dir.path}/weights');
      if (!weightsDir.existsSync()) {
        weightsDir.createSync(recursive: true);
      }
      final targetFile = File('${weightsDir.path}/default_weights.pb');
      if (!targetFile.existsSync() || targetFile.lengthSync() == 0) {
        final byteData = await rootBundle.load('assets/weights/default_weights.pb');
        final buffer = byteData.buffer;
        await targetFile.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          flush: true,
        );
      }
      return targetFile.path;
    } catch (_) {
      // Fallback to built-in embedded weights if file extraction fails
      return '<built in>';
    }
  }
}

