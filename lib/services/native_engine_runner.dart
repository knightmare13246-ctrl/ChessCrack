import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/engine_analysis.dart';

class NativeEngineRunner {
  static const MethodChannel _channel =
      MethodChannel('org.chesscrack.app/native');

  static Future<String> getDeviceAbi() async {
    if (!Platform.isAndroid) return 'x86_64';
    try {
      final String? abi = await _channel.invokeMethod<String>('getDeviceAbi');
      if (abi != null && abi.isNotEmpty) {
        return abi;
      }
    } catch (_) {}
    return 'armeabi-v7a';
  }

  static Future<bool> setExecutable(String filePath) async {
    if (!Platform.isAndroid && !Platform.isLinux && !Platform.isMacOS) {
      return true;
    }
    try {
      if (Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('setExecutable', {'path': filePath});
        if (res == true) return true;
      }
      final result = await Process.run('chmod', ['755', filePath]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

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

  static const List<String> supportedAndroidAbis = ['arm64-v8a', 'armeabi-v7a'];

  static bool isSupportedAbi(String abi) {
    if (!Platform.isAndroid) return true;
    return supportedAndroidAbis.contains(abi.trim().toLowerCase());
  }

  static Future<String?> getEngineExecutablePath(EngineType engineType) async {
    if (Platform.isAndroid) {
      final abi = await getDeviceAbi();
      if (!isSupportedAbi(abi)) {
        return null;
      }
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      if (engineType == EngineType.stockfish) {
        final sfName = Platform.isWindows ? 'stockfish.exe' : 'stockfish';
        final sfPath = '${appDir.path}/engines/stockfish/19/$sfName';
        if (File(sfPath).existsSync() && File(sfPath).lengthSync() > 100000) {
          await setExecutable(sfPath);
          return sfPath;
        }
      } else if (engineType == EngineType.lc0) {
        final lc0Name = Platform.isWindows ? 'lc0.exe' : 'lc0';
        final lc0Path = '${appDir.path}/engines/lc0/0.32.1/$lc0Name';
        if (File(lc0Path).existsSync() && File(lc0Path).lengthSync() > 100000) {
          await setExecutable(lc0Path);
          return lc0Path;
        }
      }
    } catch (_) {}

    // Fallbacks for desktop testing or legacy locations
    if (Platform.isWindows) {
      if (engineType == EngineType.stockfish) {
        const localWinPath = 'stockfish.exe';
        if (File(localWinPath).existsSync()) return localWinPath;
      } else if (engineType == EngineType.lc0) {
        const localLc0 = 'lc0.exe';
        if (File(localLc0).existsSync()) return localLc0;
      }
    } else if (Platform.isAndroid) {
      final binaryName =
          engineType == EngineType.stockfish ? 'libstockfish.so' : 'liblc0.so';
      final rawName =
          engineType == EngineType.stockfish ? 'libstockfish' : 'liblc0';

      final nativeDir = await getNativeLibraryDir();
      if (nativeDir != null) {
        final path = '$nativeDir/$binaryName';
        if (File(path).existsSync()) return path;
        final rawPath = '$nativeDir/$rawName';
        if (File(rawPath).existsSync()) return rawPath;
      }

      final commonPaths = [
        '/data/data/org.chesscrack.app/lib/$binaryName',
        '/data/user/0/org.chesscrack.app/lib/$binaryName',
        '/data/local/tmp/$rawName',
        '/data/local/tmp/$binaryName',
      ];

      for (final p in commonPaths) {
        if (File(p).existsSync()) return p;
      }
    }

    return null;
  }
}
