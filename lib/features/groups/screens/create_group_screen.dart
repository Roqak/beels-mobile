import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/widgets/common.dart';
import 'package:beels_mobile/features/groups/data/groups_repository.dart';
import 'package:beels_mobile/features/groups/models/group.dart';

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
      if (mounted) context.pop();
    } on ApiException catch (error) {
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
      backgroundColor: const Color(0xFFFCFCFE),
      appBar: const BeelsAppBar('New group'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Group name',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
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
              const SizedBox(height: 20),
              SectionHeader(
                'Initial members',
                action: Text(
                  'Optional',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFF7B7D8C)),
                ),
              ),
              const SizedBox(height: 4),
              ..._listRows(theme),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addDraft,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Add member'),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Create group',
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: draft.firstName,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(hintText: 'First name'),
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
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Last name'),
                ),
              ),
              IconButton(
                tooltip: 'Remove member',
                icon: const Icon(Icons.remove_circle_outline,
                    size: 20, color: Color(0xFFB23A3A)),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: draft.email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Email (optional)'),
            validator: (value) => _validateEmail(value),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: draft.phoneNumber,
            keyboardType: TextInputType.phone,
            decoration:
                const InputDecoration(hintText: 'Phone (optional)'),
            validator: (value) => _validatePhone(value),
          ),
        ],
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
  return phone.length >= 10
      ? null
      : 'Phone must be at least 10 characters';
}