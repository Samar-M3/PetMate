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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(shopWishlistProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(shopWishlistProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.push('/shop/cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: wishlist.loading
          ? const Center(child: CircularProgressIndicator())
          : wishlist.error != null && wishlist.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(wishlist.error!),
                  TextButton(
                    onPressed: () =>
                        ref.read(shopWishlistProvider.notifier).load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : wishlist.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    size: 56,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(height: 12),
                  const Text('Your wishlist is empty'),
                  TextButton(
                    onPressed: () => context.go('/shop'),
                    child: const Text('Browse products'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final item in wishlist.items) _item(item)],
            ),
    );
  }

  Widget _item(ShopWishlistLine item) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ShopImage(
            url: item.product.images.firstOrNull,
            width: 100,
            height: 100,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.product.brand != null)
                  Text(
                    item.product.brand!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                Text(
                  item.product.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    Text(formatShopPrice(item.product.displayPrice)),
                    if (item.product.discountedPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          formatShopPrice(item.product.basePrice),
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  item.available
                      ? 'In stock'
                      : item.availabilityReason == 'out_of_stock'
                      ? 'Out of stock'
                      : 'Unavailable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: item.available
                        ? AppColors.primaryDark
                        : AppColors.error,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () =>
                          context.push('/shop/product/${item.product.id}'),
                      child: const Text('View product'),
                    ),
                    TextButton(
                      onPressed: !item.available || !item.product.hasStock
                          ? null
                          : () async {
                              if (item.product.variants.isNotEmpty) {
                                context.push(
                                  '/shop/product/${item.product.id}',
                                );
                                return;
                              }
                              try {
                                await ref
                                    .read(shopCartProvider.notifier)
                                    .add(item.product.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Added to cart'),
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              }
                            },
                      child: const Text('Add to cart'),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(shopWishlistProvider.notifier)
                              .remove(item.id);
                        } catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
