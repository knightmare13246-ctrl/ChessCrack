import 'package:flutter/material.dart';

/// Reusable chess move token matching the professional visual reference layout.
/// Displays an optional move number prefix (e.g. "37... " or "38. ")
/// alongside the figurine SAN token with subtle selection highlighting,
/// compact padding, and touch/hover feedback without heavy button chrome.
class ChessMoveToken extends StatelessWidget {
  final String? prefix;
  final String text; // Figurine SAN or standard SAN
  final bool isSelected;
  final bool isVariation;
  final VoidCallback? onTap;
  final double fontSize;
  final TextStyle? customStyle;

  const ChessMoveToken({
    super.key,
    this.prefix,
    required this.text,
    this.isSelected = false,
    this.isVariation = false,
    this.onTap,
    this.fontSize = 12.0,
    this.customStyle,
  });

  @override
  Widget build(BuildContext context) {
    final tokenContainer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF005FB8) : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: customStyle ??
            TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isVariation ? const Color(0xFF9CDCFE) : const Color(0xFFE2E2E2)),
              fontFamily: 'monospace',
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              height: 1.25,
            ),
      ),
    );

    Widget content;
    if (prefix == null || prefix!.isEmpty) {
      content = tokenContainer;
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            prefix!,
            style: TextStyle(
              color: const Color(0xFF888888),
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              height: 1.25,
            ),
          ),
          tokenContainer,
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }

  /// Convenience helper to create a WidgetSpan for use in Text.rich / SelectableText.rich
  WidgetSpan toSpan() {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: this,
    );
  }
}
