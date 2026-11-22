import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/widgets/profile_bottom_sheet.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_widgets.dart';

class ShopHomePage extends ConsumerStatefulWidget {
  const ShopHomePage({super.key});
  @override
  ConsumerState<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends ConsumerState<ShopHomePage> {
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (ref.read(authStateProvider).isAuthenticated) {
        ref.read(shopCartProvider.notifier).load();
        ref.read(shopWishlistProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _searchProducts() {
    final value = _search.text.trim();
    context.push(
      Uri(
        path: '/shop/products',
        queryParameters: {if (value.isNotEmpty) 'search': value},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(shopCategoriesProvider);
    final featured = ref.watch(shopFeaturedProvider);
    final arrivals = ref.watch(shopNewArrivalsProvider);
    final recommended = ref.watch(shopRecommendedProvider);
    final cart = ref.watch(shopCartProvider);
    final isWide = MediaQuery.sizeOf(context).width > 900;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'PetMate Shop',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: AppColors.primaryDark),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Wishlist',
                          onPressed: () => context.push('/shop/wishlist'),
                          icon: const Icon(Icons.favorite_border),
                        ),
                        IconButton(
                          tooltip: 'Profile',
                          onPressed: () {
                            if (ref.read(authStateProvider).isAuthenticated) {
                              ProfileBottomSheet.show(context);
                            } else {
                              promptShopLogin(context);
                            }
                          },
                          icon: const Icon(Icons.person_outline),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              tooltip: 'Cart',
                              onPressed: () => context.push('/shop/cart'),
                              icon: const Icon(Icons.shopping_cart_outlined),
                            ),
                            if (cart.totalQuantity > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: CircleAvatar(
                                  radius: 9,
                                  backgroundColor: AppColors.terracotta,
                                  child: Text(
                                    '${cart.totalQuantity}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchProducts(),
                      decoration: InputDecoration(
                        hintText: 'Search products, brands, or categories',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Search',
                          onPressed: _searchProducts,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: isWide ? 190 : 220,
                    color: AppColors.creamDark,
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Good care starts with the right essentials',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Explore food, play, grooming, and everyday comfort for your pet.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () =>
                                      context.push('/shop/products'),
                                  child: const Text('Explore products'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (featured.asData?.value.isNotEmpty == true)
                          SizedBox(
                            width: isWide ? 220 : 110,
                            height: double.infinity,
                            child: ShopImage(
                              url: featured
                                  .asData!
                                  .value
                                  .first
                                  .images
                                  .firstOrNull,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Text(
                  'Shop by category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            categories.when(
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    children: [
                      const Text('Could not load categories.'),
                      TextButton(
                        onPressed: () => ref.invalidate(shopCategoriesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('No categories are available yet.'),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid.builder(
                        itemCount: items
                            .expand(
                              (category) => [category, ...category.children],
                            )
                            .length,
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 190,
                          mainAxisExtent: 180,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          final flattened = items
                              .expand(
                                (category) => [category, ...category.children],
                              )
                              .toList();
                          return ShopCategoryCard(
                            category: flattened[index],
                            onTap: () => _openCategory(flattened[index]),
                          );
                        },
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: ShopSection(
                title: 'Featured products',
                value: featured,
                onRetry: () => ref.invalidate(shopFeaturedProvider),
              ),
            ),
            SliverToBoxAdapter(
              child: ShopSection(
                title: 'New arrivals',
                value: arrivals,
                onRetry: () => ref.invalidate(shopNewArrivalsProvider),
              ),
            ),
            SliverToBoxAdapter(
              child: ShopSection(
                title: 'General recommendations',
                value: recommended,
                onRetry: () => ref.invalidate(shopRecommendedProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(ShopCategory category) => context.push(
    Uri(
      path: '/shop/products',
      queryParameters: {
        'categoryId': category.id,
        'categoryName': category.name,
      },
    ).toString(),
  );
}
