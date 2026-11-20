import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_shell.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/requests_page.dart';
import '../../features/onboarding/presentation/pages/owner_info_page.dart';
import '../../features/onboarding/presentation/pages/pet_info_page.dart';
import '../../features/pets/presentation/pages/my_pets_page.dart';
import '../../features/pets/presentation/pages/slots_purchase_page.dart';
import '../../features/seller/presentation/pages/seller_shell.dart';
import '../../features/vet/presentation/pages/vet_shell.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, _) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final location = state.matchedLocation;
    final isAuthPage = location == '/login' || location == '/register';
    final isSplashPage = location == '/splash';

    // 1. Initial unknown state -> show splash screen, do not redirect to /login
    if (authState.isUnknown) {
      return isSplashPage ? null : '/splash';
    }

    // 2. Unauthenticated -> force /login unless already on login or register
    if (authState.isUnauthenticated) {
      return isAuthPage ? null : '/login';
    }

    // 3. Authenticated -> decide first screen from role BEFORE anything else
    if (authState.isAuthenticated) {
      final role = authState.user?.role;

      // 3.1. ADMIN: Always lands on AdminShell; never shown pet setup
      if (role == UserRole.admin) {
        if (location.startsWith('/admin')) {
          return null;
        }
        return '/admin';
      }

      // Guard: Non-admins trying to access /admin (including deep links)
      if (location.startsWith('/admin')) {
        if (role == UserRole.veterinarian) return '/vet';
        if (role == UserRole.seller) return '/seller';
        return '/';
      }

      // 3.2. VETERINARIAN: Lands on Vet clinic portal
      if (role == UserRole.veterinarian) {
        if (location.startsWith('/vet')) {
          return null;
        }
        if (isAuthPage || isSplashPage || location == '/') {
          return '/vet';
        }
      }

      // 3.3. SELLER: Lands on Seller dashboard
      if (role == UserRole.seller) {
        if (location.startsWith('/seller')) {
          return null;
        }
        if (isAuthPage || isSplashPage || location == '/') {
          return '/seller';
        }
      }

      // 3.4. PET_OWNER (and default): Pet setup if no pets, else normal Home
      if (role == UserRole.petOwner || role == null) {
        final hasPets =
            (authState.user?.pets.isNotEmpty ?? false) ||
            (authState.onboardingStatus?.hasPets ?? false);

        if (!hasPets) {
          if (location != '/onboarding/pet' &&
              location != '/onboarding/owner') {
            return '/onboarding/pet';
          }
          return null;
        }

        if (isAuthPage || isSplashPage) {
          return '/';
        }
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
      GoRoute(path: '/admin', builder: (context, state) => const AdminShell()),
      GoRoute(path: '/vet', builder: (context, state) => const VetShell()),
      GoRoute(
        path: '/seller',
        builder: (context, state) => const SellerShell(),
      ),
      GoRoute(
        path: '/my-pets',
        builder: (context, state) => const MyPetsPage(),
      ),
      GoRoute(
        path: '/slots',
        builder: (context, state) => const SlotsPurchasePage(),
      ),
      GoRoute(
        path: '/requests',
        builder: (context, state) => const RequestsPage(),
      ),
    ],
  );
});
