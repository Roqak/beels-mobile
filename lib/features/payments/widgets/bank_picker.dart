import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../controllers/mandates_controller.dart';
import '../models/bank.dart';

/// Bank chooser: a field that opens a searchable sheet of banks. Handles its
/// own loading and error states so callers only pass the selection.
class BankPickerField extends ConsumerWidget {
  const BankPickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.hint = 'Choose your bank',
    this.errorText,
  });

  final Bank? selected;
  final ValueChanged<Bank> onChanged;
  final String hint;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banks = ref.watch(banksProvider);
    return banks.when(
      loading: () => const SkeletonScope(
        child: SkeletonBox(height: 52, radius: 10),
      ),
      error: (error, _) => ErrorView(
        error: error as ApiException,
        onRetry: () => ref.invalidate(banksProvider),
      ),
      data: (rows) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pick(context, rows),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Bank',
            errorText: errorText,
            suffixIcon: const Icon(Icons.expand_more),
          ),
          child: Text(selected?.name ?? hint),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, List<Bank> banks) async {
    final picked = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => BankSheet(banks: banks),
    );
    if (picked != null) onChanged(picked);
  }
}

class BankSheet extends StatefulWidget {
  const BankSheet({super.key, required this.banks});

  final List<Bank> banks;

  @override
  State<BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<BankSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final rows = q.isEmpty
        ? widget.banks
        : widget.banks.where((b) => b.name.toLowerCase().contains(q)).toList();
    final height = MediaQuery.of(context).size.height * 0.75;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search banks',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'No bank matches that search.',
                        style: TextStyle(color: BeelsColors.ink2),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: rows.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(rows[i].name),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(rows[i]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
