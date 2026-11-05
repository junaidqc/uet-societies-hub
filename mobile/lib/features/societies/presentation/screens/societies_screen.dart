import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/pull_to_refresh_wrapper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../navigation/presentation/screens/main_scaffold.dart';
import '../controllers/society_controller.dart';

class SocietiesScreen extends ConsumerStatefulWidget {
  const SocietiesScreen({super.key});

  @override
  ConsumerState<SocietiesScreen> createState() => _SocietiesScreenState();
}

class _SocietiesScreenState extends ConsumerState<SocietiesScreen> {
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Technical',
    'Cultural',
    'Literary',
    'Sports',
    'Social',
    'Academic',
    'Arts'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final societiesAsync = ref.watch(societiesListProvider);
    final selectedCategory = ref.watch(societyCategoryFilterProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isSystemAdmin = currentUser?.isSystemAdmin ?? false;

    // Check pending count for System Admin
    final pendingCount = isSystemAdmin
        ? (ref.watch(pendingSocietiesProvider).value?.length ?? 0)
        : 0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Societies Directory'),
        actions: [
          if (isSystemAdmin)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings_rounded),
                  tooltip: 'System Admin Approval Queue',
                  onPressed: () => context.push('/admin/society-requests'),
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Register Society',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (currentUser == null || currentUser.isGuest) {
            MainScaffold.promptGuestLogin(context, 'register a new student society');
          } else {
            context.push('/societies/register');
          }
        },
      ),
      body: PullToRefreshWrapper(
        onRefresh: () async {
          ref.invalidate(societiesListProvider);
          if (isSystemAdmin) {
            ref.invalidate(pendingSocietiesProvider);
          }
        },
        child: Column(
          children: [
            // System Admin Review Banner
            if (isSystemAdmin && pendingCount > 0) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pending_actions_rounded, color: Colors.amber.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$pendingCount pending society registration request(s) awaiting review.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/admin/society-requests'),
                      child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Live Search Bar (FR-33)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(societySearchQueryProvider.notifier).state = val;
                },
                decoration: InputDecoration(
                  hintText: 'Search societies, clubs, keywords...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(societySearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Category Filter Chips (FR-34)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(societyCategoryFilterProvider.notifier).state = cat;
                      }
                    },
                    selectedColor: isDark ? AppColors.primaryLight : AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isDark ? AppColors.darkBg : Colors.white)
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Societies List
            Expanded(
              child: societiesAsync.when(
                loading: () => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: const [
                    SkeletonCardLoader(),
                    SizedBox(height: 12),
                    SkeletonCardLoader(),
                  ],
                ),
                error: (err, _) => ErrorStateView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(societiesListProvider),
                ),
                data: (societies) {
                  if (societies.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.search_off_rounded,
                      title: 'No Societies Found',
                      description: 'Try adjusting your search terms or category filter.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 4),
                    itemCount: societies.length,
                    itemBuilder: (context, index) {
                      final society = societies[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/societies/${society.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
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
                                          ? const Icon(Icons.group_work_rounded, color: AppColors.primary, size: 28)
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            society.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryContainer.withOpacity(0.8),
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
                                              Text(
                                                '${society.followersCount} followers',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.lightTextMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Follow / Unfollow Button
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: society.isFollowed
                                            ? Colors.grey.shade300
                                            : AppColors.primary,
                                        foregroundColor: society.isFollowed
                                            ? AppColors.darkTextPrimary
                                            : Colors.white,
                                        minimumSize: const Size(86, 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        if (currentUser == null || currentUser.isGuest) {
                                          MainScaffold.promptGuestLogin(
                                            context,
                                            'follow ${society.name}',
                                          );
                                        } else {
                                          ref
                                              .read(societyActionControllerProvider.notifier)
                                              .toggleFollow(society.id, society.isFollowed);
                                        }
                                      },
                                      child: Text(
                                        society.isFollowed ? 'Following' : 'Follow',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  society.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
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
