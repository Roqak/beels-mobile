import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/common.dart';
import '../../controllers/beels_controllers.dart';
import '../../models/bill_provider.dart';

/// Chooser for a bills provider of one payout [type] (a network, cable
/// company or electricity distributor), loaded from the backend.
class BillProviderField extends ConsumerWidget {
  const BillProviderField({
    super.key,
    required this.type,
    required this.selectedName,
    required this.onChanged,
    this.errorText,
  });

  final String type;
  final String selectedName;
  final ValueChanged<BillProvider> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(billProvidersProvider(type));
    final label = switch (type) {
      'electricity' => 'Electricity company',
      'cable' => 'Cable provider',
      _ => 'Network',
    };
    return providers.when(
      loading: () => const SkeletonScope(
        child: SkeletonBox(height: 52, radius: 10),
      ),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(billProvidersProvider(type)),
      ),
      data: (rows) => _PickerBox(
        label: label,
        value: selectedName,
        hint: 'Choose ${label.toLowerCase()}',
        errorText: errorText,
        onTap: () async {
          final picked = await showModalBottomSheet<BillProvider>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _PickSheet<BillProvider>(
              items: rows,
              title: (p) => p.name,
              searchHint: 'Search',
            ),
          );
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }
}

/// Chooser for a data bundle or cable package from [plans].
class BillPlanField extends StatelessWidget {
  const BillPlanField({
    super.key,
    required this.plans,
    required this.selectedName,
    required this.onChanged,
    this.errorText,
  });

  final List<BillPlan> plans;
  final String selectedName;
  final ValueChanged<BillPlan> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return _PickerBox(
      label: 'Plan',
      value: selectedName,
      hint: 'Choose a plan',
      errorText: errorText,
      onTap: () async {
        final picked = await showModalBottomSheet<BillPlan>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _PickSheet<BillPlan>(
            items: plans,
            title: (p) => p.name,
            trailing: (p) => formatNaira(p.amount),
            searchHint: 'Search plans',
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(value.isEmpty ? hint : value),
      ),
    );
  }
}

/// Searchable list sheet; pops the tapped item.
class _PickSheet<T> extends StatefulWidget {
  const _PickSheet({
    required this.items,
    required this.title,
    required this.searchHint,
    this.trailing,
  });

  final List<T> items;
  final String Function(T) title;
  final String Function(T)? trailing;
  final String searchHint;

  @override
  State<_PickSheet<T>> createState() => _PickSheetState<T>();
}

class _PickSheetState<T> extends State<_PickSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final rows = q.isEmpty
        ? widget.items
        : widget.items
            .where((i) => widget.title(i).toLowerCase().contains(q))
            .toList();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Short lists (a few networks) need no search box.
            if (widget.items.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        widget.items.isEmpty
                            ? 'Nothing available right now.'
                            : 'Nothing matches that search.',
                        style: TextStyle(color: BeelsColors.ink2),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: rows.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(widget.title(rows[i])),
                        trailing: widget.trailing == null
                            ? null
                            : Text(
                                widget.trailing!(rows[i]),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: BeelsColors.ink1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
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
