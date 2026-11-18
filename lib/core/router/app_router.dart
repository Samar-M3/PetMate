import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/onboarding/presentation/pages/owner_info_page.dart';
import '../../features/onboarding/presentation/pages/pet_info_page.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, _) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final isAuthPage =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';
    final isSplashPage = state.matchedLocation == '/splash';

    // 1. Initial unknown state -> show splash screen, do not redirect to /login
    if (authState.isUnknown) {
      return isSplashPage ? null : '/splash';
    }

    // 2. Unauthenticated -> force /login unless already on login or register
    if (authState.isUnauthenticated) {
      return isAuthPage ? null : '/login';
    }

    // 3. Authenticated -> check onboarding status or redirect away from auth/splash pages
    if (authState.isAuthenticated) {
      // Admin route protection
      if (state.matchedLocation.startsWith('/admin')) {
        if (authState.user?.role != UserRole.admin) {
          return '/';
        }
      }

      final status = authState.onboardingStatus;
      if (status != null && !status.onboardingCompleted) {
        if (status.nextStep == 'PET_INFO' &&
            state.matchedLocation != '/onboarding/pet') {
          return '/onboarding/pet';
        }
        if (status.nextStep == 'OWNER_INFO' &&
            state.matchedLocation != '/onboarding/owner') {
          return '/onboarding/owner';
        }
      }

      // If user is on /login, /register, or /splash, send them home
      if (isAuthPage || isSplashPage) {
        return '/';
      }
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: routerNotifier,
    redirect: routerNotifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/onboarding/pet',
        builder: (context, state) => const PetInfoPage(),
      ),
      GoRoute(
        path: '/onboarding/owner',
        builder: (context, state) => const OwnerInfoPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Admin Panel'))),
      ),
    ],
  );
});
