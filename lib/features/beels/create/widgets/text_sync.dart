import 'package:flutter/widgets.dart';

/// Keeps a controller showing [value] without disturbing typing: when the
/// draft already matches what is in the field (the normal case while the user
/// types) nothing changes; when the draft changed elsewhere (split equally,
/// contact picked, account verified) the field follows.
void syncController(TextEditingController controller, String value) {
  if (controller.text == value) return;
  controller.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
}
