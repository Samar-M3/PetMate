import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_widgets.dart';

class ShopHomePage extends ConsumerStatefulWidget {
  const ShopHomePage({super.key});

  @override
  ConsumerState<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends ConsumerState<ShopHomePage> {
  final _searchController = TextEditingController();
  String _selectedPetType = 'All';

  final List<String> _petTypes = ['All', 'Dogs', 'Cats', 'Birds', 'Small Pets'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authStateProvider);
      if (auth.isAuthenticated) {
        ref.read(shopCartProvider.notifier).load();
        ref.read(shopWishlistProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(shopCategoriesProvider);
    ref.invalidate(shopFeaturedProvider);
    ref.invalidate(shopNewArrivalsProvider);
    ref.invalidate(shopRecommendedProvider);
    final auth = ref.read(authStateProvider);
    if (auth.isAuthenticated) {
      await ref.read(shopCartProvider.notifier).load();
      await ref.read(shopWishlistProvider.notifier).load();
    }
  }

  void _onSearchSubmit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    context.push(
      Uri(
        path: '/shop/products',
        queryParameters: {'search': trimmed},
      ).toString(),
    );
  }

  void _filterByPet(String pet) {
    setState(() => _selectedPetType = pet);
    if (pet == 'All') {
      context.push('/shop/products');
    } else {
      context.push(
        Uri(
          path: '/shop/products',
          queryParameters: {'search': pet.toLowerCase()},
        ).toString(),
      );
    }
  }

  void _openCategory(ShopCategory category) {
    context.push(
      Uri(
        path: '/shop/products',
        queryParameters: {
          'categoryId': category.id,
          'categoryName': category.name,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(shopCategoriesProvider);
    final featured = ref.watch(shopFeaturedProvider);
    final arrivals = ref.watch(shopNewArrivalsProvider);
    final recommended = ref.watch(shopRecommendedProvider);
    final cartState = ref.watch(shopCartProvider);
    final wishlistState = ref.watch(shopWishlistProvider);
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PetMate Shop',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Pet Care & Essentials',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Order History Icon
          IconButton(
            tooltip: 'My Orders',
            icon: const Icon(Icons.receipt_long_outlined, color: AppColors.textPrimary),
            onPressed: () {
              if (!auth.isAuthenticated) {
                promptShopLogin(context);
                return;
              }
              context.push('/shop/orders');
            },
          ),
          // Wishlist Icon with Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Wishlist',
                icon: const Icon(Icons.favorite_border_rounded, color: AppColors.textPrimary),
                onPressed: () {
                  if (!auth.isAuthenticated) {
                    promptShopLogin(context);
                    return;
                  }
                  context.push('/shop/wishlist');
                },
              ),
              if (wishlistState.items.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.terracotta,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${wishlistState.items.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Cart Icon with Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Cart',
                icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.textPrimary),
                onPressed: () => context.push('/shop/cart'),
              ),
              if (cartState.totalCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${cartState.totalCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Search Bar Header
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _onSearchSubmit,
                  decoration: InputDecoration(
                    hintText: 'Search food, toys, beds, grooming...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 21),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
                            onPressed: () => _onSearchSubmit(_searchController.text),
                          ),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            // Promotional Banner
            SliverToBoxAdapter(
              child: ShopPromoBanner(
                onShopNow: () => context.push('/shop/products'),
              ),
            ),

            // Shop by Pet Pills
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _petTypes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final pet = _petTypes[index];
                      final isSelected = _selectedPetType == pet;
                      return ChoiceChip(
                        label: Text(
                          pet == 'All' ? '🐾 All Pets' : pet == 'Dogs' ? '🐶 Dogs' : pet == 'Cats' ? '🐱 Cats' : pet == 'Birds' ? '🦜 Birds' : '🐰 Small Pets',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) => _filterByPet(pet),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Categories Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Shop by Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/shop/products'),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'All Categories',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories Grid / Carousel
            categories.when(
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 140,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
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
              data: (items) {
                final flattened = items
                    .expand((category) => [category, ...category.children])
                    .toList();

                if (flattened.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No categories available yet.')),
                    ),
                  );
                }

                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: flattened.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => SizedBox(
                        width: 125,
                        child: ShopCategoryCard(
                          category: flattened[index],
                          onTap: () => _openCategory(flattened[index]),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Featured Products
            SliverToBoxAdapter(
              child: ShopSection(
                title: 'Featured Products',
                subtitle: 'Handpicked favorites for happy, healthy pets',
                value: featured,
                onRetry: () => ref.invalidate(shopFeaturedProvider),
                onSeeAll: () => context.push(
                  Uri(
                    path: '/shop/products',
                    queryParameters: {'featured': 'true'},
                  ).toString(),
                ),
              ),
            ),

            // New Arrivals
            SliverToBoxAdapter(
              child: ShopSection(
                title: 'New Arrivals',
                subtitle: 'Fresh arrivals and latest pet essentials',
                value: arrivals,
                onRetry: () => ref.invalidate(shopNewArrivalsProvider),
                onSeeAll: () => context.push(
                  Uri(
                    path: '/shop/products',
                    queryParameters: {'sortBy': 'newest'},
                  ).toString(),
                ),
              ),
            ),

            // General Recommendations / Best Sellers
            SliverToBoxAdapter(
              child: ShopSection(
                title: 'Recommended for You',
                subtitle: 'Popular treats, toys, and care items',
                value: recommended,
                onRetry: () => ref.invalidate(shopRecommendedProvider),
                onSeeAll: () => context.push('/shop/products'),
              ),
            ),

            // Safe Area bottom spacer
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
