import 'package:flutter/material.dart';
import '../../services/sound_service.dart';
import '../../services/theme_service.dart';
import '../../theme/lichess_theme.dart';

class ThemeSettingsDialog extends StatefulWidget {
  final ThemeService themeService;
  final SoundService soundService;
  final VoidCallback onThemeChanged;

  const ThemeSettingsDialog({
    super.key,
    required this.themeService,
    required this.soundService,
    required this.onThemeChanged,
  });

  @override
  State<ThemeSettingsDialog> createState() => _ThemeSettingsDialogState();
}

class _ThemeSettingsDialogState extends State<ThemeSettingsDialog> {
  late String _selectedBoardId;
  late String _selectedPieceSet;
  late String _selectedSoundTheme;
  late bool _soundEnabled;
  late double _soundVolume;
  late int _pieceAnimationMs;

  @override
  void initState() {
    super.initState();
    _selectedBoardId = widget.themeService.activeBoard.id;
    _selectedPieceSet = widget.themeService.activePieceSet;
    _selectedSoundTheme = widget.soundService.activeTheme;
    _soundEnabled = widget.soundService.isEnabled;
    _soundVolume = widget.soundService.volume;
    _pieceAnimationMs = widget.themeService.pieceAnimationMs;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LichessColors.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: LichessStyles.cardBorderRadius),
      title: const Text(
        'Board & Appearance Settings',
        style: TextStyle(color: LichessColors.darkText, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Board Themes Grid
              const Text('Board Theme', style: TextStyle(color: LichessColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ThemeService.boardThemes.map((b) {
                  final isSelected = b.id == _selectedBoardId;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedBoardId = b.id),
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: LichessColors.darkSurfaceHigh,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? LichessColors.primary : LichessColors.darkBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: b.isTexture
                                  ? Image.asset(
                                      b.imageAssetPath!,
                                      fit: BoxFit.cover,
                                    )
                                  : Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(width: 17, height: 17, color: b.lightSquare),
                                            Container(width: 17, height: 17, color: b.darkSquare),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Container(width: 17, height: 17, color: b.darkSquare),
                                            Container(width: 17, height: 17, color: b.lightSquare),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b.name.split(' ').first,
                            style: TextStyle(
                              color: isSelected ? LichessColors.primary : LichessColors.darkTextMuted,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 2. Chess Piece Sets
              const Text('Chess Pieces Set', style: TextStyle(color: LichessColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: LichessColors.darkBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: LichessColors.darkBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPieceSet,
                    dropdownColor: LichessColors.darkSurfaceHigh,
                    isExpanded: true,
                    items: ThemeService.pieceSets.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/piece_sets/$p/wN.webp',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.circle, size: 12, color: Colors.white54),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              p[0].toUpperCase() + p.substring(1),
                              style: const TextStyle(color: LichessColors.darkText, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPieceSet = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Move Sounds
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Move Sounds', style: TextStyle(color: LichessColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  Switch(
                    value: _soundEnabled,
                    activeTrackColor: LichessColors.primary,
                    onChanged: (val) => setState(() => _soundEnabled = val),
                  ),
                ],
              ),
              if (_soundEnabled) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: LichessColors.darkBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: LichessColors.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSoundTheme,
                      dropdownColor: LichessColors.darkSurfaceHigh,
                      isExpanded: true,
                      items: ThemeService.soundThemes.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            _soundThemeLabel(s),
                            style: const TextStyle(color: LichessColors.darkText, fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSoundTheme = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.volume_up, size: 16, color: LichessColors.darkTextMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: LichessColors.primary,
                          inactiveTrackColor: LichessColors.darkBorder,
                          thumbColor: LichessColors.primary,
                        ),
                        child: Slider(
                          value: _soundVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          onChanged: (val) => setState(() => _soundVolume = val),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${(_soundVolume * 100).round()}%',
                        style: const TextStyle(color: LichessColors.darkTextMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // 4. Piece Movement Animation Speed
              const Text('Piece Animation', style: TextStyle(color: LichessColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: LichessColors.darkBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: LichessColors.darkBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pieceAnimationMs,
                    dropdownColor: LichessColors.darkSurfaceHigh,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 200, child: Text('Smooth (200ms - Default)', style: TextStyle(color: LichessColors.darkText, fontSize: 12))),
                      DropdownMenuItem(value: 120, child: Text('Fast (120ms)', style: TextStyle(color: LichessColors.darkText, fontSize: 12))),
                      DropdownMenuItem(value: 320, child: Text('Cinematic (320ms)', style: TextStyle(color: LichessColors.darkText, fontSize: 12))),
                      DropdownMenuItem(value: 0, child: Text('Instant / Disabled (0ms)', style: TextStyle(color: LichessColors.darkText, fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _pieceAnimationMs = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: LichessColors.darkTextMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LichessColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            widget.themeService.activeBoard = widget.themeService.getBoardTheme(_selectedBoardId);
            widget.themeService.activePieceSet = _selectedPieceSet;
            widget.themeService.pieceAnimationMs = _pieceAnimationMs;
            widget.soundService.setVolume(_soundVolume);
            widget.soundService.activeTheme = _selectedSoundTheme;
            widget.soundService.isEnabled = _soundEnabled;
            widget.onThemeChanged();
            Navigator.pop(context);
          },
          child: const Text('Apply Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  String _soundThemeLabel(String id) {
    switch (id) {
      case 'standard':
        return 'Standard (Authentic Wood)';
      case 'futuristic':
        return 'Futuristic (Synth)';
      case 'nes':
        return 'Retro 8-Bit';
      case 'piano':
        return 'Acoustic Piano';
      case 'sfx':
        return 'Arcade SFX';
      case 'silent':
        return 'Silent (Mute)';
      default:
        return id[0].toUpperCase() + id.substring(1);
    }
  }
}
