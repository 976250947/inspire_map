import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/ai_chat/view/ai_chat_page.dart';
import '../../features/auth/view/login_page.dart';
import '../../features/community/view/community_page.dart';
import '../../features/community/view/publish_post_page.dart';
import '../../features/map/view/map_page.dart';
import '../../features/onboarding/view/onboarding_page.dart';
import '../../features/plan/view/plan_detail_page.dart';
import '../../features/plan/view/plan_list_page.dart';
import '../../features/profile/view/bookmarks_page.dart';
import '../../features/profile/view/footprint_list_page.dart';
import '../../features/profile/view/my_posts_page.dart';
import '../../features/profile/view/profile_page.dart';
import '../../features/profile/view/travel_poster_page.dart';
import '../../features/route_plan/view/route_plan_page.dart';
import '../../features/start/view/start_page.dart';
import '../shell/app_shell.dart';

class AppRouter {
  static const String start = '/start';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String map = '/map';
  static const String profile = '/profile';
  static const String aiChat = '/ai_chat';
  static const String footprints = '/footprints';
  static const String myPosts = '/my_posts';
  static const String bookmarks = '/bookmarks';
  static const String travelPoster = '/travel_poster';
  static const String community = '/community';
  static const String publishPost = '/publish_post';
  static const String routePlan = '/route_plan';
  static const String plans = '/plans';
  static const String postDetail = '/post/:postId';

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static const Set<String> _authRequiredRoutes = <String>{
    publishPost,
    routePlan,
    footprints,
    myPosts,
    bookmarks,
    travelPoster,
    profile,
    plans,
  };

  static bool _isLoggedIn() {
    if (!Hive.isBoxOpen('user_prefs')) {
      return false;
    }
    final box = Hive.box('user_prefs');
    final token = box.get('auth_token') as String?;
    return token != null && token.isNotEmpty;
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: start,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final path = state.matchedLocation;
      if (_authRequiredRoutes.contains(path) && !_isLoggedIn()) {
        return login;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: start,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const StartPage(),
        ),
      ),
      GoRoute(
        path: login,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const OnboardingPage(),
        ),
      ),
      GoRoute(
        path: publishPost,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const PublishPostPage(),
        ),
      ),
      GoRoute(
        path: routePlan,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const RoutePlanPage(),
        ),
      ),
      GoRoute(
        path: postDetail,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: CommunityPage(
            initialPostId: state.pathParameters['postId'],
          ),
        ),
      ),
      GoRoute(
        path: '/plans/:planId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: PlanDetailPage(
            planId: state.pathParameters['planId'] ?? '',
          ),
        ),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        pageBuilder: (context, state, child) => MaterialPage<void>(
          key: state.pageKey,
          child: AppShell(child: child),
        ),
        routes: <RouteBase>[
          GoRoute(
            path: map,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: MapPage(),
            ),
          ),
          GoRoute(
            path: aiChat,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: AiChatPage(),
            ),
          ),
          GoRoute(
            path: community,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: CommunityPage(),
            ),
          ),
          GoRoute(
            path: footprints,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: FootprintListPage(),
            ),
          ),
          GoRoute(
            path: myPosts,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: MyPostsPage(),
            ),
          ),
          GoRoute(
            path: bookmarks,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: BookmarksPage(),
            ),
          ),
          GoRoute(
            path: plans,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: PlanListPage(),
            ),
          ),
          GoRoute(
            path: travelPoster,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: TravelPosterPage(),
            ),
          ),
          GoRoute(
            path: profile,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: ProfilePage(),
            ),
          ),
        ],
      ),
    ],
  );
}
