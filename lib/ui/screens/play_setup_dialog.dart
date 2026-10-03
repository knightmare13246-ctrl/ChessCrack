import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/chess_move.dart';
import '../../models/chess_time_control.dart';
import '../../models/engine_analysis.dart';
import '../../models/engine_settings.dart';
import '../../services/engine_download_service.dart';
import '../../services/uci_engine_service.dart';

class PlayGameConfig {
  final EngineType opponentEngine;
  final PieceColor playerColor;
  final ChessTimeControl timeControl;
  final bool limitStrength;
  final int? stockfishElo;
  final String? selectedMaiaId;
  final MaiaThinkingProfile maiaThinkingProfile;

  const PlayGameConfig({
    required this.opponentEngine,
    required this.playerColor,
    required this.timeControl,
    this.limitStrength = false,
    this.stockfishElo,
    this.selectedMaiaId,
    this.maiaThinkingProfile = MaiaThinkingProfile.humanLike,
  });
}

class PlaySetupDialog extends StatefulWidget {
  final UciEngineService engineService;
  final EngineDownloadService downloadService;

  const PlaySetupDialog({
    super.key,
    required this.engineService,
    required this.downloadService,
  });

  static Future<PlayGameConfig?> show(
    BuildContext context, {
    required UciEngineService engineService,
    required EngineDownloadService downloadService,
  }) {
    return showDialog<PlayGameConfig>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PlaySetupDialog(
        engineService: engineService,
        downloadService: downloadService,
      ),
    );
  }

  @override
  State<PlaySetupDialog> createState() => _PlaySetupDialogState();
}

class _PlaySetupDialogState extends State<PlaySetupDialog> {
  EngineType _selectedOpponent = EngineType.stockfish;
  String _sideChoice = 'random'; // 'white', 'black', 'random'
  ChessTimeControl _selectedTimeControl = ChessTimeControl.blitz5_0;

  // Stockfish Elo settings
  bool _limitStockfishStrength = true;
  double _stockfishElo = 1500;

  // Maia settings
  String _selectedMaiaId = 'maia_1500';
  MaiaThinkingProfile _maiaProfile = MaiaThinkingProfile.humanLike;

  // Custom time control
  bool _isCustomTimeControl = false;
  int _customMinutes = 5;
  int _customIncrementSeconds = 3;

