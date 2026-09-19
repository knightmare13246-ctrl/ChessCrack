import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NibblerFenBar extends StatelessWidget {
  final String fen;

  const NibblerFenBar({super.key, required this.fen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: fen));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('FEN copied to clipboard'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        color: Colors.black,
        child: Row(
          children: [
            Expanded(
              child: Text(
                fen,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF00D2BE),
                  fontFamily: 'monospace',
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.copy,
              color: Color(0xFF00D2BE),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }
}
