import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/pgn_parser.dart';

class PgnPasteDialog extends StatefulWidget {
  final void Function(String pgn) onImportPgn;

  const PgnPasteDialog({super.key, required this.onImportPgn});

  @override
  State<PgnPasteDialog> createState() => _PgnPasteDialogState();
}

class _PgnPasteDialogState extends State<PgnPasteDialog> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _controller.text = data.text!;
      });
    }
  }

  void _loadSample(String samplePgn) {
    setState(() {
      _controller.text = samplePgn;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Paste PGN',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.paste, color: Color(0xFF00D2BE), size: 18),
            onPressed: _pasteFromClipboard,
            tooltip: 'Paste from clipboard',
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: const InputDecoration(
                  hintText: 'Paste PGN moves or full PGN game here...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sample Games:',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00D2BE),
                      side: const BorderSide(color: Colors.white24),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    ),
                    onPressed: () => _loadSample(PgnParser.sampleKasparovTopalov),
                    child: const Text('Kasparov Immortal', style: TextStyle(fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00D2BE),
                      side: const BorderSide(color: Colors.white24),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    ),
                    onPressed: () => _loadSample(PgnParser.sampleFischerGameOfCentury),
                    child: const Text('Game of Century', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D2BE),
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            final pgn = _controller.text.trim();
            if (pgn.isNotEmpty) {
              widget.onImportPgn(pgn);
              Navigator.pop(context);
            }
          },
          child: const Text('Import Game', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
