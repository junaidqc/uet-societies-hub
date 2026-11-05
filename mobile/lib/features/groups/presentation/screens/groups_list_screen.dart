// ============================================================================
// Screen: groups_list_screen.dart
// Description: Lists all committee and executive groups accessible to user (FR-26)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/pull_to_refresh_wrapper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../presentation/controllers/group_controller.dart';
import '../domain/models/group_model.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Committee Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Create Committee Group',
            onPressed: () => context.push('/groups/create'),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const SkeletonListLoader(),
        error: (err, _) => ErrorStateView(
          title: 'Unable to load groups',
          message: err.toString(),
          onRetry: () => ref.refresh(userGroupsProvider),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return EmptyStateView(
              icon: Icons.groups_outlined,
              title: 'No Committee Groups Yet',
              message:
                  'You have not been added to any executive or committee groups. Once selected in society recruitment, your groups will appear here.',
              actionLabel: 'Browse Hiring',
              onAction: () => context.go('/hiring'),
            );
          }

          return PullToRefreshWrapper(
            onRefresh: () async => ref.refresh(userGroupsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _buildGroupTile(context, group);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupTile(BuildContext context, GroupModel group) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          radius: 24,
          child: const Icon(Icons.people_alt, color: AppColors.primary),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.societyName != null) ...[
              const SizedBox(height: 2),
              Text(
                group.societyName!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
            if (group.description != null && group.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                group.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          context.push('/groups/${group.id}', extra: group.name);
        },
      ),
    );
  }
}
