import 'package:flutter/material.dart';

/// Inline error banner for auth forms; colors are the shared err tokens
/// (#B23A3A on #FBEDED).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const errorColor = Color(0xFFB23A3A);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEDED),
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
    );
  }
}