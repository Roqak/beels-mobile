import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/widgets/common.dart';
import 'package:beels_mobile/features/groups/data/groups_repository.dart';
import 'package:beels_mobile/features/groups/models/group.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFE),
      appBar: const BeelsAppBar('Group'),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error is ApiException
              ? error
              : ApiException(error.toString(), statusCode: 0),
          onRetry: () => ref.invalidate(groupDetailProvider(widget.id)),
        ),
        data: (group) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(groupDetailProvider(widget.id)),
          child: _GroupDetailBody(
            group: group,
            footer: _AddMemberCard(
              formKey: _formKey,
              firstNameController: _firstNameController,
              lastNameController: _lastNameController,
              emailController: _emailController,
              phoneController: _phoneController,
              submitting: _adding,
              onSubmit: _submitAddMember,
            ),
            onRemoveMember: _confirmRemoveMember,
            onRegenerateInvite: _regenerateInvite,
            onDelete: _confirmDelete,
          ),
        ),
      ),
    );
  }

  Future<void> _submitAddMember() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    setState(() => _adding = true);
    try {
      await ref.read(groupDetailProvider(widget.id).notifier).addMember(
            firstName: firstName,
            lastName: lastName.isEmpty ? null : lastName,
            email: email.isEmpty ? null : email,
            phoneNumber: phone.isEmpty ? null : phone,
          );
      if (mounted) {
        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
        _phoneController.clear();
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Member added')),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not add member. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _confirmRemoveMember(GroupMember member) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context,
      title: 'Remove member?',
      message:
          '${member.fullName.isEmpty ? 'This member' : member.fullName} will no longer be part of this group.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(groupDetailProvider(widget.id).notifier)
          .removeMember(member.id!);
      messenger.showSnackBar(
        const SnackBar(content: Text('Member removed')),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not remove member. Try again.')),
      );
    }
  }

  Future<void> _regenerateInvite() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(groupDetailProvider(widget.id).notifier)
          .regenerateInvite();
      messenger.showSnackBar(
        const SnackBar(content: Text('Invite link regenerated')),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not regenerate link. Try again.')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final group = ref.read(groupDetailProvider(widget.id)).valueOrNull;
    if (group == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm(
      context,
      title: 'Delete group?',
      message:
          '${group.name} and its members list will be permanently deleted.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(groupDetailProvider(widget.id).notifier)
          .deleteGroup();
      if (mounted) context.pop();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete group. Try again.')),
      );
    }
  }
}

class _GroupDetailBody extends StatelessWidget {
  const _GroupDetailBody({
    required this.group,
    required this.footer,
    required this.onRemoveMember,
    required this.onRegenerateInvite,
    required this.onDelete,
  });

  final Group group;
  final Widget footer;
  final ValueChanged<GroupMember> onRemoveMember;
  final VoidCallback onRegenerateInvite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _InfoCard(group: group, onDelete: onDelete),
        const SizedBox(height: 12),
        _InviteCard(
          group: group,
          onRegenerate: onRegenerateInvite,
        ),
        const SizedBox(height: 12),
        SectionHeader(
          'Members',
          action: Text(
            group.membersCount == 1
                ? '1 member'
                : '${group.membersCount} members',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF7B7D8C)),
          ),
        ),
        const SizedBox(height: 4),
        if (group.members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              icon: Icons.person_add_alt_1,
              title: 'No members yet',
              message: 'Add people you save with, or share the invite link.',
            ),
          )
        else
          ...group.members.map(
            (member) => _MemberTile(
              member: member,
              onRemove: member.id == null ? null : () => onRemoveMember(member),
            ),
          ),
        const SizedBox(height: 16),
        footer,
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.group, required this.onDelete});

  final Group group;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = group.description;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Delete group',
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFB23A3A)),
                onPressed: onDelete,
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFF5B5D6B)),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Meta(
                icon: Icons.people_outline,
                label: group.membersCount == 1
                    ? '1 member'
                    : '${group.membersCount} members',
              ),
              if (group.createdAt != null)
                _Meta(
                  icon: Icons.event_outlined,
                  label: 'Created ${DateFormat('d MMM yyyy').format(group.createdAt!)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7B7D8C)),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: const Color(0xFF7B7D8C)),
        ),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.group, required this.onRegenerate});

  final Group group;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = group.inviteLink;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 18, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invite link',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Regenerate link',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: onRegenerate,
              ),
            ],
          ),
          if (link != null && link.isNotEmpty) ...[
            SelectableText(
              link,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF4338CA)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copy(context, link),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Share.share(
                    link,
                    subject: 'Join ${group.name} on Beels',
                  ),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share'),
                ),
              ],
            ),
          ] else
            Text(
              'No invite link yet. Generate one to let people join this group.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF5B5D6B)),
            ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied')),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, this.onRemove});

  final GroupMember member;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameParts = member.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = nameParts.isEmpty
        ? '?'
        : nameParts.map((part) => part[0]).take(2).join().toUpperCase();
    final subtitle =
        member.email.isNotEmpty ? member.email : (member.phoneNumber ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF7F7FA),
            child: Text(
              initials,
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF5B5D6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName.isEmpty ? 'Unnamed member' : member.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF7B7D8C)),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove member',
              icon: const Icon(Icons.remove_circle_outline,
                  size: 20, color: Color(0xFFB23A3A)),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _AddMemberCard extends StatelessWidget {
  const _AddMemberCard({
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.phoneController,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3EA)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add a member',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(hintText: 'First name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'First name is required'
                            : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(hintText: 'Last name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Email (optional)'),
              validator: _validateEmail,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(hintText: 'Phone (optional)'),
              validator: _validatePhone,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Add member',
              loading: submitting,
              onPressed: submitting ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

final RegExp _emailRegex =
    RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

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

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}