import 'package:flutter/material.dart';

import '../theme.dart';

/// Semantic kinds mapped from raw backend status strings.
enum StatusKind { ok, warn, err, muted }

/// Maps a raw status string to a [StatusKind]:
/// success/completed/active → ok, pending/processing → warn,
/// failed/cancelled/rejected/inactive → err, anything else → muted.
StatusKind statusKind(String status) {
  switch (status.trim().toLowerCase()) {
    case 'success':
    case 'completed':
    case 'active':
      return StatusKind.ok;
    case 'pending':
    case 'processing':
      return StatusKind.warn;
    case 'failed':
    case 'cancelled':
    case 'rejected':
    case 'inactive':
      return StatusKind.err;
    default:
      return StatusKind.muted;
  }
}

/// Small rounded status pill with a colored dot.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.kind});

  final String label;
  final StatusKind kind;

  Color get _strong {
    switch (kind) {
      case StatusKind.ok:
        return BeelsColors.ok;
      case StatusKind.warn:
        return BeelsColors.warn;
      case StatusKind.err:
        return BeelsColors.err;
      case StatusKind.muted:
        return BeelsColors.ink2;
    }
  }

  Color get _soft {
    switch (kind) {
      case StatusKind.ok:
        return BeelsColors.okSoft;
      case StatusKind.warn:
        return BeelsColors.warnSoft;
      case StatusKind.err:
        return BeelsColors.errSoft;
      case StatusKind.muted:
        return BeelsColors.fieldFill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _strong, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _strong,
            ),
          ),
        ],
      ),
    );
  }
}