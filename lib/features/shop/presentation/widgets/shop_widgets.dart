import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';

extension ShopFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String formatShopPrice(double value) =>
    'Rs. ${NumberFormat(value == value.roundToDouble() ? '#,##0' : '#,##0.##').format(value)}';

void promptShopLogin(BuildContext context) {
  final from = GoRouterState.of(context).uri.toString();
  context.go(Uri(path: '/login', queryParameters: {'from': from}).toString());
}

class ShopImage extends StatelessWidget {
  final String? url;
  final double? height;
  final double? width;
  final BoxFit fit;
  const ShopImage({
    super.key,
    this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: url == null || url!.isEmpty
        ? Container(
            height: height,
            width: width,
            color: AppColors.creamDark,
            child: const Icon(Icons.pets, color: AppColors.primary),
          )
        : Image.network(
            url!,
            height: height,
            width: width,
            fit: fit,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    height: height,
                    width: width,
                    color: AppColors.creamDark,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
            errorBuilder: (_, _, _) => Container(
              height: height,
              width: width,
              color: AppColors.creamDark,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.textMuted,
              ),
            ),
          ),
  );
}

class ShopCategoryCard extends StatelessWidget {
  final ShopCategory category;
  final VoidCallback onTap;
  const ShopCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ShopImage(url: category.imageUrl),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${category.productCount} products',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

class ShopProductCard extends ConsumerWidget {
  final ShopProduct product;
  final VoidCallback? onTap;
  const ShopProductCard({super.key, required this.product, this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(shopWishlistProvider);
    final auth = ref.watch(authStateProvider);
    final wishlistItem = wishlist.items
        .where((item) => item.product.id == product.id)
        .firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => context.push('/shop/product/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ShopImage(url: product.images.firstOrNull),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton.filledTonal(
                      tooltip: wishlistItem == null
                          ? 'Add to wishlist'
                          : 'Remove from wishlist',
                      icon: Icon(
                        wishlistItem == null
                            ? Icons.favorite_border
                            : Icons.favorite,
                        color: AppColors.terracotta,
                      ),
                      onPressed: () async {
                        if (!auth.isAuthenticated) {
                          promptShopLogin(context);
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          if (wishlistItem == null) {
                            await ref
                                .read(shopWishlistProvider.notifier)
                                .add(product.id);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Added to wishlist'),
                              ),
                            );
                          } else {
                            await ref
                                .read(shopWishlistProvider.notifier)
                                .remove(wishlistItem.id);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Removed from wishlist'),
                              ),
                            );
                          }
                        } catch (error) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand != null)
                    Text(
                      product.brand!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        formatShopPrice(product.displayPrice),
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(color: AppColors.primaryDark),
                      ),
                      if (product.discountedPrice != null) ...[
                        Text(
                          formatShopPrice(product.basePrice),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.textMuted,
                              ),
                        ),
                        if (product.discountPercentage != null)
                          Text(
                            '${product.discountPercentage}% off',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.terracottaDark),
                          ),
                      ],
                    ],
                  ),
                  Text(
                    product.hasStock ? 'In stock' : 'Out of stock',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: product.hasStock
                          ? AppColors.primaryDark
                          : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: !product.hasStock
                          ? null
                          : () async {
                              if (product.variants.isNotEmpty) {
                                context.push('/shop/product/${product.id}');
                                return;
                              }
                              if (!auth.isAuthenticated) {
                                promptShopLogin(context);
                                return;
                              }
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ref
                                    .read(shopCartProvider.notifier)
                                    .add(product.id);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Added to cart'),
                                  ),
                                );
                              } catch (error) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            },
                      child: Text(
                        product.variants.isNotEmpty
                            ? 'Choose options'
                            : 'Add to cart',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShopSection extends StatelessWidget {
  final String title;
  final AsyncValue<List<ShopProduct>> value;
  final VoidCallback onRetry;
  const ShopSection({
    super.key,
    required this.title,
    required this.value,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 350,
          child: value.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load $title.'),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
            data: (items) => items.isEmpty
                ? const Center(child: Text('No products available yet.'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: 220,
                      child: ShopProductCard(product: items[index]),
                    ),
                  ),
          ),
        ),
      ],
    ),
  );
}
