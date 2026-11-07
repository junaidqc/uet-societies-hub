import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/pull_to_refresh_wrapper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../controllers/hiring_controller.dart';
import '../../domain/models/application_model.dart';

class AdminApplicationsScreen extends ConsumerStatefulWidget {
  final String hiringId;
  final String societyId;

  const AdminApplicationsScreen({
    super.key,
    required this.hiringId,
    required this.societyId,
  });

  @override
  ConsumerState<AdminApplicationsScreen> createState() => _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends ConsumerState<AdminApplicationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statuses = ['All', 'submitted', 'under_review', 'shortlisted', 'accepted', 'rejected'];

  String _currentStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentStatusFilter = _statuses[_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showStatusDialog(BuildContext context, ApplicationModel app) {
    String selectedStatus = app.status;
    final feedbackController = TextEditingController(text: app.feedback ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Review ${app.applicantName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Position: ${app.position}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Select Applicant Status:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.rule_folder_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                    DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                    DropdownMenuItem(value: 'shortlisted', child: Text('Shortlisted')),
                    DropdownMenuItem(value: 'accepted', child: Text('Selected / Accepted')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: feedbackController,
                  label: 'Feedback / Interview Notes (Optional)',
                  hint: 'e.g. Recommended for interview round 2...',
                  maxLines: 3,
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
              onPressed: () async {
                Navigator.of(ctx).pop();
                final success = await ref
                    .read(hiringActionControllerProvider.notifier)
                    .updateStatus(
                      applicationId: app.id,
                      hiringId: widget.hiringId,
                      status: selectedStatus,
                      feedback: feedbackController.text.trim(),
                    );
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated ${app.applicantName} to ${selectedStatus.toUpperCase()}!'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              child: const Text('Save Status'),
            ),
          ],
        ),
      ),
    );
  }

  /// FR-28: Onboard Selected Applicant directly to Committee Group
  void _showAddToGroupSheet(BuildContext context, ApplicationModel app) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final groupsAsync = ref.watch(societyGroupsProvider(widget.societyId));

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Add to Committee Group',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Onboard selected applicant ${app.applicantName} directly to a society group.',
                  style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 16),

                groupsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                  data: (groups) {
                    if (groups.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: const [
                            Icon(Icons.group_off_outlined, size: 40, color: AppColors.lightTextMuted),
                            SizedBox(height: 10),
                            Text('No groups created for this society yet.'),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final g = groups[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primaryContainer,
                              child: Icon(Icons.groups_rounded, color: AppColors.primary),
                            ),
                            title: Text(g['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(g['description']?.toString() ?? 'Committee Group', maxLines: 1),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                final success = await ref
                                    .read(hiringActionControllerProvider.notifier)
                                    .addApplicantToGroup(
                                      applicationId: app.id,
                                      groupId: g['id'] as String,
                                      role: 'member',
                                    );
                                if (success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${app.applicantName} added to "${g["name"]}"!'),
                                      backgroundColor: AppColors.accent,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Add Member', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'shortlisted':
        return Colors.blue;
      case 'under_review':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = ApplicationFilterParams(
      hiringId: widget.hiringId,
      status: _currentStatusFilter,
    );
    final appsAsync = ref.watch(hiringApplicationsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applicant Review Console'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Submitted'),
            Tab(text: 'Under Review'),
            Tab(text: 'Shortlisted'),
            Tab(text: 'Selected'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: PullToRefreshWrapper(
        onRefresh: () async {
          ref.invalidate(hiringApplicationsProvider(params));
        },
        child: appsAsync.when(
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
            onRetry: () => ref.invalidate(hiringApplicationsProvider(params)),
          ),
          data: (apps) {
            if (apps.isEmpty) {
              return EmptyStateView(
                icon: Icons.assignment_late_outlined,
                title: 'No Applications in this Category',
                description: 'Applications for this recruitment will appear here as students apply.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                final color = _getStatusColor(app.status);
                final dateStr = DateFormat('MMM d, y').format(app.createdAt);

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Applicant Profile Header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primaryContainer,
                              backgroundImage: app.applicantAvatar != null
                                  ? NetworkImage(app.applicantAvatar!)
                                  : null,
                              child: app.applicantAvatar == null
                                  ? Text(
                                      app.applicantName.isNotEmpty ? app.applicantName[0].toUpperCase() : 'U',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.applicantName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    '${app.applicantRoll} • ${app.applicantDept}, Sem ${app.applicantSemester}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color.withOpacity(0.4)),
                              ),
                              child: Text(
                                app.statusDisplay.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Position applied for & Applied date
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Applied: ${app.position}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Date: $dateStr',
                              style: const TextStyle(fontSize: 11, color: AppColors.lightTextMuted),
                            ),
                          ],
                        ),

                        // Questionnaire Answers
                        if (app.answers.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkSurface
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.lightBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Applicant Responses:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                ...app.answers.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: RichText(
                                      text: TextSpan(
                                        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
                                        children: [
                                          TextSpan(
                                            text: 'Q: ${entry.key}\n',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                          TextSpan(
                                            text: 'A: ${entry.value}\n',
                                            style: const TextStyle(color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],

                        if (app.feedback != null && app.feedback!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Internal Feedback: ${app.feedback!}',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.lightTextMuted),
                          ),
                        ],
                        const Divider(height: 24),

                        // Actions Row: Update Status & (FR-28) Add to Group if Selected
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                ),
                                icon: const Icon(Icons.rate_review_outlined, size: 16),
                                label: const Text('Update Status'),
                                onPressed: () => _showStatusDialog(context, app),
                              ),
                            ),
                            // FR-28 Action: Direct Onboarding to Group for Selected Candidates
                            if (app.isSelected) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    minimumSize: const Size(0, 40),
                                  ),
                                  icon: const Icon(Icons.group_add_rounded, size: 16),
                                  label: const Text('Add to Group'),
                                  onPressed: () => _showAddToGroupSheet(context, app),
                                ),
                              ),
                            ],
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
