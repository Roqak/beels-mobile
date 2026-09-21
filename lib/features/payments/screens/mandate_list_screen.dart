import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/beels_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_chip.dart' show StatusChip, statusKind;
import '../controllers/mandates_controller.dart';
import '../models/payment_mandate.dart';

/// Lists the organizer's direct-debit mandates with revocation.
class MandateListScreen extends ConsumerWidget {
  const MandateListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mandates = ref.watch(mandatesControllerProvider);
    return Scaffold(
      appBar: const BeelsAppBar('Direct debit'),
      body: mandates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error as ApiException,
          onRetry: () =>
              ref.read(mandatesControllerProvider.notifier).refresh(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No direct debit yet',
              message:
                  'Set up a mandate to let Beels collect your contributions '
                  'automatically on collection day.',
              actionLabel: 'Set up mandate',
              onAction: () async {
                await context.push('/mandates/setup');
                ref.read(mandatesControllerProvider.notifier).refresh();
              },
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(mandatesControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == rows.length) {
                  return OutlinedButton.icon(
                    onPressed: () async {
                      await context.push('/mandates/setup');
                      ref.read(mandatesControllerProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Set up another mandate'),
                  );
                }
                final mandate = rows[index];
                return _MandateTile(
                  mandate: mandate,
                  onRevoke: () => _confirmRevoke(context, ref, mandate),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    WidgetRef ref,
    PaymentMandate mandate,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke mandate?'),
        content: const Text(
          'Beels will no longer be able to collect contributions from this '
          'account automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(mandatesControllerProvider.notifier).revoke(mandate);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mandate revoked.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not revoke the mandate. Try again.'),
          ),
        );
      }
    }
  }
}

String _last4(String value) =>
    value.length > 4 ? value.substring(value.length - 4) : value;

class _MandateTile extends StatelessWidget {
  const _MandateTile({required this.mandate, required this.onRevoke});

  final PaymentMandate mandate;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mandate.bankName ?? 'Bank',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '•••• ${_last4(mandate.accountNumber)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusChip(label: mandate.status, kind: statusKind(mandate.status)),
          IconButton(
            tooltip: 'Revoke mandate',
            onPressed: onRevoke,
            icon: const Icon(Icons.link_off),
          ),
        ],
      ),
    );
  }
}