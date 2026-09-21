import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A contact the user chose from the system picker.
class PickedContact {
  const PickedContact({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.email = '',
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String email;

  factory PickedContact.fromMap(Map<Object?, Object?> map) {
    final name = splitName((map['name'] ?? '').toString());
    return PickedContact(
      firstName: name.$1,
      lastName: name.$2,
      phone: normalizeNigerianPhone((map['phone'] ?? '').toString()),
      email: (map['email'] ?? '').toString().trim(),
    );
  }
}

extension PickedContactFill on PickedContact {
  /// Copies the non-empty parts into the given form controllers, leaving any
  /// field the contact has no value for exactly as the user left it.
  void fillInto({
    TextEditingController? firstName,
    TextEditingController? lastName,
    TextEditingController? email,
    TextEditingController? phone,
  }) {
    if (this.firstName.isNotEmpty) firstName?.text = this.firstName;
    if (this.lastName.isNotEmpty) lastName?.text = this.lastName;
    if (this.email.isNotEmpty) email?.text = this.email;
    if (this.phone.isNotEmpty) phone?.text = this.phone;
  }
}

/// "Ada Okafor" -> (Ada, Okafor); "Ada" -> (Ada, ""); extra words go to the
/// last name ("Ada Ngozi Okafor" -> (Ada, "Ngozi Okafor")).
(String, String) splitName(String displayName) {
  final parts =
      displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return ('', '');
  final list = parts.toList();
  return (list.first, list.skip(1).join(' '));
}

/// Cleans a contact number for the API: drops spaces, dashes and brackets and
/// turns Nigerian international forms (+234 / 234) into the local 0-prefixed
/// form the rest of the app uses. Other numbers are kept as typed (digits and
/// a leading plus).
String normalizeNigerianPhone(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
  if (cleaned.startsWith('+234') && cleaned.length >= 14) {
    return '0${cleaned.substring(4)}';
  }
  if (cleaned.startsWith('234') && cleaned.length >= 13) {
    return '0${cleaned.substring(3)}';
  }
  return cleaned;
}

/// Opens the phone's contact picker. Faked in tests.
abstract class ContactPicker {
  /// `null` when the user cancels. Throws [ContactPickerException] when the
  /// picker cannot be opened.
  Future<PickedContact?> pick();
}

class ContactPickerException implements Exception {
  const ContactPickerException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PlatformContactPicker implements ContactPicker {
  const PlatformContactPicker();

  static const _channel = MethodChannel('beels/contacts');

  @override
  Future<PickedContact?> pick() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('pick');
      if (result == null) return null;
      return PickedContact.fromMap(result);
    } on PlatformException catch (e) {
      throw ContactPickerException(
          e.message ?? 'Could not open your contacts.');
    } on MissingPluginException {
      throw const ContactPickerException(
          'Contacts are not available on this device.');
    }
  }
}

final contactPickerProvider =
    Provider<ContactPicker>((ref) => const PlatformContactPicker());
