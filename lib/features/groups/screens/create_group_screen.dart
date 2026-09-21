import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/widgets/common.dart';
import 'package:beels_mobile/features/groups/data/groups_repository.dart';
import 'package:beels_mobile/features/groups/models/group.dart';
import 'package:beels_mobile/core/contacts/contact_picker.dart';
import 'package:beels_mobile/core/theme.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _MemberDraft {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final phoneNumber = TextEditingController();

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phoneNumber.dispose();
  }

  bool get isEmpty =>
      firstName.text.trim().isEmpty &&
      lastName.text.trim().isEmpty &&
      email.text.trim().isEmpty &&
      phoneNumber.text.trim().isEmpty;
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<_MemberDraft> _members = [];
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final draft in _members) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addDraft() {
    setState(() => _members.add(_MemberDraft()));
  }

  void _removeDraft(int index) {
    setState(() {
      _members[index].dispose();
      _members.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final members = _members
        .where((draft) => !draft.isEmpty)
        .map((draft) => GroupMember(
              firstName: draft.firstName.text.trim(),
              lastName: draft.lastName.text.trim(),
              email: draft.email.text.trim(),
              phoneNumber: _nullIfEmpty(draft.phoneNumber.text.trim()),
            ))
        .toList();

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await ref.read(groupsRepositoryProvider).create(
            name: name,
            description: description.isEmpty ? null : description,
            members: members,
          );
      HapticFeedback.mediumImpact();
      if (mounted) context.pop();
    } on ApiException catch (error) {
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not create group. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _nullIfEmpty(String value) => value.isEmpty ? null : value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('New group'),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const IntroBanner(
                title: 'Save with people you trust',
                body:
                    'A group keeps your circle in one place, so you can invite the same people to many beels.',
              ),
              const SizedBox(height: 20),
              SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Group name',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Group name is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Description (optional)',
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SectionHeader(
                'Initial members',
                action: Text(
                  'Optional',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: BeelsColors.ink2),
                ),
              ),
              const SizedBox(height: 10),
              ..._listRows(theme),
              Pressable(
                onTap: _addDraft,
                haptic: true,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BeelsColors.borderStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_alt_rounded,
                          size: 20, color: BeelsColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Add member',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: BeelsColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: BeelsColors.panel,
          border: Border(top: BorderSide(color: BeelsColors.border)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          child: PrimaryButton(
            label: 'Create group',
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ),
    );
  }

  List<Widget> _listRows(ThemeData theme) {
    return [
      for (var i = 0; i < _members.length; i++)
        _MemberRow(
          key: ValueKey(_members[i]),
          draft: _members[i],
          onRemove: () => _removeDraft(i),
        ),
    ];
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({super.key, required this.draft, required this.onRemove});

  final _MemberDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ContactPickButton(
                onPicked: (c) => c.fillInto(
                  firstName: draft.firstName,
                  lastName: draft.lastName,
                  email: draft.email,
                  phone: draft.phoneNumber,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.firstName,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'First name'),
                    validator: (value) {
                      if (draft.isEmpty) return null;
                      return (value == null || value.trim().isEmpty)
                          ? 'First name required'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: draft.lastName,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Last name'),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove member',
                  icon: Icon(Icons.remove_circle_outline,
                      size: 20, color: BeelsColors.err),
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.email,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Email (optional)'),
              validator: (value) => _validateEmail(value),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.phoneNumber,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Phone (optional)'),
              validator: (value) => _validatePhone(value),
            ),
          ],
        ),
      ),
    );
  }
}

final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return null;
  return _emailRegex.hasMatch(email) ? null : 'Enter a valid email';
}

String? _validatePhone(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) return null;
  return phone.length >= 10 ? null : 'Phone must be at least 10 characters';
}
