import 'package:flutter/material.dart';

class ChessCrackAboutDialog extends StatelessWidget {
  const ChessCrackAboutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ChessCrackAboutDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF333333), width: 1),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icon/chesscrack_icon.png',
              width: 38,
              height: 38,
              errorBuilder: (_, __, ___) => const Icon(Icons.psychology, color: Color(0xFF00D2BE), size: 36),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ChessCrack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'v1.0.0 • Offline Analysis Workbench',
                  style: TextStyle(
                    color: Color(0xFF00D2BE),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A high-performance, offline chess analysis workbench and neural network study utility for Android.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              _buildSectionHeader('ZERO-BINARY BASE PACKAGING'),
              const Text(
                'ChessCrack contains no bundled engines or neural networks in the base package. Stockfish, Leela Chess Zero, and Maia models are downloaded on-demand directly from official upstream releases with integrity verification.',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 12),
              _buildSectionHeader('PRIVACY & PERMISSIONS'),
              const Text(
                '• INTERNET: Only used to download user-selected engines & Maia weights from official sources. All analysis runs 100% offline on-device.\n• VIBRATE: Tactile feedback on moves.\n• Zero tracking, zero telemetry, zero advertisements.',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 12),
              _buildSectionHeader('UPSTREAM ACKNOWLEDGMENTS'),
              const Text(
                '• Stockfish: Official Stockfish developers (GPLv3)\n• Leela Chess Zero (Lc0): Lc0 contributors (GPLv3)\n• Maia Chess: CSSLab, University of Toronto\n• Nibbler GUI: Inspiration by Tomas Rokicki (GPLv3)\n• Board Assets & Sounds: Lichess.org (CC-BY-SA)',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 12),
              _buildSectionHeader('LICENSE'),
              const Text(
                'Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later).',
                style: TextStyle(color: Color(0xFF00D2BE), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            showLicensePage(
              context: context,
              applicationName: 'ChessCrack',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 ChessCrack Contributors\nLicensed under GNU GPLv3',
            );
          },
          child: const Text('View Licenses', style: TextStyle(color: Color(0xFF00D2BE), fontSize: 13)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C2C2C),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
