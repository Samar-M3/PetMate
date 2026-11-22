import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/onboarding/presentation/pages/owner_info_page.dart';
import '../../features/onboarding/presentation/pages/pet_info_page.dart';
import '../../features/shop/presentation/pages/shop_home_page.dart';
import '../../features/shop/presentation/pages/shop_listing_page.dart';
import '../../features/shop/presentation/pages/product_details_page.dart';
import '../../features/shop/presentation/pages/cart_page.dart';
import '../../features/shop/presentation/pages/wishlist_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthPage = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final location = state.matchedLocation;
      final isPublicShopPage = location == '/shop' || location == '/shop/products' || location.startsWith('/shop/product/');

      // 1. If not authenticated, force to login unless on register
      if (!authState.isAuthenticated) {
        if (isAuthPage || isPublicShopPage) return null;
        return Uri(path: '/login', queryParameters: {'from': state.uri.toString()}).toString();
      }

      // 2. If authenticated but onboarding is incomplete
      final status = authState.onboardingStatus;
      if (status != null && !status.onboardingCompleted) {
        if (status.nextStep == 'PET_INFO' && state.matchedLocation != '/onboarding/pet') {
          return '/onboarding/pet';
        }
        if (status.nextStep == 'OWNER_INFO' && state.matchedLocation != '/onboarding/owner') {
          return '/onboarding/owner';
        }
      }

      // 3. If authenticated & completed, redirect away from login/register
      if (isAuthPage) {
        final destination = state.uri.queryParameters['from'];
        if (destination != null && destination.startsWith('/shop/')) return destination;
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
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
      GoRoute(path: '/shop', builder: (context, state) => const ShopHomePage()),
      GoRoute(
        path: '/shop/products',
        builder: (context, state) => ShopListingPage(
          categoryId: state.uri.queryParameters['categoryId'],
          categoryName: state.uri.queryParameters['categoryName'],
          search: state.uri.queryParameters['search'],
        ),
      ),
      GoRoute(path: '/shop/product/:id', builder: (context, state) => ProductDetailsPage(productId: state.pathParameters['id']!)),
      GoRoute(path: '/shop/cart', builder: (context, state) => const ShopCartPage()),
      GoRoute(path: '/shop/wishlist', builder: (context, state) => const ShopWishlistPage()),
    ],
  );
});
