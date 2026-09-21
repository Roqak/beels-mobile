import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/money.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/adire_pattern.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../auth/widgets/error_banner.dart';
import '../beel_draft.dart';
import '../beel_draft_controller.dart';

/// Step 5: everything in one place before it is created. Each section has an
/// Edit button that jumps back to the step that owns it.
class ReviewStep extends ConsumerWidget {
  const ReviewStep({
    super.key,
    required this.onEdit,
    this.submitError,
    this.now,
  });

  /// Jumps to a step index (0 basics, 1 schedule, 2 people, 3 payout).
  final ValueChanged<int> onEdit;
  final String? submitError;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(beelDraftProvider);
    final next = nextRun(d, now ?? DateTime.now());
    final target = d.target ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (submitError != null) ...[
          ErrorBanner(message: submitError!),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: BeelsColors.dye)),
                const Positioned.fill(child: AdirePattern(cell: 26)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          d.isOpen ? 'Open link' : 'People you chose',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        d.name.trim(),
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatNaira(target),
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 40,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recurrenceSentence(d) +
                            (next == null
                                ? ''
                                : ' · next ${DateFormat('d MMM').format(next)}'),
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.75)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Schedule',
          onEdit: () => onEdit(1),
          children: [_Line(recurrenceSentence(d), null)],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Who pays',
          onEdit: () => onEdit(2),
          children: d.isOpen
              ? [
                  _Line(
                    'Anyone with your link',
                    d.perPersonPreview == null
                        ? null
                        : '${formatNaira((d.perPersonPreview! * 100).round() / 100)} each',
                  ),
                ]
              : [
                  for (var i = 0; i < d.contributors.length; i++)
                    _Line(
                      d.contributors[i].fullName,
                      formatNaira(d.effectiveContributorAmount(i) ?? 0),
                    ),
                ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Who gets paid',
          onEdit: () => onEdit(3),
          children: [
            for (final b in d.beneficiaries)
              _Line(
                b.name.trim().isEmpty
                    ? kBeneficiaryTypes[b.type]!
                    : b.name.trim(),
                d.effectiveBeneficiaryAmount(b) == null
                    ? null
                    : formatNaira(d.effectiveBeneficiaryAmount(b)!),
                subtitle: b.isBank
                    ? '${b.bankName.isEmpty ? 'Bank' : b.bankName} · ${_mask(b.accountNumber)}'
                    : '${kBeneficiaryTypes[b.type]} · ${b.serviceIdentifier}',
              ),
          ],
        ),
      ],
    );
  }

  static String _mask(String account) => account.length <= 4
      ? account
      : '•••• ${account.substring(account.length - 4)}';
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.onEdit,
    required this.children,
  });

  final String title;
  final VoidCallback onEdit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BeelsColors.ink2,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Edit $title',
                excludeSemantics: true,
                onTap: onEdit,
                child: TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  child: const Text('Edit'),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.left, this.right, {this.subtitle});

  final String left;
  final String? right;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  left,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BeelsColors.ink0,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12.5, color: BeelsColors.ink2),
                  ),
              ],
            ),
          ),
          if (right != null)
            Text(
              right!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: BeelsColors.ink1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}
