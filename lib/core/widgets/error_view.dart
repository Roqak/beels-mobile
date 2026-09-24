import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../theme.dart';

/// Centered error placeholder with a friendly message and a retry button.
///
/// Accepts any thrown object and normalizes it internally, so call sites
/// never need `error as ApiException` casts (which crash on unexpected
/// errors like malformed payloads).
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  /// Friendly user copy for the given error; developer-ish details
  /// (raw exception text, payload errors) never reach the screen.
  static ApiException normalize(Object error) {
    final e = error;
    if (e is ApiException) {
      if (e.statusCode == 0) return e; // already user-facing copy
      return e;
    }
    return const ApiException(
      'Something went wrong. Please try again.',
      statusCode: 0,
    );
  }

  ApiException get _normalized => normalize(error);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: BeelsColors.errSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: BeelsColors.err,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: BeelsColors.ink0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _normalized.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, height: 1.45, color: BeelsColors.ink1),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
