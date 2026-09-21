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
import 'package:beels_mobile/core/theme.dart';

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
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Group'),
      body: groupAsync.when(
        loading: () => const SkeletonScope(
          child: SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SkeletonRow(),
                  SkeletonRow(),
                  SkeletonRow(),
                  SkeletonRow()
                ],
              ),
            ),
          ),
        ),
        error: (error, _) => ErrorView(
          error: error is ApiException
              ? error
              : ApiException(error.toString(), statusCode: 0),
          onRetry: () => ref.invalidate(groupDetailProvider(widget.id)),
        ),
        data: (group) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupDetailProvider(widget.id)),
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
      HapticFeedback.mediumImpact();
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
      await ref.read(groupDetailProvider(widget.id).notifier).deleteGroup();
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
        const SizedBox(height: 24),
        SectionHeader(
          'Members',
          action: Text(
            group.membersCount == 1
                ? '1 member'
                : '${group.membersCount} members',
            style: theme.textTheme.bodySmall?.copyWith(color: BeelsColors.ink2),
          ),
        ),
        const SizedBox(height: 10),
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
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < group.members.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  _MemberTile(
                    member: group.members[i],
                    onRemove: group.members[i].id == null
                        ? null
                        : () => onRemoveMember(group.members[i]),
                  ),
                ],
              ],
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
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: BeelsColors.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: BeelsColors.accent,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  group.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: BeelsColors.ink0,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete group',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.delete_outline, color: BeelsColors.err),
                onPressed: onDelete,
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: BeelsColors.ink1),
            ),
          ],
          const SizedBox(height: 14),
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
                  label:
                      'Created ${DateFormat('d MMM yyyy').format(group.createdAt!)}',
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
        Icon(icon, size: 16, color: BeelsColors.ink2),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: BeelsColors.ink2),
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
        color: BeelsColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 18, color: BeelsColors.accent),
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
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onRegenerate,
              ),
            ],
          ),
          if (link != null && link.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: BeelsColors.panel,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                link,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: BeelsColors.accentHover),
              ),
            ),
            const SizedBox(height: 12),
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
              style:
                  theme.textTheme.bodySmall?.copyWith(color: BeelsColors.ink1),
            ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String link) {
    HapticFeedback.mediumImpact();
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: BeelsColors.accentSoft,
            child: Text(
              initials,
              style: theme.textTheme.labelMedium?.copyWith(
                color: BeelsColors.accent,
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
                        ?.copyWith(color: BeelsColors.ink2),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove member',
              icon: const Icon(Icons.remove_circle_outline,
                  size: 20, color: BeelsColors.err),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
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
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
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
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Last name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: emailController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Email (optional)'),
              validator: _validateEmail,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Phone (optional)'),
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
          style: FilledButton.styleFrom(backgroundColor: BeelsColors.err),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
