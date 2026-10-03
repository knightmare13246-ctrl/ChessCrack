import 'package:flutter/material.dart';
import '../../models/engine_analysis.dart';
import '../../models/engine_download_model.dart';
import '../../models/engine_settings.dart';
import '../../services/engine_download_service.dart';

class EngineManagerDialog extends StatefulWidget {
  final EngineSettings settings;
  final void Function(EngineSettings newSettings) onSettingsChanged;
  final Future<void> Function()? onBeforeEngineRemoved;

  const EngineManagerDialog({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.onBeforeEngineRemoved,
  });

  static Future<void> show(
    BuildContext context, {
    required EngineSettings settings,
    required void Function(EngineSettings newSettings) onSettingsChanged,
    Future<void> Function()? onBeforeEngineRemoved,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EngineManagerDialog(
        settings: settings,
        onSettingsChanged: onSettingsChanged,
        onBeforeEngineRemoved: onBeforeEngineRemoved,
      ),
    );
  }

  @override
  State<EngineManagerDialog> createState() => _EngineManagerDialogState();
}

class _EngineManagerDialogState extends State<EngineManagerDialog> {
  final EngineDownloadService _downloadService = EngineDownloadService();
  late EngineSettings _currentSettings;

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings;
    _downloadService.addListener(_onServiceUpdate);
    _downloadService.refreshStatuses();
  }

  @override
  void dispose() {
    _downloadService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _selectEngine(EngineType type) {
    String? resolvedWeights;
    if (type == EngineType.lc0) {
      final installedNets = _downloadService.getInstalledMaiaModels();
      if (installedNets.isNotEmpty) {
        resolvedWeights = installedNets.first.localPath;
      }
    }
    setState(() {
      _currentSettings = _currentSettings.copyWith(
        activeEngine: type,
        selectedMaiaId: null,
        weightsPath: resolvedWeights,
        nodeLimit: null,
      );
    });
    widget.onSettingsChanged(_currentSettings);
  }

  void _selectMaiaModel(MaiaModelInfo model) {
    setState(() {
      _currentSettings = _currentSettings.copyWith(
        activeEngine: EngineType.lc0,
        selectedMaiaId: model.id,
        weightsPath: model.localPath,
        nodeLimit: 1, // Official requirement: Run at Nodes = 1
      );
    });
    widget.onSettingsChanged(_currentSettings);
  }

  @override
  Widget build(BuildContext context) {
    final storage = _downloadService.getStorageSummary();
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final viewInsets = mediaQuery.viewInsets;
    final safePadding = mediaQuery.padding;

    // Usable screen area safely bounded away from status bars, nav bars, notches
    final safeWidth = screenWidth - safePadding.horizontal;
    final safeHeight = screenHeight - safePadding.vertical - viewInsets.vertical;

    final isLandscape = screenWidth > screenHeight;
    final isTablet = screenWidth >= 600;

    // Responsive dialog sizing:
    // On phones: dialog fills comfortable width (with 8-12px side padding) and safe height.
    // On tablets/foldables: centered comfortable modal.
    final double dialogWidth = isTablet ? 580.0 : (safeWidth - 16.0).clamp(280.0, 560.0);
    final double dialogHeight = isLandscape
        ? (safeHeight - 16.0).clamp(280.0, safeHeight)
        : (safeHeight - 24.0).clamp(420.0, safeHeight);

    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? ((screenWidth - dialogWidth) / 2).clamp(16.0, 200.0) : 8.0,
        vertical: isLandscape ? 8.0 : 12.0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. FIXED HEADER (Never scrolled)
              _buildHeader(context),

              // 2. SCROLLABLE MIDDLE CONTENT (Single scroll container)
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                  children: [
                    // Section 1: Real Engines
                    _buildSectionHeader('REAL UCI ENGINES', Icons.developer_board),
                    const SizedBox(height: 8),
                    _buildEngineCard(
                      info: _downloadService.stockfishInfo,
                      engineType: EngineType.stockfish,
                      displayName: 'Stockfish 19',
                      subtitle: 'Latest official stable release',
                      onDownload: () => _downloadService.downloadStockfish(),
                      onRemove: () => _downloadService.removeStockfish(
                        onBeforeDelete: widget.onBeforeEngineRemoved,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEngineCard(
                      info: _downloadService.lc0Info,
                      engineType: EngineType.lc0,
                      displayName: 'Leela Chess Zero',
                      subtitle: 'Latest official stable release',
                      onDownload: () => _downloadService.downloadLc0(),
                      onRemove: () => _downloadService.removeLc0(
                        onBeforeDelete: widget.onBeforeEngineRemoved,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section 2: Human Sparring / Maia Networks
                    _buildSectionHeader('MAIA HUMAN SPARRING NETWORKS', Icons.psychology),
                    const SizedBox(height: 6),
                    _buildMaiaInfoCard(),
                    const SizedBox(height: 10),

                    // All Maia model cards
                    ..._downloadService.maiaModels.values.map((model) => _buildMaiaCard(model)),

                    const SizedBox(height: 20),

                    // Section 3: Maia Human Behavior Analysis (Moves by Rating)
                    _buildSectionHeader('HUMAN BEHAVIOR ANALYSIS (MOVES BY RATING)', Icons.insights),
                    const SizedBox(height: 6),
                    _buildMaiaRatingInfoCard(),
                    const SizedBox(height: 10),
                    _buildMaiaRatingModelCard(_downloadService.maiaRatingModelInfo),

                    // Bottom margin inside scroll area to guarantee the last card clears the footer
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // 3. FIXED FOOTER (Storage Summary & Done Button)
              _buildFooter(context, storage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF202020),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2C), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF142B28),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.memory, color: Color(0xFF00D2BE), size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ENGINE & NETWORK MANAGER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Modular offline UCI engines and human sparring networks',
                  style: TextStyle(color: Colors.white54, fontSize: 10.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00D2BE), size: 15),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00D2BE),
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildMaiaInfoCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF132220),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF00D2BE).withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF00D2BE), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Maia networks run inside Leela Chess Zero at Nodes = 1. Download Lc0 once, then download and switch between Maia networks instantly.',
              style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineCard({
    required EngineArtifactInfo info,
    required EngineType engineType,
    required String displayName,
    required String subtitle,
    required VoidCallback onDownload,
    required VoidCallback onRemove,
  }) {
    final isSelected = _currentSettings.activeEngine == engineType && _currentSettings.selectedMaiaId == null;
    final isInstalled = info.isInstalled;
    final isDownloading = info.isDownloading;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xFF00D2BE) : const Color(0xFF303030),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tier 1: Prominent Engine Header (Icon + Full Unclipped Title + Subtitle)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF003830) : const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00D2BE).withValues(alpha: 0.5) : const Color(0xFF383838),
                  ),
                ),
                child: Icon(
                  engineType == EngineType.stockfish ? Icons.hardware : Icons.memory,
                  color: isSelected ? const Color(0xFF00D2BE) : Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Tier 2: Metadata Badges (Version · Status · Size) in a wrap to prevent any horizontal collision
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildBadge(info.version, const Color(0xFF00D2BE), const Color(0xFF1B2E2B)),
              if (isInstalled)
                _buildBadge(
                  'Installed (${EngineStorageSummary.formatBytes(info.installedSizeBytes)})',
                  const Color(0xFF81C784),
                  const Color(0xFF1B3B2B),
                  icon: Icons.check_circle_outline,
                )
              else if (info.status == DownloadStatus.unsupported)
                _buildBadge('Architecture unsupported', Colors.amberAccent, const Color(0xFF332A00), icon: Icons.block)
              else if (!isDownloading)
                _buildBadge('Not installed', Colors.white54, const Color(0xFF262626)),
            ],
          ),

          // Downloading progress bar (if active)
          if (isDownloading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: info.progress > 0 ? info.progress : null,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D2BE)),
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    info.status == DownloadStatus.verifying
                        ? 'Verifying UCI engine response...'
                        : (info.status == DownloadStatus.installing
                            ? 'Extracting native binary...'
                            : 'Downloading: ${(info.progress * 100).toStringAsFixed(0)}%'),
                    style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 10.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  info.totalBytes > 0
                      ? '${EngineStorageSummary.formatBytes(info.bytesReceived)} / ${EngineStorageSummary.formatBytes(info.totalBytes)}'
                      : '',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
            ),
          ],

          if (info.errorMessage != null && !isDownloading) ...[
            const SizedBox(height: 6),
            Text(
              info.status == DownloadStatus.unsupported
                  ? info.errorMessage!
                  : 'Error: ${info.errorMessage}',
              style: TextStyle(
                color: info.status == DownloadStatus.unsupported ? Colors.amberAccent : Colors.redAccent,
                fontSize: 10.5,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Tier 3: Action Controls Row (Spacious & Separated from text)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Main Action Button
              if (isDownloading)
                OutlinedButton.icon(
                  onPressed: () => _downloadService.cancelDownload(info.id),
                  icon: const Icon(Icons.cancel, size: 14, color: Colors.orangeAccent),
                  label: const Text('CANCEL', style: TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orangeAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else if (info.status == DownloadStatus.unsupported)
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.block, size: 14, color: Colors.white38),
                  label: const Text('UNAVAILABLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else if (!isInstalled)
                ElevatedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('DOWNLOAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005FB8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003830),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF00D2BE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 13, color: Color(0xFF00D2BE)),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE ENGINE',
                        style: TextStyle(
                          color: Color(0xFF00D2BE),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _selectEngine(engineType),
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: const Text('SELECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00D2BE),
                    side: const BorderSide(color: Color(0xFF00D2BE)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    visualDensity: VisualDensity.compact,
                  ),
                ),

              // Action or delete button (only when installed and not currently downloading)
              if (isInstalled && !isDownloading)
                if (info.isBundled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 13, color: Color(0xFF81C784)),
                        SizedBox(width: 4),
                        Text(
                          'INCLUDED IN APP',
                          style: TextStyle(color: Color(0xFF81C784), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _confirmRemove(
                      title: 'Remove ${info.name}?',
                      content: 'This will delete the local executable (${EngineStorageSummary.formatBytes(info.installedSizeBytes)}) from private storage. You can re-download it anytime.',
                      onConfirm: onRemove,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                    label: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaiaCard(MaiaModelInfo model) {
    final isSelected = _currentSettings.activeEngine == EngineType.lc0 && _currentSettings.selectedMaiaId == model.id;
    final isInstalled = model.isInstalled;
    final isDownloading = model.isDownloading;
    final lc0Installed = _downloadService.lc0Info.isInstalled;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF00D2BE) : const Color(0xFF2C2C2C),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tier 1: Circle Level Badge + Maia Title + Metadata Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF003830) : const Color(0xFF282828),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00D2BE) : const Color(0xFF383838),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${model.approximateElo ~/ 100}',
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00D2BE) : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Badges in a Wrap: Elo, Nodes = 1, Installed / Size (NO overlap possible)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildBadge('Elo ~${model.approximateElo}', const Color(0xFF00D2BE), const Color(0xFF162B28)),
                        _buildBadge('Nodes = 1', const Color(0xFF80CBC4), const Color(0xFF142926)),
                        if (isInstalled)
                          _buildBadge(
                            'Installed (${EngineStorageSummary.formatBytes(model.installedSizeBytes)})',
                            const Color(0xFF81C784),
                            const Color(0xFF1A3326),
                            icon: Icons.check,
                          )
                        else
                          _buildBadge('Size: ~12 MB', Colors.white54, const Color(0xFF262626)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Downloading progress bar (if active)
          if (isDownloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: model.progress > 0 ? model.progress : null,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D2BE)),
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloading: ${(model.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 10),
                ),
                Text(
                  model.totalBytes > 0
                      ? '${EngineStorageSummary.formatBytes(model.bytesReceived)} / ${EngineStorageSummary.formatBytes(model.totalBytes)}'
                      : '',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
            ),
          ],

          if (model.errorMessage != null && !isDownloading) ...[
            const SizedBox(height: 4),
            Text(
              'Error: ${model.errorMessage}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 9.5),
            ),
          ],

          const SizedBox(height: 8),

          // Tier 3: Action Controls Row (Cleanly separated from metadata badges)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isDownloading)
                OutlinedButton.icon(
                  onPressed: () => _downloadService.cancelDownload(model.id),
                  icon: const Icon(Icons.cancel, size: 13, color: Colors.orangeAccent),
                  label: const Text('CANCEL', style: TextStyle(fontSize: 10.5, color: Colors.orangeAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orangeAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else if (!isInstalled)
                ElevatedButton.icon(
                  onPressed: () => _downloadService.downloadMaiaModel(model.id),
                  icon: const Icon(Icons.download, size: 13),
                  label: const Text('GET', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005FB8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003830),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF00D2BE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: Color(0xFF00D2BE)),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE NETWORK',
                        style: TextStyle(color: Color(0xFF00D2BE), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    if (!lc0Installed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please download the Lc0 engine first to run Maia networks.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }
                    _selectMaiaModel(model);
                  },
                  icon: const Icon(Icons.play_arrow, size: 13),
                  label: const Text('SELECT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00D2BE),
                    side: const BorderSide(color: Color(0xFF00D2BE)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),

              if (isInstalled && !isDownloading)
                TextButton.icon(
                  onPressed: () => _confirmRemove(
                    title: 'Remove ${model.name}?',
                    content: 'This will delete the local neural network file (${model.filename}). Lc0 engine will stay installed.',
                    onConfirm: () async {
                      if (_currentSettings.selectedMaiaId == model.id) {
                        _currentSettings = _currentSettings.copyWith(
                          selectedMaiaId: null,
                          weightsPath: null,
                          activeEngine: EngineType.stockfish,
                        );
                        widget.onSettingsChanged(_currentSettings);
                      }
                      await _downloadService.removeMaiaModel(
                        model.id,
                        onBeforeDelete: widget.onBeforeEngineRemoved,
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                  label: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaiaRatingInfoCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF132220),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF00D2BE).withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_graph, color: Color(0xFF00D2BE), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Powers the "Moves by Rating" human-behavior analysis graph. The Maia-3 neural network (CSSLab / ICLR 2026) directly predicts human move probability distributions conditioned on player ratings from 600 to 2600 Elo.',
              style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaiaRatingModelCard(EngineArtifactInfo info) {
    final isInstalled = info.isInstalled;
    final isDownloading = info.isDownloading;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isInstalled ? const Color(0xFF00D2BE).withValues(alpha: 0.5) : const Color(0xFF2C2C2C),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isInstalled ? const Color(0xFF003830) : const Color(0xFF282828),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isInstalled ? const Color(0xFF00D2BE) : const Color(0xFF383838),
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.show_chart, color: Color(0xFF00D2BE), size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.version,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildBadge('Elo 600-2600', const Color(0xFF00D2BE), const Color(0xFF162B28)),
                        _buildBadge('ONNX Runtime', const Color(0xFF80CBC4), const Color(0xFF142926)),
                        if (isInstalled)
                          _buildBadge(
                            'Installed (${EngineStorageSummary.formatBytes(info.installedSizeBytes)})',
                            const Color(0xFF81C784),
                            const Color(0xFF1A3326),
                            icon: Icons.check,
                          )
                        else
                          _buildBadge('Size: ~44 MB', Colors.white54, const Color(0xFF262626)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isDownloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: info.progress > 0 ? info.progress : null,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D2BE)),
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloading: ${(info.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 10),
                ),
                Text(
                  info.totalBytes > 0
                      ? '${EngineStorageSummary.formatBytes(info.bytesReceived)} / ${EngineStorageSummary.formatBytes(info.totalBytes)}'
                      : '',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
            ),
          ],

          if (info.errorMessage != null && !isDownloading) ...[
            const SizedBox(height: 4),
            Text(
              'Error: ${info.errorMessage}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 9.5),
            ),
          ],

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isDownloading)
                OutlinedButton.icon(
                  onPressed: () => _downloadService.cancelDownload(info.id),
                  icon: const Icon(Icons.cancel, size: 13, color: Colors.orangeAccent),
                  label: const Text('CANCEL', style: TextStyle(fontSize: 10.5, color: Colors.orangeAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orangeAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else if (!isInstalled)
                ElevatedButton.icon(
                  onPressed: () => _downloadService.downloadMaiaRatingModel(),
                  icon: const Icon(Icons.download, size: 13),
                  label: const Text('DOWNLOAD', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005FB8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003830),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF00D2BE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Color(0xFF00D2BE)),
                      SizedBox(width: 4),
                      Text(
                        'ANALYSIS READY',
                        style: TextStyle(color: Color(0xFF00D2BE), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              if (isInstalled && !isDownloading)
                TextButton.icon(
                  onPressed: () => _confirmRemove(
                    title: 'Remove Maia-3 Rating Model?',
                    content: 'This will delete the local neural network file (${info.filename}, ${EngineStorageSummary.formatBytes(info.installedSizeBytes)}). The "Moves by Rating" chart will prompt to re-download when opened.',
                    onConfirm: () async {
                      await _downloadService.deleteMaiaRatingModel();
                      if (mounted) setState(() {});
                    },
                  ),
                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                  label: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, EngineStorageSummary storage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: Color(0xFF2C2C2C), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage, color: Color(0xFF00D2BE), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'SF: ${EngineStorageSummary.formatBytes(storage.stockfishBytes)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lc0: ${EngineStorageSummary.formatBytes(storage.lc0Bytes)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nets: ${EngineStorageSummary.formatBytes(storage.maiaBytes)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Maia-3: ${EngineStorageSummary.formatBytes(storage.maia3Bytes)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Total Storage: ${EngineStorageSummary.formatBytes(storage.totalBytes)}',
                  style: const TextStyle(
                    color: Color(0xFF00D2BE),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003830),
              foregroundColor: const Color(0xFF00D2BE),
              side: const BorderSide(color: Color(0xFF00D2BE), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              visualDensity: VisualDensity.compact,
              elevation: 0,
            ),
            child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _confirmRemove({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        content: Text(content, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: const Text('REMOVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
