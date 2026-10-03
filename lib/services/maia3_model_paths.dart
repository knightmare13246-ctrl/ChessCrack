import 'dart:io';

/// Single canonical path and state resolver for the Maia-3 rating-conditioned model.
///
/// Guarantees:
/// 1. Canonical model path: `<app_documents>/models/maia3/maia3_simplified.onnx`
/// 2. Temp download path: `<app_documents>/models/maia3/maia3_simplified.onnx.download`
/// 3. Metadata path: `<app_documents>/models/maia3/metadata.json`
/// 4. ONNX Runtime and consumers NEVER touch or receive temporary `.download` files.
class Maia3ModelPaths {
  final Directory directory;

  Maia3ModelPaths._(this.directory);

  /// Resolves the canonical paths given the application base documents directory.
  factory Maia3ModelPaths.fromBaseDir(Directory baseDir) {
    final sep = Platform.pathSeparator;
    final dir = Directory('${baseDir.path}${sep}models${sep}maia3');
    return Maia3ModelPaths._(dir);
  }

  /// Directory holding Maia-3 assets (`.../models/maia3`).
  Directory get modelDirectory => directory;

  /// Canonical, usable ONNX model path (`.../models/maia3/maia3_simplified.onnx`).
  String get finalModelPath => '${directory.path}${Platform.pathSeparator}maia3_simplified.onnx';

  /// Temporary download path (`.../models/maia3/maia3_simplified.onnx.download`).
  String get tempDownloadPath => '${directory.path}${Platform.pathSeparator}maia3_simplified.onnx.download';

  /// Metadata file path (`.../models/maia3/metadata.json`).
  String get metadataPath => '${directory.path}${Platform.pathSeparator}metadata.json';

  /// File instance for the canonical model.
  File get finalModelFile => File(finalModelPath);

  /// File instance for the temporary download file.
  File get tempDownloadFile => File(tempDownloadPath);

  /// File instance for the metadata JSON file.
  File get metadataFile => File(metadataPath);

  /// Ensures the parent directory exists on disk.
  void ensureDirectoryExists() {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }

  /// Cleans up any orphaned `.download` file left over from a previous interrupted session.
  void cleanupOrphanedDownload() {
    try {
      final temp = tempDownloadFile;
      if (temp.existsSync()) {
        temp.deleteSync();
      }
    } catch (_) {}
  }

  /// Verifies if the canonical model exists and meets minimum integrity size (>= 1MB).
  bool isModelValid() {
    final file = finalModelFile;
    return file.existsSync() && file.lengthSync() >= 1000000;
  }
}
