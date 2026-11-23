import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_widgets.dart';

class ShopWishlistPage extends ConsumerStatefulWidget {
  const ShopWishlistPage({super.key});

  @override
  ConsumerState<ShopWishlistPage> createState() => _ShopWishlistPageState();
}

class _ShopWishlistPageState extends ConsumerState<ShopWishlistPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shopWishlistProvider.notifier).load();
      ref.read(shopCartProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(shopWishlistProvider);
    final cartState = ref.watch(shopCartProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          wishlist.items.isNotEmpty
              ? 'My Wishlist (${wishlist.items.length})'
              : 'Wishlist',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cart',
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.shopping_bag_outlined, color: AppColors.textPrimary),
                if (cartState.totalCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cartState.totalCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/shop/cart'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wishlist.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : wishlist.error != null && wishlist.items.isEmpty
              ? _buildError(wishlist.error!)
              : wishlist.items.isEmpty
                  ? _buildEmpty()
                  : _buildWishlist(wishlist.items),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.creamDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 56,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your wishlist is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Save your favorite food, treats, toys, and essentials here to purchase later!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.go('/shop'),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text(
                'Browse Pet Shop',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(shopWishlistProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlist(List<ShopWishlistLine> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final line = items[index];
        final prod = line.product;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              GestureDetector(
                onTap: () => context.push('/shop/product/${prod.id}'),
                child: SizedBox(
                  width: 85,
                  height: 85,
                  child: ShopImage(
                    url: prod.images.firstOrNull,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/shop/product/${prod.id}'),
                            child: Text(
                              prod.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => ref.read(shopWishlistProvider.notifier).remove(line.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatShopPrice(prod.displayPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Action Buttons
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (prod.variants.isNotEmpty) {
                                context.push('/shop/product/${prod.id}');
                                return;
                              }
                              await ref.read(shopCartProvider.notifier).add(prod.id);
                              await ref.read(shopWishlistProvider.notifier).remove(line.id);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('${prod.name} moved to cart!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                              );
                            }
                          },
                          icon: const Icon(Icons.shopping_bag_outlined, size: 14),
                          label: Text(
                            prod.variants.isNotEmpty ? 'Select Options' : 'Move to Cart',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
