import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_shell.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/data/models/connection_request_model.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/requests_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_flow_page.dart';
import '../../features/onboarding/presentation/pages/owner_info_page.dart';
import '../../features/onboarding/presentation/pages/pet_info_page.dart';
import '../../features/registration/presentation/pages/pet_owner_registration_flow_page.dart';
import '../../features/registration/presentation/pages/role_selection_page.dart';
import '../../features/pets/presentation/pages/my_pets_page.dart';
import '../../features/pets/presentation/pages/pet_details_page.dart';
import '../../features/pets/presentation/pages/slots_purchase_page.dart';
import '../../features/seller/presentation/pages/seller_add_product_page.dart';
import '../../features/seller/presentation/pages/seller_orders_page.dart';
import '../../features/seller/presentation/pages/seller_order_detail_page.dart';
import '../../features/profile/presentation/pages/owner_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/seller/presentation/pages/seller_registration_page.dart';
import '../../features/seller/presentation/pages/seller_shell.dart';
import '../../features/seller/presentation/pages/seller_status_page.dart';
import '../../features/shop/presentation/pages/cart_page.dart';
import '../../features/shop/presentation/pages/checkout_page.dart';
import '../../features/shop/presentation/pages/order_detail_page.dart';
import '../../features/shop/presentation/pages/order_history_page.dart';
import '../../features/shop/presentation/pages/product_details_page.dart';
import '../../features/shop/presentation/pages/shop_home_page.dart';
import '../../features/shop/presentation/pages/shop_listing_page.dart';
import '../../features/shop/presentation/pages/wishlist_page.dart';
import '../../features/chat/presentation/pages/chat_route_page.dart';
import '../../features/chat/presentation/pages/message_request_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/notification_settings_page.dart';
import '../../features/care_events/screens/vet_login_screen.dart';
import '../../features/care_events/screens/vet_home_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, _) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final location = state.matchedLocation;
    if (location == '/seller/login') {
      return '/login';
    }

    final isAuthPage =
        location == '/login' ||
        location == '/register' ||
        location == '/register/pet-owner' ||
        location == '/seller/register' ||
        location == '/vet-login';
    final isSplashPage = location == '/splash';
    final isPublicShopPage =
        location == '/shop' ||
        location == '/shop/products' ||
        location.startsWith('/shop/product/');
    // Vet portal pages (login is public, home is protected by screen)
    final isVetPortalPage = location == '/vet-login' || location == '/vet-home';

    // 1. Initial unknown state -> show splash screen, do not redirect to /login
    if (authState.isUnknown) {
      return isSplashPage ? null : '/splash';
    }

    // 2. Unauthenticated -> allow public shop pages, vet portal pages, else force /login
    if (authState.isUnauthenticated) {
      if (isAuthPage || isPublicShopPage || isVetPortalPage) return null;
      return '/login';
    }

    // 3. Authenticated -> decide first screen from role BEFORE anything else
    if (authState.isAuthenticated) {
      // 3.0. If user profile is not yet fetched, stay on / redirect to splash.
      // This prevents prematurely routing ADMIN/SELLER to the pet-owner flow
      // before role information is resolved from the backend.
      // If user profile is already loaded, never kick them back to /splash during background syncs.
      if (authState.user == null) {
        return isSplashPage ? null : '/splash';
      }

      // If already on the splash screen and still performing initial load, stay on splash.
      if (isSplashPage && authState.isLoading) {
        return null;
      }

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

      // 3.4. PET_OWNER (and default): Registration flow if not completed, else normal Home
      if (role == UserRole.petOwner || role == null) {
        final registrationCompleted =
            authState.user?.registrationCompleted ??
            authState.isOnboardingCompleted;

        if (!registrationCompleted) {
          if (location != '/register/pet-owner' &&
              location != '/onboarding' &&
              location != '/onboarding/pet' &&
              location != '/onboarding/owner') {
            return '/register/pet-owner';
          }
          return null;
        }

        if (isAuthPage || isSplashPage || location == '/register/pet-owner' || location.startsWith('/onboarding')) {
          final destination = state.uri.queryParameters['from'];
          if (destination != null && destination.startsWith('/shop/')) {
            return destination;
          }
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
        builder: (context, state) => const RoleSelectionPage(),
      ),
      GoRoute(
        path: '/register/pet-owner',
        builder: (context, state) => const PetOwnerRegistrationFlowPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowPage(),
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
      GoRoute(path: '/vet', builder: (context, state) => const VetHomeScreen()),
      GoRoute(path: '/vet-login', builder: (context, state) => const VetLoginScreen()),
      GoRoute(
        path: '/vet-home',
        builder: (context, state) => const VetHomeScreen(),
      ),
      GoRoute(
        path: '/seller/register',
        builder: (context, state) => const SellerRegistrationPage(),
      ),
      GoRoute(
        path: '/seller/status',
        builder: (context, state) => const SellerStatusPage(),
      ),
      GoRoute(
        path: '/seller',
        builder: (context, state) => const SellerShell(),
      ),
      GoRoute(
        path: '/seller/products/add',
        builder: (context, state) => const SellerAddProductPage(),
      ),
      GoRoute(
        path: '/seller/orders',
        builder: (context, state) => const SellerOrdersPage(),
      ),
      GoRoute(
        path: '/seller/orders/:id',
        builder: (context, state) => SellerOrderDetailPage(
          orderId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/my-pets',
        builder: (context, state) => const MyPetsPage(),
      ),
      GoRoute(
        path: '/slots',
        builder: (context, state) =>
            SlotsPurchasePage(targetPetId: state.uri.queryParameters['petId']),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/requests',
        builder: (context, state) => const RequestsPage(),
      ),
      GoRoute(
        path: '/request/:requestId',
        builder: (context, state) => MessageRequestPage(
          requestId: state.pathParameters['requestId'] ?? '',
          initialRequest: state.extra is ConnectionRequestModel
              ? state.extra as ConnectionRequestModel
              : null,
        ),
      ),
      GoRoute(
        path: '/pet/:petId',
        builder: (context, state) =>
            PetDetailsPage(petId: state.pathParameters['petId'] ?? ''),
      ),
      GoRoute(
        path: '/owner/:userId',
        builder: (context, state) =>
            OwnerProfilePage(userId: state.pathParameters['userId'] ?? ''),
      ),
      GoRoute(path: '/shop', builder: (context, state) => const ShopHomePage()),
      GoRoute(
        path: '/shop/products',
        builder: (context, state) => ShopListingPage(
          categoryId: state.uri.queryParameters['categoryId'],
          categoryName: state.uri.queryParameters['categoryName'],
          search: state.uri.queryParameters['search'],
        ),
      ),
      GoRoute(
        path: '/shop/product/:id',
        builder: (context, state) =>
            ProductDetailsPage(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/shop/cart',
        builder: (context, state) => const ShopCartPage(),
      ),
      GoRoute(
        path: '/shop/wishlist',
        builder: (context, state) => const ShopWishlistPage(),
      ),
      GoRoute(
        path: '/shop/checkout',
        builder: (context, state) => const ShopCheckoutPage(),
      ),
      GoRoute(
        path: '/shop/orders',
        builder: (context, state) => const ShopOrderHistoryPage(),
      ),
      GoRoute(
        path: '/shop/orders/:id',
        builder: (context, state) =>
            ShopOrderDetailPage(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (context, state) =>
            ChatRoutePage(matchId: state.pathParameters['matchId'] ?? ''),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => const NotificationSettingsPage(),
      ),
    ],
  );
});
