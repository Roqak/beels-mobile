import 'package:flutter/material.dart';

import 'package:beels_mobile/core/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:beels_mobile/core/api/api_exception.dart';
import 'package:beels_mobile/core/widgets/common.dart';
import 'package:beels_mobile/features/groups/data/groups_repository.dart';
import 'package:beels_mobile/features/groups/models/group.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsListProvider);
    return Scaffold(
      backgroundColor: BeelsColors.surface,
      appBar: const BeelsAppBar('Groups'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context, ref),
        icon: const Icon(Icons.group_add),
        label: const Text('New group'),
      ),
      body: groupsAsync.when(
        loading: () => const _ListSkeleton(),
        error: (error, _) => ErrorView(
          error: error is ApiException
              ? error
              : ApiException(error.toString(), statusCode: 0),
          onRetry: () => ref.invalidate(groupsListProvider),
        ),
        data: (groups) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(groupsListProvider),
          child: groups.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.group_outlined,
                      title: 'No groups yet',
                      message:
                          'Groups let you organize people you save with together.',
                      actionLabel: 'Create a group',
                      onAction: () => _openCreate(context, ref),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _GroupCard(
                    group: groups[index],
                    onOpen: () => _openDetail(context, ref, groups[index].id),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    await context.push('/groups/new');
    ref.invalidate(groupsListProvider);
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    int groupId,
  ) async {
    await context.push('/groups/$groupId');
    ref.invalidate(groupsListProvider);
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onOpen});

  final Group group;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = group.description;
    final count = group.membersCount;
    return Pressable(
      onTap: onOpen,
      child: SurfaceCard(
        onTap: onOpen,
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: BeelsColors.accentSoft,
              child: Text(
                group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                style: theme.textTheme.titleMedium?.copyWith(
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
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: BeelsColors.ink1),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 14, color: BeelsColors.ink3),
                      const SizedBox(width: 4),
                      Text(
                        count == 1 ? '1 member' : '$count members',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: BeelsColors.ink2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: BeelsColors.ink3),
          ],
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonScope(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SkeletonRow(),
              SkeletonRow(),
              SkeletonRow(),
              SkeletonRow(),
              SkeletonRow(),
              SkeletonRow(),
            ],
          ),
        ),
      ),
    );
  }
}
