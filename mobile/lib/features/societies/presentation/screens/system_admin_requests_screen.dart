import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/pull_to_refresh_wrapper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/society_controller.dart';
import '../../domain/models/society_model.dart';

class SystemAdminRequestsScreen extends ConsumerWidget {
  const SystemAdminRequestsScreen({super.key});

  void _showApproveDialog(BuildContext context, WidgetRef ref, SocietyModel society) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Society?'),
        content: Text(
          'Are you sure you want to approve "${society.name}"? This will make the society active and automatically appoint the applicant as President.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(societyActionControllerProvider.notifier)
                  .approveSociety(society.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${society.name}" approved and activated!'),
                    backgroundColor: AppColors.accent,
                  ),
                );
              }
            },
            child: const Text('Approve & Activate'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, SocietyModel society) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Society Request'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provide a reason for rejecting "${society.name}":'),
              const SizedBox(height: 12),
              AppTextField(
                controller: reasonController,
                label: 'Rejection Reason *',
                hint: 'e.g. Duplicate charter, missing faculty sponsor...',
                maxLines: 3,
                validator: (val) => val == null || val.trim().isEmpty ? 'Reason is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(societyActionControllerProvider.notifier)
                  .rejectSociety(society.id, reasonController.text.trim());
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${society.name}" request rejected.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Security Gate in UI (also strictly enforced by Database RLS & RPC)
    if (user == null || !user.isSystemAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Security Access Denied: Only authenticated System Administrators can view society approval queues.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    final requestsAsync = ref.watch(pendingSocietiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Society Approval Queue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: PullToRefreshWrapper(
        onRefresh: () async {
          ref.invalidate(pendingSocietiesProvider);
        },
        child: requestsAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SkeletonCardLoader(),
              SizedBox(height: 12),
              SkeletonCardLoader(),
            ],
          ),
          error: (err, _) => ErrorStateView(
            message: err.toString(),
            onRetry: () => ref.invalidate(pendingSocietiesProvider),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyStateView(
                icon: Icons.assignment_turned_in_rounded,
                title: 'Queue Clean',
                description: 'No pending society registration requests at this time.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final society = requests[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primaryContainer,
                              backgroundImage: society.logoUrl != null
                                  ? NetworkImage(society.logoUrl!)
                                  : null,
                              child: society.logoUrl == null
                                  ? const Icon(Icons.group_work_rounded, color: AppColors.primary)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    society.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          society.category,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'PENDING',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          society.description,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (society.email != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                society.email!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 28),

                        // Action Buttons: Approve & Reject
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Reject'),
                                onPressed: () => _showRejectDialog(context, ref, society),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text('Approve'),
                                onPressed: () => _showApproveDialog(context, ref, society),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
