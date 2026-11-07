import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/pull_to_refresh_wrapper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Guest Mode UI
    if (user == null || user.isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 50,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Guest Explorer',
                  style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are currently browsing in guest mode. Sign in with your official @uet.edu.pk student email to follow societies, join discussions, and apply for executive recruitments.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'Log In with UET Email',
                  icon: Icons.login_rounded,
                  onPressed: () => context.push('/login'),
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Create Student Account',
                  type: AppButtonType.outlined,
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () => context.push('/signup'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Authenticated Student Profile
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: PullToRefreshWrapper(
        onRefresh: () async {
          ref.invalidate(currentProfileProvider);
        },
        child: profileAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SkeletonCardLoader(),
              SizedBox(height: 16),
              SkeletonCardLoader(),
            ],
          ),
          error: (err, _) => ErrorStateView(
            message: err.toString(),
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Profile not found'));
            }

            final initials = profile.fullName.isNotEmpty
                ? profile.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                : 'U';

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.primary,
                          backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                          child: profile.avatarUrl == null
                              ? Text(
                                  initials.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile.fullName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            profile.rollNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        if (profile.isSystemAdmin) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade700, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, size: 14, color: Colors.amber.shade800),
                                const SizedBox(width: 4),
                                Text(
                                  'System Administrator',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (profile.isSystemAdmin) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: isDark ? AppColors.darkCard : const Color(0xFFFFFBEB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.amber.shade400, width: 1),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.amber.shade100,
                            child: Icon(Icons.admin_panel_settings_rounded, color: Colors.amber.shade900),
                          ),
                          title: const Text('System Admin Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Moderation queue, reports, totals & metrics', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: () => context.push('/admin/dashboard'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.amber.shade100,
                            child: Icon(Icons.how_to_reg_rounded, color: Colors.amber.shade900),
                          ),
                          title: const Text('Charter Approval Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Review and approve new society registrations', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: () => context.push('/admin/society-requests'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Committee Working Groups Quick Access
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: const Icon(Icons.groups_rounded, color: AppColors.primary),
                    ),
                    title: const Text('Committee Working Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Team chat, polls, tasks & notices', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () => context.push('/groups'),
                  ),
                ),
                const SizedBox(height: 16),

                // Academic & Contact Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Academic Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.account_balance_rounded,
                          label: 'Department',
                          value: profile.department,
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow(
                          icon: Icons.school_rounded,
                          label: 'Semester',
                          value: 'Semester ${profile.semester}',
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow(
                          icon: Icons.email_rounded,
                          label: 'Official Email',
                          value: profile.email,
                        ),
                        if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildInfoRow(
                            icon: Icons.phone_rounded,
                            label: 'Phone',
                            value: profile.phoneNumber!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bio Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About / Bio',
                          style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          profile.bio != null && profile.bio!.isNotEmpty
                              ? profile.bio!
                              : 'No bio added yet. Tap edit to write something about your interests, skills, or society involvement.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: profile.bio == null || profile.bio!.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign Out Button
                AppButton(
                  text: 'Log Out',
                  icon: Icons.logout_rounded,
                  type: AppButtonType.outlined,
                  color: AppColors.error,
                  onPressed: () => _confirmSignOut(context, ref),
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of UET Societies Hub?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/splash');
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
