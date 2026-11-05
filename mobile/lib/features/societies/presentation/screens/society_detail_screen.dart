import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/pull_to_refresh_wrapper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../navigation/presentation/screens/main_scaffold.dart';
import '../controllers/society_controller.dart';
import '../../domain/models/society_model.dart';
import '../../domain/models/office_bearer_model.dart';

class SocietyDetailScreen extends ConsumerStatefulWidget {
  final String societyId;

  const SocietyDetailScreen({
    super.key,
    required this.societyId,
  });

  @override
  ConsumerState<SocietyDetailScreen> createState() => _SocietyDetailScreenState();
}

class _SocietyDetailScreenState extends ConsumerState<SocietyDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final societyAsync = ref.watch(societyDetailProvider(widget.societyId));
    final bearersAsync = ref.watch(societyOfficeBearersProvider(widget.societyId));
    final roleAsync = ref.watch(userSocietyRoleProvider(widget.societyId));
    final currentUser = ref.watch(currentUserProvider);

    final isSocietyExecutive = roleAsync.value != null || (currentUser?.isSystemAdmin ?? false);

    return Scaffold(
      body: societyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorStateView(
            message: err.toString(),
            onRetry: () => ref.invalidate(societyDetailProvider(widget.societyId)),
          ),
        ),
        data: (society) {
          if (society == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Society not found')),
            );
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                    onPressed: () => context.pop(),
                  ),
                  actions: [
                    if (isSocietyExecutive)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 20),
                        ),
                        tooltip: 'Manage Society',
                        onPressed: () => context.push('/societies/${society.id}/manage'),
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        society.bannerUrl != null
                            ? Image.network(
                                society.bannerUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.primaryDark, AppColors.primaryLight],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.2),
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          bottom: 20,
                          right: 20,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 32,
                                  backgroundColor: AppColors.primaryContainer,
                                  backgroundImage: society.logoUrl != null
                                      ? NetworkImage(society.logoUrl!)
                                      : null,
                                  child: society.logoUrl == null
                                      ? const Icon(Icons.group_work_rounded, size: 32, color: AppColors.primary)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      society.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            society.category,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${society.followersCount} followers',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    child: Row(
                      children: [
                        // Follow / Unfollow Button (FR-9)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: society.isFollowed ? Colors.grey.shade300 : AppColors.primary,
                              foregroundColor: society.isFollowed ? AppColors.darkTextPrimary : Colors.white,
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            icon: Icon(
                              society.isFollowed ? Icons.check_rounded : Icons.person_add_rounded,
                              size: 18,
                            ),
                            label: Text(society.isFollowed ? 'Following' : 'Follow Society'),
                            onPressed: () {
                              if (currentUser == null || currentUser.isGuest) {
                                MainScaffold.promptGuestLogin(context, 'follow ${society.name}');
                              } else {
                                ref
                                    .read(societyActionControllerProvider.notifier)
                                    .toggleFollow(society.id, society.isFollowed);
                              }
                            },
                          ),
                        ),
                        if (isSocietyExecutive) ...[
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              minimumSize: const Size(120, 44),
                            ),
                            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                            label: const Text('Manage'),
                            onPressed: () => context.push('/societies/${society.id}/manage'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      indicatorColor: AppColors.primary,
                      tabs: const [
                        Tab(text: 'About'),
                        Tab(text: 'Office Bearers'),
                        Tab(text: 'Opportunities'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: ABOUT
                _buildAboutTab(context, society),

                // TAB 2: OFFICE BEARERS (FR-8)
                _buildOfficeBearersTab(bearersAsync),

                // TAB 3: OPPORTUNITIES / HIRINGS
                _buildOpportunitiesTab(context, society),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAboutTab(BuildContext context, SocietyModel society) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'About the Society',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          society.description,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        const Text(
          'Contact & Official Channels',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (society.email != null)
          _buildContactRow(Icons.email_outlined, 'Official Email', society.email!),
        if (society.website != null)
          _buildContactRow(Icons.language_rounded, 'Website', society.website!),
        if (society.socialLinks['facebook'] != null)
          _buildContactRow(Icons.share_rounded, 'Facebook', society.socialLinks['facebook'].toString()),
        if (society.socialLinks['linkedin'] != null)
          _buildContactRow(Icons.link_rounded, 'LinkedIn', society.socialLinks['linkedin'].toString()),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.lightTextMuted)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeBearersTab(AsyncValue<List<OfficeBearerModel>> bearersAsync) {
    return bearersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => ErrorStateView(message: err.toString()),
      data: (bearers) {
        if (bearers.isEmpty) {
          return const Center(child: Text('No office bearers listed yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bearers.length,
          itemBuilder: (context, index) {
            final bearer = bearers[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: bearer.isPresident ? AppColors.primary : AppColors.primaryContainer,
                  backgroundImage: bearer.avatarUrl != null ? NetworkImage(bearer.avatarUrl!) : null,
                  child: bearer.avatarUrl == null
                      ? Icon(
                          bearer.isPresident ? Icons.star_rounded : Icons.person_rounded,
                          color: bearer.isPresident ? Colors.white : AppColors.primary,
                        )
                      : null,
                ),
                title: Text(bearer.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${bearer.rollNumber} • ${bearer.department}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bearer.isPresident
                        ? AppColors.primaryContainer
                        : (bearer.isAdmin ? Colors.blue.shade50 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bearer.roleDisplay,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: bearer.isPresident
                          ? AppColors.primaryDark
                          : (bearer.isAdmin ? Colors.blue.shade800 : Colors.grey.shade700),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOpportunitiesTab(BuildContext context, SocietyModel society) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.work_outline_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('Executive Recruitment 2026', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('OPEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Open positions: Mobile App Developer, UI/UX Designer, Event Lead.'),
                const SizedBox(height: 12),
                AppButton(
                  text: 'Apply via Hiring Portal',
                  icon: Icons.assignment_turned_in_rounded,
                  onPressed: () => context.go('/hiring'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
