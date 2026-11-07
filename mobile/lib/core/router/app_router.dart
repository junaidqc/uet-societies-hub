import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/navigation/presentation/screens/main_scaffold.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/societies/presentation/screens/societies_screen.dart';
import '../../features/societies/presentation/screens/society_detail_screen.dart';
import '../../features/societies/presentation/screens/society_registration_request_screen.dart';
import '../../features/societies/presentation/screens/society_management_screen.dart';
import '../../features/societies/presentation/screens/system_admin_requests_screen.dart';
import '../../features/hiring/presentation/screens/hiring_screen.dart';
import '../../features/hiring/presentation/screens/create_hiring_screen.dart';
import '../../features/hiring/presentation/screens/apply_hiring_screen.dart';
import '../../features/hiring/presentation/screens/admin_applications_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/feed/domain/models/post_model.dart';
import '../../features/feed/presentation/screens/create_edit_post_screen.dart';
import '../../features/feed/presentation/screens/create_event_screen.dart';
import '../../features/groups/presentation/screens/groups_list_screen.dart';
import '../../features/groups/presentation/screens/create_group_screen.dart';
import '../../features/groups/presentation/screens/group_chat_screen.dart';
import '../../features/groups/presentation/screens/group_info_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final GlobalKey<NavigatorState> _societiesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'societies');
final GlobalKey<NavigatorState> _hiringNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'hiring');
final GlobalKey<NavigatorState> _notificationsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'notifications');
final GlobalKey<NavigatorState> _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AppUser?>>(
      authStateProvider,
      (_, __) {
        notifyListeners();
      },
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final user = authState.value ?? _ref.read(authRepositoryProvider).currentUser;
    final isLoggedIn = user != null;

    final loc = state.matchedLocation;
    final isAuthRoute = loc == '/splash' ||
        loc == '/login' ||
        loc == '/signup' ||
        loc == '/forgot-password';

    // If authenticated/guest and trying to view splash or auth screens, route to home
    if (isLoggedIn && isAuthRoute) {
      return '/home';
    }

    // If unauthenticated and trying to view protected screens, route to splash
    if (!isLoggedIn && !isAuthRoute && loc != '/verify-otp') {
      return '/splash';
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // Splash / Welcome
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final email = state.extra as String? ??
              state.uri.queryParameters['email'] ??
              'your email';
          return OtpVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Profile Edit Sub-route
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileEditScreen(),
      ),

      // Society Detail & Action Routes (Root Navigator for full-screen push)
      GoRoute(
        path: '/societies/register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SocietyRegistrationRequestScreen(),
      ),
      GoRoute(
        path: '/societies/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SocietyDetailScreen(societyId: id);
        },
      ),
      GoRoute(
        path: '/societies/:id/manage',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SocietyManagementScreen(societyId: id);
        },
      ),

      // System Admin Society Requests Queue
      GoRoute(
        path: '/admin/society-requests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SystemAdminRequestsScreen(),
      ),

      // Post & Event Creation / Editing Routes
      GoRoute(
        path: '/posts/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateEditPostScreen(),
      ),
      GoRoute(
        path: '/posts/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final post = state.extra as PostModel?;
          return CreateEditPostScreen(postToEdit: post);
        },
      ),
      GoRoute(
        path: '/events/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateEventScreen(),
      ),

      // Hiring Application & Review Routes
      GoRoute(
        path: '/hiring/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateHiringScreen(),
      ),
      GoRoute(
        path: '/hiring/:id/apply',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ApplyHiringScreen(hiringId: id);
        },
      ),
      GoRoute(
        path: '/hiring/:id/applications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final societyId = state.extra as String? ?? '';
          return AdminApplicationsScreen(hiringId: id, societyId: societyId);
        },
      ),

      // Committee Groups & Realtime Chat Routes (Phase 5 & 5b)
      GoRoute(
        path: '/groups',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GroupsListScreen(),
      ),
      GoRoute(
        path: '/groups/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/groups/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.extra as String? ?? 'Committee Chat';
          return GroupChatScreen(groupId: id, groupName: name);
        },
      ),
      GoRoute(
        path: '/groups/:id/info',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.extra as String? ?? 'Group Details';
          return GroupInfoScreen(groupId: id, groupName: name);
        },
      ),

      // Calendar Route (Phase 6, FR-35, UC-3)
      GoRoute(
        path: '/calendar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CalendarScreen(),
      ),

      // System Admin Console (Phase 8, FR-38..FR-40)
      GoRoute(
        path: '/admin/dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Bottom Navigation Stateful Shell Route
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Branch 1: Societies
          StatefulShellBranch(
            navigatorKey: _societiesNavigatorKey,
            routes: [
              GoRoute(
                path: '/societies',
                builder: (context, state) => const SocietiesScreen(),
              ),
            ],
          ),

          // Branch 2: Hiring
          StatefulShellBranch(
            navigatorKey: _hiringNavigatorKey,
            routes: [
              GoRoute(
                path: '/hiring',
                builder: (context, state) => const HiringScreen(),
              ),
            ],
          ),

          // Branch 3: Notifications
          StatefulShellBranch(
            navigatorKey: _notificationsNavigatorKey,
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),

          // Branch 4: Profile
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
