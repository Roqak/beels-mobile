import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contacts/contact_picker.dart';
import '../theme.dart';

/// "From contacts" action for forms that add a person. Opens the system
/// picker; [onPicked] receives the chosen contact. Hidden where the picker is
/// not supported.
class ContactPickButton extends ConsumerWidget {
  const ContactPickButton({super.key, required this.onPicked});

  final ValueChanged<PickedContact> onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: BeelsColors.accent,
      ),
      icon: const Icon(Icons.contacts_rounded, size: 18),
      label: const Text('From contacts'),
      onPressed: () async {
        HapticFeedback.selectionClick();
        final messenger = ScaffoldMessenger.of(context);
        try {
          final picked = await ref.read(contactPickerProvider).pick();
          if (picked != null) onPicked(picked);
        } on ContactPickerException catch (e) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
    );
  }
}
