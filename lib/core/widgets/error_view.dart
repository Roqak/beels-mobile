import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../theme.dart';

/// Centered error placeholder with the API message and a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final ApiException error;
  final VoidCallback? onRetry;

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
              error.message,
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
