// ============================================================================
// Screen: notifications_screen.dart
// Description: Realtime notifications stream & per-society/group mute dialog (FR-36, FR-37)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../navigation/presentation/screens/main_scaffold.dart';
import '../../../societies/presentation/controllers/society_controller.dart';
import '../../../groups/presentation/controllers/group_controller.dart';
import '../data/supabase_notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _showMutePreferencesSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final prefsAsync = ref.watch(mutePreferencesProvider);
          final societiesAsync = ref.watch(societiesListProvider);
          final groupsAsync = ref.watch(userGroupsProvider);

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.85,
            minChildSize: 0.4,
            builder: (ctx, scrollController) => Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notification Settings',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'Mute push notifications from specific societies or working groups.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(height: 24),

                  const Text(
                    'Societies',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),

                  societiesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Unable to load societies'),
                    data: (societies) {
                      final prefs = prefsAsync.value ?? [];
                      final mutedSocietyIds = prefs
                          .where((p) => p.societyId != null && p.isMuted)
                          .map((p) => p.societyId!)
                          .toSet();

                      return Column(
                        children: societies.map((s) {
                          final isMuted = mutedSocietyIds.contains(s.id);
                          return SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(s.name, style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                              isMuted ? 'Muted (No push alerts)' : 'Active notifications',
                              style: const TextStyle(fontSize: 11),
                            ),
                            value: !isMuted,
                            activeColor: AppColors.primary,
                            onChanged: (active) async {
                              await ref.read(notificationsRepositoryProvider).toggleMute(
                                societyId: s.id,
                                mute: !active,
                              );
                              ref.invalidate(mutePreferencesProvider);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const Divider(height: 24),
                  const Text(
                    'Committee Groups',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),

                  groupsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (groups) {
                      if (groups.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('No committee groups joined.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        );
                      }
                      final prefs = prefsAsync.value ?? [];
                      final mutedGroupIds = prefs
                          .where((p) => p.groupId != null && p.isMuted)
                          .map((p) => p.groupId!)
                          .toSet();

                      return Column(
                        children: groups.map((g) {
                          final isMuted = mutedGroupIds.contains(g.id);
                          return SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(g.name, style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                              isMuted ? 'Muted' : 'Active alerts',
                              style: const TextStyle(fontSize: 11),
                            ),
                            value: !isMuted,
                            activeColor: AppColors.primary,
                            onChanged: (active) async {
                              await ref.read(notificationsRepositoryProvider).toggleMute(
                                groupId: g.id,
                                mute: !active,
                              );
                              ref.invalidate(mutePreferencesProvider);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null || user.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: EmptyStateView(
          icon: Icons.notifications_off_outlined,
          title: 'Guest Mode',
          message:
              'Sign in with your @uet.edu.pk student email to receive real-time notifications about recruitment, society invitations, and events.',
          actionLabel: 'Log In with UET Email',
          onAction: () => MainScaffold.promptGuestLogin(context, 'view your notifications'),
        ),
      );
    }

    final notifsStream = ref.watch(inAppNotificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Notification Preferences & Mute',
            onPressed: () => _showMutePreferencesSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark All Read',
            onPressed: () => ref.read(notificationsRepositoryProvider).markAllAsRead(),
          ),
        ],
      ),
      body: notifsStream.when(
        loading: () => const SkeletonListLoader(),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyStateView(
              icon: Icons.notifications_none_rounded,
              title: 'No Notifications',
              message: 'You are all caught up! Updates from followed societies, hirings, and groups will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                tileColor: notif.isRead ? null : AppColors.primaryLight.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                leading: CircleAvatar(
                  backgroundColor: notif.isRead ? Colors.grey.shade200 : AppColors.primaryLight,
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: notif.isRead ? Colors.grey : AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  notif.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(notif.body, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, hh:mm a').format(notif.createdAt.toLocal()),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                onTap: () {
                  if (!notif.isRead) {
                    ref.read(notificationsRepositoryProvider).markAsRead(notif.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