  @override
  void initState() {
    super.initState();
    final minE = widget.engineService.minElo ?? 1320;
    final maxE = widget.engineService.maxElo ?? 3190;
    _stockfishElo = _stockfishElo.clamp(minE.toDouble(), maxE.toDouble());

    // Prefer installed Maia models if available
    final installedMaia = widget.downloadService.getInstalledMaiaModels();
    if (installedMaia.isNotEmpty) {
      _selectedMaiaId = installedMaia.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final minElo = (widget.engineService.minElo ?? 1320).toDouble();
    final maxElo = (widget.engineService.maxElo ?? 3190).toDouble();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF333333)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D2BE).withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sports_esports, color: Color(0xFF00D2BE), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Play with Engine',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Genuine offline engine opponent',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Content scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Opponent Selector
                      _buildSectionTitle('CHOOSE OPPONENT'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildOpponentTab(EngineType.stockfish, 'Stockfish', Icons.bolt),
                          const SizedBox(width: 8),
                          _buildOpponentTab(EngineType.lc0, 'Maia', Icons.person),
                          const SizedBox(width: 8),
                          _buildOpponentTab(EngineType.lc0, 'Lc0', Icons.psychology, isPureLc0: true),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Opponent-specific settings
                      if (_selectedOpponent == EngineType.stockfish) ...[
                        _buildStockfishSettings(minElo, maxElo),
                      ] else if (_isMaiaMode) ...[
                        _buildMaiaSettings(),
                      ] else ...[
                        _buildLc0Settings(),
                      ],
                      const SizedBox(height: 16),

                      // Side Selector
                      _buildSectionTitle('PLAY AS'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSideButton('white', 'White', '♔'),
                          const SizedBox(width: 8),
                          _buildSideButton('random', 'Random', '⯪'),
                          const SizedBox(width: 8),
                          _buildSideButton('black', 'Black', '♚'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Time Control Selector
                      _buildSectionTitle('TIME CONTROL'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTcChip(ChessTimeControl.hyperbullet30s),
                          _buildTcChip(ChessTimeControl.bullet1_0),
                          _buildTcChip(ChessTimeControl.bullet2_1),
                          _buildTcChip(ChessTimeControl.blitz3_0),
                          _buildTcChip(ChessTimeControl.blitz3_2),
                          _buildTcChip(ChessTimeControl.blitz5_0),
                          _buildTcChip(ChessTimeControl.blitz5_3),
                          _buildTcChip(ChessTimeControl.rapid10_0),
                          _buildTcChip(ChessTimeControl.rapid15_10),
                          _buildTcChip(ChessTimeControl.unlimitedPreset),
                          _buildCustomTcChip(),
                        ],
                      ),

                      if (_isCustomTimeControl) ...[
                        const SizedBox(height: 12),
                        _buildCustomTcSliders(),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D2BE),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text(
                      'START GAME',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    onPressed: _onStartPressed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isMaiaMode => _selectedOpponent == EngineType.lc0 && _selectedMaiaId.isNotEmpty && !_isPureLc0;
  bool _isPureLc0 = false;

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00D2BE),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildOpponentTab(EngineType type, String label, IconData icon, {bool isPureLc0 = false}) {
    final isSelected = _selectedOpponent == type && _isPureLc0 == isPureLc0;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedOpponent = type;
              _isPureLc0 = isPureLc0;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00D2BE).withAlpha(35) : const Color(0xFF262626),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF00D2BE) : const Color(0xFF383838),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: isSelected ? const Color(0xFF00D2BE) : Colors.white70, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockfishSettings(double minElo, double maxElo) {
    final supportsLimit = widget.engineService.supportsLimitStrength;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Strength Control',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _limitStockfishStrength
                        ? 'Stockfish • Elo limit ${_stockfishElo.round()}'
                        : 'Stockfish • Full Strength',
                    style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 12),
                  ),
                ],
              ),
              Switch(
                value: _limitStockfishStrength,
                activeThumbColor: const Color(0xFF00D2BE),
                onChanged: supportsLimit
                    ? (val) => setState(() => _limitStockfishStrength = val)
                    : null,
              ),
            ],
          ),
          if (_limitStockfishStrength) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${minElo.round()}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _stockfishElo.clamp(minElo, maxElo),
                    min: minElo,
                    max: maxElo,
                    divisions: math.max(1, ((maxElo - minElo) ~/ 25)),
                    activeColor: const Color(0xFF00D2BE),
                    inactiveColor: Colors.white12,
                    label: '${_stockfishElo.round()}',
                    onChanged: (v) => setState(() => _stockfishElo = v),
                  ),
                ),
                Text('${maxElo.round()}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaiaSettings() {
    final maiaList = widget.downloadService.maiaModels.values.toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maia Human Sparring Model',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: maiaList.any((m) => m.id == _selectedMaiaId) ? _selectedMaiaId : null,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: const Color(0xFF1B1B1B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            dropdownColor: const Color(0xFF222222),
            items: maiaList.map((m) {
              return DropdownMenuItem(
                value: m.id,
                child: Text(
                  '${m.name} ${m.isInstalled ? "(Installed)" : "(Download needed)"}',
                  style: TextStyle(
                    color: m.isInstalled ? Colors.white : Colors.amber,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedMaiaId = val);
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Thinking Pace',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildMaiaProfileRadio(MaiaThinkingProfile.instant, 'Instant'),
              const SizedBox(width: 8),
              _buildMaiaProfileRadio(MaiaThinkingProfile.natural, 'Natural'),
              const SizedBox(width: 8),
              _buildMaiaProfileRadio(MaiaThinkingProfile.humanLike, 'Human-like'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaiaProfileRadio(MaiaThinkingProfile profile, String label) {
    final isSelected = _maiaProfile == profile;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _maiaProfile = profile),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00D2BE).withAlpha(30) : const Color(0xFF1B1B1B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? const Color(0xFF00D2BE) : Colors.white12,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00D2BE) : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLc0Settings() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF00D2BE), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Lc0 plays with your installed neural network weights and settings.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideButton(String id, String label, String pieceSymbol) {
    final isSelected = _sideChoice == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sideChoice = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00D2BE).withAlpha(35) : const Color(0xFF262626),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF00D2BE) : const Color(0xFF383838),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(pieceSymbol, style: const TextStyle(fontSize: 18, color: Colors.white)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTcChip(ChessTimeControl tc) {
    final isSelected = !_isCustomTimeControl && _selectedTimeControl == tc;
    return ChoiceChip(
      label: Text(tc.displayName),
      selected: isSelected,
      selectedColor: const Color(0xFF00D2BE),
      backgroundColor: const Color(0xFF262626),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _isCustomTimeControl = false;
          _selectedTimeControl = tc;
        });
      },
    );
  }

  Widget _buildCustomTcChip() {
    return ChoiceChip(
      label: const Text('Custom'),
      selected: _isCustomTimeControl,
      selectedColor: const Color(0xFF00D2BE),
      backgroundColor: const Color(0xFF262626),
      labelStyle: TextStyle(
        color: _isCustomTimeControl ? Colors.black : Colors.white70,
        fontWeight: _isCustomTimeControl ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() => _isCustomTimeControl = true);
      },
    );
  }

  Widget _buildCustomTcSliders() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Minutes:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('$_customMinutes min', style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _customMinutes.toDouble(),
            min: 1,
            max: 60,
            activeColor: const Color(0xFF00D2BE),
            onChanged: (v) => setState(() => _customMinutes = v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Increment:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('$_customIncrementSeconds s', style: const TextStyle(color: Color(0xFF00D2BE), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _customIncrementSeconds.toDouble(),
            min: 0,
            max: 30,
            activeColor: const Color(0xFF00D2BE),
            onChanged: (v) => setState(() => _customIncrementSeconds = v.round()),
          ),
        ],
      ),
    );
  }

  void _onStartPressed() {
    PieceColor color;
    if (_sideChoice == 'white') {
      color = PieceColor.white;
    } else if (_sideChoice == 'black') {
      color = PieceColor.black;
    } else {
      color = math.Random().nextBool() ? PieceColor.white : PieceColor.black;
    }

    ChessTimeControl tc;
    if (_isCustomTimeControl) {
      tc = ChessTimeControl.custom(
        baseMinutes: _customMinutes,
        incrementSeconds: _customIncrementSeconds,
      );
    } else {
      tc = _selectedTimeControl;
    }

    final config = PlayGameConfig(
      opponentEngine: _selectedOpponent,
      playerColor: color,
      timeControl: tc,
      limitStrength: _selectedOpponent == EngineType.stockfish && _limitStockfishStrength,
      stockfishElo: _selectedOpponent == EngineType.stockfish && _limitStockfishStrength
          ? _stockfishElo.round()
          : null,
      selectedMaiaId: _isMaiaMode ? _selectedMaiaId : null,
      maiaThinkingProfile: _maiaProfile,
    );

    Navigator.of(context).pop(config);
  }
}
