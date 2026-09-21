import 'package:flutter/material.dart';
import 'package:beels_mobile/core/theme.dart';

/// Inline error banner for auth forms; colors are the shared err tokens
/// (#B23A3A on #FBEDED).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const errorColor = BeelsColors.err;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BeelsColors.errSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: errorColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: errorColor, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
