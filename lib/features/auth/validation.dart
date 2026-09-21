final RegExp _emailPattern = RegExp(
  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
);

String? validateRequired(String? value, String label) {
  if ((value ?? '').trim().isEmpty) {
    return 'Enter your $label';
  }
  return null;
}

String? validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Enter your email';
  if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
  return null;
}

String? validatePhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'Enter your phone number';
  if (digits.length < 11) return 'Phone number must be at least 11 digits';
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Enter your password';
  if (password.length < 6) return 'Password must be at least 6 characters';
  return null;
}

String? validateConfirmPassword(String? value, String newPassword) {
  final confirm = value ?? '';
  if (confirm.isEmpty) return 'Confirm your password';
  if (confirm != newPassword) return 'Passwords do not match';
  return null;
}