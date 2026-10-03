import 'dart:io';

enum DownloadStatus {
  notInstalled,
  queued,
  downloading,
  verifying,
  installing,
  installed,
  error,
  cancelled,
  unsupported,
}

enum EngineInstallationState {
  uninstalled,
  downloading,
  verifying,
  installed,
  ready,
  deleting,
  error,
}

class EngineArtifactInfo {
  final String id;
  final String name;
  final String version;
  final String filename;
  final String officialSourceUrl;
  final String downloadUrl;
  String localExecutablePath;
  String metadataPath;
  final int expectedSizeBytes;
  final String abi;
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  int bytesReceived;
  int totalBytes;
  String? errorMessage;
  int installedSizeBytes;

  EngineArtifactInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.filename,
    required this.officialSourceUrl,
    required this.downloadUrl,
    required this.localExecutablePath,
    required this.metadataPath,
    this.expectedSizeBytes = 0,
    required this.abi,
    this.status = DownloadStatus.notInstalled,
    this.progress = 0.0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.installedSizeBytes = 0,
  });

  bool get isInstalled {
    if (status != DownloadStatus.installed) return false;
    if (isBundled) return true;
    if (localExecutablePath.isEmpty) return false;
    return File(localExecutablePath).existsSync();
  }
  bool get isDownloading => status == DownloadStatus.downloading || status == DownloadStatus.verifying || status == DownloadStatus.installing;
  bool get isBundled => status == DownloadStatus.installed && (localExecutablePath.contains('/lib/') || localExecutablePath.endsWith('.so'));

  EngineInstallationState get installationState {
    switch (status) {
      case DownloadStatus.notInstalled:
      case DownloadStatus.cancelled:
      case DownloadStatus.unsupported:
        return EngineInstallationState.uninstalled;
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        return EngineInstallationState.downloading;
      case DownloadStatus.verifying:
      case DownloadStatus.installing:
        return EngineInstallationState.verifying;
      case DownloadStatus.installed:
        return EngineInstallationState.installed;
      case DownloadStatus.error:
        return EngineInstallationState.error;
    }
  }
}

class MaiaModelInfo {
  final String id;
  final String name;
  final int approximateElo;
  final String filename;
  final String officialSourceUrl;
  final String downloadUrl;
  final String checksum; // "unavailable" if not provided by upstream
  String localPath;
  final String metadataPath;
  final int estimatedSizeBytes;
  final String credit;
  final String notes; // e.g. "Run at Nodes = 1"
  DownloadStatus status;
  double progress;
  int bytesReceived;
  int totalBytes;
  String? errorMessage;
  int installedSizeBytes;

  MaiaModelInfo({
    required this.id,
    required this.name,
    required this.approximateElo,
    required this.filename,
    required this.officialSourceUrl,
    required this.downloadUrl,
    this.checksum = 'unavailable',
    required this.localPath,
    required this.metadataPath,
    required this.estimatedSizeBytes,
    required this.credit,
    this.notes = 'Run at Nodes = 1',
    this.status = DownloadStatus.notInstalled,
    this.progress = 0.0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.installedSizeBytes = 0,
  });

  bool get isInstalled => status == DownloadStatus.installed && File(localPath).existsSync();
  bool get isDownloading => status == DownloadStatus.downloading || status == DownloadStatus.verifying;

  EngineInstallationState get installationState {
    switch (status) {
      case DownloadStatus.notInstalled:
      case DownloadStatus.cancelled:
      case DownloadStatus.unsupported:
        return EngineInstallationState.uninstalled;
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        return EngineInstallationState.downloading;
      case DownloadStatus.verifying:
      case DownloadStatus.installing:
        return EngineInstallationState.verifying;
      case DownloadStatus.installed:
        return File(localPath).existsSync()
            ? EngineInstallationState.installed
            : EngineInstallationState.uninstalled;
      case DownloadStatus.error:
        return EngineInstallationState.error;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'approximateElo': approximateElo,
    'filename': filename,
    'officialSourceUrl': officialSourceUrl,
    'downloadUrl': downloadUrl,
    'checksum': checksum,
    'localPath': localPath,
    'installed': isInstalled,
    'fileSize': installedSizeBytes > 0 ? installedSizeBytes : estimatedSizeBytes,
    'credit': credit,
    'notes': notes,
  };
}

class MaiaProfile {
  final String modelId;
  final int approximateElo;
  final int nodes;
  final String backend;
  final int threads;
  final bool showWdl;
  final bool showMovesLeft;

  const MaiaProfile({
    required this.modelId,
    required this.approximateElo,
    this.nodes = 1,
    this.backend = 'auto',
    this.threads = 1,
    this.showWdl = true,
    this.showMovesLeft = true,
  });

  MaiaProfile copyWith({
    String? modelId,
    int? approximateElo,
    int? nodes,
    String? backend,
    int? threads,
    bool? showWdl,
    bool? showMovesLeft,
  }) {
    return MaiaProfile(
      modelId: modelId ?? this.modelId,
      approximateElo: approximateElo ?? this.approximateElo,
      nodes: nodes ?? this.nodes,
      backend: backend ?? this.backend,
      threads: threads ?? this.threads,
      showWdl: showWdl ?? this.showWdl,
      showMovesLeft: showMovesLeft ?? this.showMovesLeft,
    );
  }

  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    'approximateElo': approximateElo,
    'nodes': nodes,
    'backend': backend,
    'threads': threads,
    'showWdl': showWdl,
    'showMovesLeft': showMovesLeft,
  };

  factory MaiaProfile.fromJson(Map<String, dynamic> json) {
    return MaiaProfile(
      modelId: json['modelId'] as String,
      approximateElo: json['approximateElo'] as int? ?? 1100,
      nodes: json['nodes'] as int? ?? 1,
      backend: json['backend'] as String? ?? 'auto',
      threads: json['threads'] as int? ?? 1,
      showWdl: json['showWdl'] as bool? ?? true,
      showMovesLeft: json['showMovesLeft'] as bool? ?? true,
    );
  }
}

class EngineStorageSummary {
  final int stockfishBytes;
  final int lc0Bytes;
  final int maiaBytes;
  final int maia3Bytes;

  const EngineStorageSummary({
    this.stockfishBytes = 0,
    this.lc0Bytes = 0,
    this.maiaBytes = 0,
    this.maia3Bytes = 0,
  });

  int get totalBytes => stockfishBytes + lc0Bytes + maiaBytes + maia3Bytes;

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1.0) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}

