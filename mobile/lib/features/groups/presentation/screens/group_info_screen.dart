// ============================================================================
// Screen: group_info_screen.dart
// Description: Member roster, Leave Group, and Remove/Permanently Ban Member (FR-31)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../presentation/controllers/group_controller.dart';
import '../domain/models/group_model.dart';

class GroupInfoScreen extends ConsumerWidget {
  final String groupId;
  final String groupName;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  void _showRemoveDialog(BuildContext context, WidgetRef ref, GroupMemberModel member) {
    final reasonController = TextEditingController();
    bool permanentBan = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Remove ${member.fullName}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to remove ${member.fullName} from $groupName?'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for removal',
                  hintText: 'e.g. Inactivity, graduation, violation',
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permanent ban (cannot re-enter)', style: TextStyle(fontSize: 13)),
                value: permanentBan,
                activeColor: AppColors.error,
                onChanged: (val) => setState(() => permanentBan = val ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await ref.read(groupActionsControllerProvider.notifier).removeMember(
                  groupId: groupId,
                  userId: member.userId,
                  permanentBlock: permanentBan,
                  reason: reasonController.text.trim(),
                );
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${member.fullName} removed and barred from re-entry.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Remove Member', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Committee Group?'),
        content: const Text(
          'You will forfeit access to messages, documents and tasks in this group. You must be re-added by an admin to regain access.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(groupActionsControllerProvider.notifier).leaveGroup(groupId);
              if (context.mounted && ok) {
                context.go('/groups');
              }
            },
            child: const Text('Leave Group', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: Text('$groupName Details')),
      body: membersAsync.when(
        loading: () => const SkeletonListLoader(),
        error: (err, _) => ErrorStateView(
          title: 'Unable to load members',
          message: err.toString(),
          onRetry: () => ref.refresh(groupMembersProvider(groupId)),
        ),
        data: (members) {
          final isCurrentUserAdmin = members.any(
            (m) => m.userId == currentUserId && m.role == 'admin',
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            radius: 28,
                            child: Icon(Icons.groups, color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  groupName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${members.length} members',
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: AppColors.accent),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Private Group: Non-members cannot read messages or files via database RLS.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Group Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ...members.map((member) {
                final isMe = member.userId == currentUserId;
                final isAdmin = member.role == 'admin';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAdmin ? AppColors.primaryLight : Colors.grey.withOpacity(0.15),
                      child: Text(
                        (member.fullName ?? 'U')[0].toUpperCase(),
                        style: TextStyle(
                          color: isAdmin ? AppColors.primary : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          member.fullName ?? 'Member',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          const Text('(You)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${member.rollNumber ?? ''} • ${isAdmin ? 'Admin' : 'Member'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: (isCurrentUserAdmin && !isMe)
                        ? IconButton(
                            icon: const Icon(Icons.person_remove_outlined, color: AppColors.error),
                            tooltip: 'Remove & Bar Member',
                            onPressed: () => _showRemoveDialog(context, ref, member),
                          )
                        : null,
                  ),
                );
              }),

              const SizedBox(height: 24),
              // Leave Group Button
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app, color: AppColors.error),
                label: const Text('Leave Group', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showLeaveDialog(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}
