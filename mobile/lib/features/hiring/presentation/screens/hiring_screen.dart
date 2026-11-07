import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/pull_to_refresh_wrapper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../navigation/presentation/screens/main_scaffold.dart';
import '../../../societies/presentation/controllers/society_controller.dart';
import '../controllers/hiring_controller.dart';
import '../../domain/models/hiring_model.dart';

class HiringScreen extends ConsumerWidget {
  const HiringScreen({super.key});

  Color _getDaysLeftColor(HiringModel hiring) {
    if (hiring.status == 'closed' || hiring.isExpired) {
      return Colors.red;
    }
    if (hiring.daysLeft <= 1) {
      return Colors.orange.shade800;
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiringsAsync = ref.watch(hiringsListProvider);
    final selectedSociety = ref.watch(hiringSocietyFilterProvider);
    final isSavedOnly = ref.watch(hiringSavedOnlyProvider);
    final currentUser = ref.watch(currentUserProvider);

    final societiesAsync = ref.watch(societiesListProvider);
    final adminSocietiesAsync = ref.watch(userAdminSocietiesProvider);
    final isSocietyAdmin = (adminSocietiesAsync.value?.isNotEmpty ?? false) || (currentUser?.isSystemAdmin ?? false);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recruitment & Opportunities'),
        actions: [
          // Saved Hirings Filter Toggle (FR-24)
          IconButton(
            icon: Icon(
              isSavedOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isSavedOnly ? AppColors.primary : null,
            ),
            tooltip: isSavedOnly ? 'Show All Hirings' : 'Show Saved Hirings',
            onPressed: () {
              if (currentUser == null || currentUser.isGuest) {
                MainScaffold.promptGuestLogin(context, 'view your saved opportunities');
              } else {
                ref.read(hiringSavedOnlyProvider.notifier).state = !isSavedOnly;
              }
            },
          ),
        ],
      ),
      floatingActionButton: isSocietyAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Post Recruitment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => context.push('/hiring/create'),
            )
          : null,
      body: PullToRefreshWrapper(
        onRefresh: () async {
          ref.invalidate(hiringsListProvider);
        },
        child: Column(
          children: [
            // Society Filter Row (FR-19)
            societiesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (societies) {
                return SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    itemCount: societies.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isAll = index == 0;
                      final id = isAll ? 'All' : societies[index - 1].id;
                      final name = isAll ? 'All Societies' : societies[index - 1].name;
                      final isSelected = selectedSociety == id;

                      return ChoiceChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            ref.read(hiringSocietyFilterProvider.notifier).state = id;
                          }
                        },
                        selectedColor: isDark ? AppColors.primaryLight : AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? (isDark ? AppColors.darkBg : Colors.white)
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            // Active Filters Banner if Saved Only
            if (isSavedOnly) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_added_rounded, size: 16, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    const Text('Showing Bookmarked Opportunities', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => ref.read(hiringSavedOnlyProvider.notifier).state = false,
                      child: const Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Hirings List sorted by deadline (FR-19)
            Expanded(
              child: hiringsAsync.when(
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
                  onRetry: () => ref.invalidate(hiringsListProvider),
                ),
                data: (hirings) {
                  if (hirings.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.work_off_outlined,
                      title: isSavedOnly ? 'No Saved Hirings' : 'No Open Recruitments',
                      description: isSavedOnly
                          ? 'Bookmark opportunities using the save icon on any recruitment card.'
                          : 'No active recruitments found for the selected society filter.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                    itemCount: hirings.length,
                    itemBuilder: (context, index) {
                      final hiring = hirings[index];
                      final daysColor = _getDaysLeftColor(hiring);
                      final deadlineStr = DateFormat('MMM d, y').format(hiring.deadline);

                      // Check if current user is admin for this specific society
                      final canManageHiring = (currentUser?.isSystemAdmin ?? false) ||
                          (adminSocietiesAsync.value?.any((s) => s['id'] == hiring.societyId) ?? false);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Society Header Row
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => context.push('/societies/${hiring.societyId}'),
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.primaryContainer,
                                      backgroundImage: hiring.societyLogo != null
                                          ? NetworkImage(hiring.societyLogo!)
                                          : null,
                                      child: hiring.societyLogo == null
                                          ? const Icon(Icons.group_work_rounded, color: AppColors.primary)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => context.push('/societies/${hiring.societyId}'),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hiring.societyName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            'Deadline: $deadlineStr',
                                            style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Days-Left Chip (FR-20)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: daysColor.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: daysColor.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      hiring.daysLeftText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: daysColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Save / Bookmark Icon (FR-24)
                                  IconButton(
                                    icon: Icon(
                                      hiring.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                      color: hiring.isSaved ? AppColors.primary : AppColors.lightTextMuted,
                                      size: 22,
                                    ),
                                    tooltip: hiring.isSaved ? 'Remove Bookmark' : 'Save Hiring',
                                    onPressed: () {
                                      if (currentUser == null || currentUser.isGuest) {
                                        MainScaffold.promptGuestLogin(context, 'bookmark recruitment opportunities');
                                      } else {
                                        HapticFeedback.lightImpact();
                                        ref.read(hiringActionControllerProvider.notifier).toggleSave(hiring.id, hiring.isSaved);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Hiring Title & Description
                              Text(
                                hiring.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                hiring.description,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),

                              // Requirements
                              if (hiring.requirements != null) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Eligibility: ${hiring.requirements!}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Method & Seats Badges
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Method: ${hiring.selectionMethod}', style: const TextStyle(fontSize: 11)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Seats: ${hiring.totalSeats}', style: const TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Open Roles Chips
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: hiring.positions.map((pos) {
                                  return Chip(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    label: Text(pos, style: const TextStyle(fontSize: 11)),
                                    backgroundColor: isDark ? AppColors.darkSurface : AppColors.primaryContainer.withOpacity(0.5),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 18),

                              // Actions Row: Apply Now (<= 5 Taps) & Manage Applications
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      text: hiring.hasApplied
                                          ? 'Application Submitted'
                                          : (hiring.isOpen ? 'Apply for Position' : 'Recruitment Closed'),
                                      icon: hiring.hasApplied
                                          ? Icons.done_all_rounded
                                          : Icons.assignment_turned_in_rounded,
                                      color: hiring.hasApplied ? Colors.grey.shade400 : (hiring.isOpen ? AppColors.primary : Colors.grey),
                                      onPressed: hiring.isOpen && !hiring.hasApplied
                                          ? () {
                                              if (currentUser == null || currentUser.isGuest) {
                                                MainScaffold.promptGuestLogin(context, 'apply for this recruitment');
                                              } else {
                                                context.push('/hiring/${hiring.id}/apply');
                                              }
                                            }
                                          : null,
                                    ),
                                  ),

                                  // Executive Applications Review Console (UC-2, FR-25, FR-28)
                                  if (canManageHiring) ...[
                                    const SizedBox(width: 10),
                                    IconButton.outlined(
                                      icon: const Icon(Icons.people_alt_outlined, color: AppColors.primary),
                                      tooltip: 'Review Applicant Submissions',
                                      onPressed: () => context.push(
                                        '/hiring/${hiring.id}/applications',
                                        extra: hiring.societyId,
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
          ],
        ),
      ),
    );
  }
}
