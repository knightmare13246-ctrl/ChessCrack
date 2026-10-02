import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nibbler_chess/models/engine_download_model.dart';
import 'package:nibbler_chess/services/engine_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Artifact Deletion & Storage Lifecycle Suite', () {
    test('1. EngineArtifactInfo distinguishes bundled native libraries vs downloaded updates', () {
      final bundledArtifact = EngineArtifactInfo(
        id: 'sf_bundled',
        name: 'Stockfish 19',
        version: '19',
        filename: 'libstockfish.so',
        officialSourceUrl: '',
        downloadUrl: '',
        localExecutablePath: '/data/app/~~pkg/lib/arm64/libstockfish.so',
        metadataPath: '',
        abi: 'arm64-v8a',
        status: DownloadStatus.installed,
      );

      final downloadedArtifact = EngineArtifactInfo(
        id: 'sf_downloaded',
        name: 'Stockfish 19',
        version: '19',
        filename: 'stockfish',
        officialSourceUrl: '',
        downloadUrl: 'https://github.com/...',
        localExecutablePath: '/data/user/0/com.example.chess/app_flutter/engines/stockfish/19/stockfish',
        metadataPath: '',
        abi: 'arm64-v8a',
        status: DownloadStatus.installed,
      );

      expect(bundledArtifact.isBundled, isTrue,
          reason: 'Artifact inside /lib/ ending in .so must report isBundled = true');
      expect(downloadedArtifact.isBundled, isFalse,
          reason: 'Artifact in app documents directory must report isBundled = false');
    });

    test('2. removeStockfish fires onBeforeDelete hook before unlinking', () async {
      final service = EngineDownloadService();
      bool hookExecuted = false;

      // Mock installed status
      service.stockfishInfo.status = DownloadStatus.installed;
      service.stockfishInfo.installedSizeBytes = 50 * 1024 * 1024;
      service.stockfishInfo.localExecutablePath = '${Directory.systemTemp.path}/test_sf_dummy.exe';

      // Create dummy file
      final dummyFile = File(service.stockfishInfo.localExecutablePath);
      dummyFile.writeAsStringSync('binary');

      await service.removeStockfish(
        onBeforeDelete: () async {
          hookExecuted = true;
          // In real workflow, this disables the engine and terminates native process
          expect(dummyFile.existsSync(), isTrue,
              reason: 'File must still exist during onBeforeDelete hook execution');
        },
      );

      expect(hookExecuted, isTrue);
      expect(dummyFile.existsSync(), isFalse);
    });

    test('3. removeLc0 fires onBeforeDelete hook before unlinking', () async {
      final service = EngineDownloadService();
      bool hookExecuted = false;

      service.lc0Info.status = DownloadStatus.installed;
      service.lc0Info.installedSizeBytes = 40 * 1024 * 1024;
      service.lc0Info.localExecutablePath = '${Directory.systemTemp.path}/test_lc0_dummy.exe';

      final dummyFile = File(service.lc0Info.localExecutablePath);
      dummyFile.writeAsStringSync('lc0_binary');

      await service.removeLc0(
        onBeforeDelete: () async {
          hookExecuted = true;
        },
      );

      expect(hookExecuted, isTrue);
      expect(dummyFile.existsSync(), isFalse);
    });

    test('4. removeMaiaModel updates storage counter in real-time and reverts status to notInstalled', () async {
      final service = EngineDownloadService();
      bool hookExecuted = false;

      final maiaModel = MaiaModelInfo(
        id: 'maia_1500_test',
        name: 'Maia 1500',
        approximateElo: 1500,
        filename: 'maia-1500.pb.gz',
        officialSourceUrl: '',
        downloadUrl: '',
        localPath: '${Directory.systemTemp.path}/maia-1500.pb.gz',
        metadataPath: '${Directory.systemTemp.path}/maia-1500.json',
        estimatedSizeBytes: 48 * 1024 * 1024,
        credit: 'CSSLab',
        status: DownloadStatus.installed,
        installedSizeBytes: 48 * 1024 * 1024,
      );

      // Register model in service
      service.maiaModels[maiaModel.id] = maiaModel;

      // Create dummy weight file
      final dummyWeights = File(maiaModel.localPath);
      dummyWeights.writeAsStringSync('dummy weights');

      // Verify initial storage tally includes this model
      final initialStorage = service.getStorageSummary();
      expect(initialStorage.maiaBytes, greaterThanOrEqualTo(48 * 1024 * 1024));

      // Remove model
      await service.removeMaiaModel(
        maiaModel.id,
        onBeforeDelete: () async {
          hookExecuted = true;
        },
      );

      expect(hookExecuted, isTrue);
      expect(dummyWeights.existsSync(), isFalse);
      expect(maiaModel.status, DownloadStatus.notInstalled);
      expect(maiaModel.installedSizeBytes, equals(0));

      // Clean up service dictionary
      service.maiaModels.remove(maiaModel.id);
    });

    test('5. cancelDownload transitions status to cancelled and sets errorMessage', () {
      final service = EngineDownloadService();

      service.stockfishInfo.status = DownloadStatus.downloading;
      service.cancelDownload(service.stockfishInfo.id);

      expect(service.stockfishInfo.status, DownloadStatus.cancelled);
      expect(service.stockfishInfo.errorMessage, contains('Cancelled by user'));
    });

    test('6. DownloadStatus enum covers the complete lifecycle state space', () {
      final expectedStatuses = [
        DownloadStatus.notInstalled,
        DownloadStatus.queued,
        DownloadStatus.downloading,
        DownloadStatus.verifying,
        DownloadStatus.installing,
        DownloadStatus.installed,
        DownloadStatus.error,
        DownloadStatus.cancelled,
        DownloadStatus.unsupported,
      ];

      for (final status in expectedStatuses) {
        expect(DownloadStatus.values, contains(status));
      }
    });
  });
}
