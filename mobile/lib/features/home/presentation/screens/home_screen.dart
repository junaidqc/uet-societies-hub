import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/pull_to_refresh_wrapper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../feed/presentation/widgets/event_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final feedTab = ref.watch(feedTabFilterProvider);
    final postsAsync = feedTab == 0
        ? ref.watch(followedFeedProvider)
        : ref.watch(publicFeedProvider);

    final eventsAsync = ref.watch(eventsListProvider);
    final adminSocietiesAsync = ref.watch(userAdminSocietiesProvider);
    final isSocietyAdmin = (adminSocietiesAsync.value?.isNotEmpty ?? false) || (user?.isSystemAdmin ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'UET Societies Hub',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Campus Calendar & Deadlines',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Committee Groups',
            onPressed: () => context.push('/groups'),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search Societies',
            onPressed: () => context.go('/societies'),
          ),
        ],
      ),
      floatingActionButton: isSocietyAdmin
          ? PopupMenuButton<String>(
              offset: const Offset(0, -110),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'post') {
                  context.push('/posts/create');
                } else if (val == 'event') {
                  context.push('/events/create');
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'post',
                  child: Row(
                    children: const [
                      Icon(Icons.campaign_outlined, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Publish Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'event',
                  child: Row(
                    children: const [
                      Icon(Icons.event_outlined, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Host Campus Event', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Create',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: PullToRefreshWrapper(
        onRefresh: () async {
          ref.invalidate(followedFeedProvider);
          ref.invalidate(publicFeedProvider);
          ref.invalidate(eventsListProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Welcome Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [AppColors.darkCard, AppColors.primaryContainerDark]
                          : [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            user != null && !user.isGuest
                                ? 'Welcome, ${user.fullName?.split(" ").first ?? "Student"}! 👋'
                                : 'Welcome, Guest Explorer! 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              user != null && !user.isGuest ? (user.rollNumber ?? 'Student') : 'Guest Mode',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user != null && !user.isGuest
                            ? 'Discover campus events, read announcements, and interact with your followed societies.'
                            : 'Browsing official public announcements. Log in to follow societies and RSVP for events.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // UPCOMING EVENTS SECTION (FR-16, FR-17)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upcoming Events & Hackathons',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (isSocietyAdmin)
                          TextButton.icon(
                            onPressed: () => context.push('/events/create'),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Event', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 250,
                    child: eventsAsync.when(
                      loading: () => ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: const [
                          SkeletonBox(width: 280, height: 230),
                          SizedBox(width: 14),
                          SkeletonBox(width: 280, height: 230),
                        ],
                      ),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Error loading events: $err', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                      ),
                      data: (events) {
                        if (events.isEmpty) {
                          return const Center(
                            child: Text('No upcoming events scheduled right now.', style: TextStyle(color: AppColors.lightTextMuted, fontSize: 13)),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            return EventCard(event: events[index]);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // FEED FILTER TABS (Following vs Explore All) (FR-13)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Following Feed'),
                      selected: feedTab == 0,
                      onSelected: (val) {
                        if (val) ref.read(feedTabFilterProvider.notifier).state = 0;
                      },
                      selectedColor: isDark ? AppColors.primaryLight : AppColors.primary,
                      labelStyle: TextStyle(
                        color: feedTab == 0
                            ? (isDark ? AppColors.darkBg : Colors.white)
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: feedTab == 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Discover All Posts'),
                      selected: feedTab == 1,
                      onSelected: (val) {
                        if (val) ref.read(feedTabFilterProvider.notifier).state = 1;
                      },
                      selectedColor: isDark ? AppColors.primaryLight : AppColors.primary,
                      labelStyle: TextStyle(
                        color: feedTab == 1
                            ? (isDark ? AppColors.darkBg : Colors.white)
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        fontWeight: feedTab == 1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // POSTS LIST (FR-11..FR-15: Newest first, pinned on top, likes, comments, edit/delete/pin)
            postsAsync.when(
              loading: () => SliverList(
                delegate: SliverChildListDelegate([
                  const SkeletonCardLoader(),
                  const SkeletonCardLoader(),
                ]),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: ErrorStateView(
                  message: err.toString(),
                  onRetry: () {
                    ref.invalidate(followedFeedProvider);
                    ref.invalidate(publicFeedProvider);
                  },
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: EmptyStateView(
                        icon: Icons.feed_outlined,
                        title: feedTab == 0 ? 'No Followed Society Posts' : 'No Announcements Found',
                        description: feedTab == 0
                            ? 'Follow societies from the Societies directory to see their announcements and updates here.'
                            : 'No announcements published yet.',
                        actionLabel: feedTab == 0 ? 'Browse Societies' : null,
                        onAction: feedTab == 0 ? () => context.go('/societies') : null,
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return PostCard(post: posts[index]);
                    },
                    childCount: posts.length,
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }
}
