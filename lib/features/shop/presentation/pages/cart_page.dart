import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_widgets.dart';

class ShopCartPage extends ConsumerStatefulWidget {
  const ShopCartPage({super.key});
  @override
  ConsumerState<ShopCartPage> createState() => _ShopCartPageState();
}

class _ShopCartPageState extends ConsumerState<ShopCartPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(shopCartProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(shopCartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping cart')),
      body: cart.loading
          ? const Center(child: CircularProgressIndicator())
          : cart.error != null && cart.items.isEmpty
          ? _error(cart.error!)
          : cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 56,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(height: 12),
                  const Text('Your cart is empty'),
                  TextButton(
                    onPressed: () => context.go('/shop'),
                    child: const Text('Browse products'),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final summary = _summary(cart);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final line in cart.items) _line(line),
                    const SizedBox(height: 16),
                    if (constraints.maxWidth > 800)
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(width: 360, child: summary),
                      )
                    else
                      summary,
                  ],
                );
              },
            ),
    );
  }

  Widget _error(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton(
          onPressed: () => ref.read(shopCartProvider.notifier).load(),
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _line(ShopCartLine line) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopImage(
            url: line.product.images.firstOrNull,
            width: 96,
            height: 96,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (line.variant != null)
                  Text(
                    line.variant!.options.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(formatShopPrice(line.unitPrice)),
                Text(
                  line.available
                      ? '${line.availableStock} available'
                      : (line.availabilityReason ?? 'Unavailable'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: line.available
                        ? AppColors.primaryDark
                        : AppColors.error,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      iconSize: 20,
                      onPressed: line.quantity > 1 && line.available
                          ? () => _update(line, line.quantity - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${line.quantity}'),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      iconSize: 20,
                      onPressed:
                          line.quantity < line.availableStock && line.available
                          ? () => _update(line, line.quantity + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      iconSize: 20,
                      tooltip: 'Remove item',
                      onPressed: () => _confirmRemove(line.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                Text(
                  'Subtotal: ${formatShopPrice(line.lineSubtotal)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _summary(ShopCartState cart) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Order summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _summaryRow('Items', '${cart.items.length}'),
          _summaryRow('Total quantity', '${cart.totalQuantity}'),
          _summaryRow('Subtotal', formatShopPrice(cart.subtotal)),
          const Divider(),
          _summaryRow('Estimated total', formatShopPrice(cart.subtotal)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Checkout is coming soon. No order or payment was started.',
                ),
              ),
            ),
            child: const Text('Proceed to Checkout'),
          ),
        ],
      ),
    ),
  );
  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );

  Future<void> _update(ShopCartLine line, int quantity) async {
    try {
      await ref.read(shopCartProvider.notifier).update(line.id, quantity);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _confirmRemove(String id) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove item?'),
        content: const Text('This item will be removed from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove != true) return;
    try {
      await ref.read(shopCartProvider.notifier).remove(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
