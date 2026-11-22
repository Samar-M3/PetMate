import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_widgets.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailsPage({super.key, required this.productId});
  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int _imageIndex = 0;
  int _quantity = 1;
  ShopVariant? _variant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authStateProvider).isAuthenticated) {
        ref.read(shopWishlistProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(shopProductProvider(widget.productId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product details'),
        actions: [
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () => context.push('/shop/wishlist'),
            icon: const Icon(Icons.favorite_border),
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.push('/shop/cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: productState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load this product.'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(shopProductProvider(widget.productId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: _buildProduct,
      ),
    );
  }

  Widget _buildProduct(ShopProduct product) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final variantStock =
        _variant?.availableStock ??
        (product.variants.isEmpty ? product.availableStock : 0);
    final price =
        _variant?.priceOverride ?? product.discountedPrice ?? product.basePrice;
    final content = [
      _gallery(product),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.brand != null)
              Text(
                product.brand!,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 6),
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (product.categoryName != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  product.categoryName!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                Text(
                  formatShopPrice(price),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: AppColors.primaryDark),
                ),
                if (_variant == null && product.discountedPrice != null)
                  Text(
                    formatShopPrice(product.basePrice),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (_variant == null && product.discountPercentage != null)
                  Chip(label: Text('${product.discountPercentage}% off')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.variants.isNotEmpty && _variant == null
                  ? 'Select an option to check stock'
                  : variantStock > 0
                  ? '$variantStock available'
                  : 'Out of stock',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: variantStock > 0
                    ? AppColors.primaryDark
                    : AppColors.error,
              ),
            ),
            if (product.variants.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Options', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: product.variants
                    .map(
                      (variant) => ChoiceChip(
                        label: Text(
                          variant.options.entries
                              .map((entry) => '${entry.key}: ${entry.value}')
                              .join(' · '),
                        ),
                        selected: _variant?.id == variant.id,
                        onSelected:
                            variant.isAvailable && variant.availableStock > 0
                            ? (_) => setState(() {
                                _variant = variant;
                                _quantity = 1;
                              })
                            : null,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                IconButton(
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_quantity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: variantStock > _quantity
                      ? () => setState(() => _quantity++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                Text('Quantity', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (product.storeName != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.creamDark,
                  backgroundImage: product.storeImageUrl == null
                      ? null
                      : NetworkImage(product.storeImageUrl!),
                  child: product.storeImageUrl == null
                      ? const Icon(Icons.storefront, color: AppColors.primary)
                      : null,
                ),
                title: Text(product.storeName!),
                subtitle: const Text('Approved PetMate store'),
              ),
            const SizedBox(height: 12),
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              product.description?.isNotEmpty == true
                  ? product.description!
                  : 'No description is available for this product.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _actions(product, variantStock),
          ],
        ),
      ),
    ];
    return SingleChildScrollView(
      child: wide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: content[0]),
                    Expanded(child: content[1]),
                  ],
                ),
              ),
            )
          : Column(children: content),
    );
  }

  Widget _gallery(ShopProduct product) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ShopImage(
            url: product.images.isEmpty
                ? null
                : product.images[_imageIndex.clamp(
                    0,
                    product.images.length - 1,
                  )],
          ),
        ),
        if (product.images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: product.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => InkWell(
                onTap: () => setState(() => _imageIndex = index),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: index == _imageIndex
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ShopImage(
                    url: product.images[index],
                    width: 70,
                    height: 70,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _actions(ShopProduct product, int stock) {
    final auth = ref.watch(authStateProvider);
    final wishlist = ref.watch(shopWishlistProvider);
    final saved = wishlist.items
        .where((item) => item.product.id == product.id)
        .firstOrNull;
    final hasRequiredVariant = product.variants.isEmpty || _variant != null;
    final canAdd = hasRequiredVariant && stock > 0 && _quantity <= stock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: !canAdd
              ? null
              : () async {
                  if (!auth.isAuthenticated) {
                    promptShopLogin(context);
                    return;
                  }
                  try {
                    await ref
                        .read(shopCartProvider.notifier)
                        .add(
                          product.id,
                          variantId: _variant?.id,
                          quantity: _quantity,
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to cart')),
                      );
                    }
                  } catch (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  }
                },
          icon: const Icon(Icons.shopping_cart_outlined),
          label: const Text('Add to cart'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            if (!auth.isAuthenticated) {
              promptShopLogin(context);
              return;
            }
            try {
              if (saved == null) {
                await ref.read(shopWishlistProvider.notifier).add(product.id);
              } else {
                await ref.read(shopWishlistProvider.notifier).remove(saved.id);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      saved == null
                          ? 'Added to wishlist'
                          : 'Removed from wishlist',
                    ),
                  ),
                );
              }
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }
          },
          icon: Icon(saved == null ? Icons.favorite_border : Icons.favorite),
          label: Text(
            saved == null ? 'Add to wishlist' : 'Remove from wishlist',
          ),
        ),
      ],
    );
  }
}
