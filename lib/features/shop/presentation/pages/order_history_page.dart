import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_widgets.dart';

class ShopOrderHistoryPage extends ConsumerStatefulWidget {
  const ShopOrderHistoryPage({super.key});

  @override
  ConsumerState<ShopOrderHistoryPage> createState() => _ShopOrderHistoryPageState();
}

class _ShopOrderHistoryPageState extends ConsumerState<ShopOrderHistoryPage> {
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shopOrdersProvider.notifier).load();
    });
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.error;
      case 'SHIPPED':
        return Colors.orange;
      case 'PROCESSING':
      case 'CONFIRMED':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(shopOrdersProvider);

    final filteredOrders = ordersState.items.where((order) {
      if (_selectedStatusFilter == 'ALL') return true;
      if (_selectedStatusFilter == 'ACTIVE') {
        return order.status == 'PENDING' ||
            order.status == 'CONFIRMED' ||
            order.status == 'PROCESSING' ||
            order.status == 'SHIPPED';
      }
      if (_selectedStatusFilter == 'DELIVERED') {
        return order.status == 'DELIVERED';
      }
      if (_selectedStatusFilter == 'CANCELLED') {
        return order.status == 'CANCELLED';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Orders'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ACTIVE', 'In Progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('DELIVERED', 'Delivered'),
                  const SizedBox(width: 8),
                  _buildFilterChip('CANCELLED', 'Cancelled'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Orders List
          Expanded(
            child: ordersState.isLoading && ordersState.items.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ordersState.error != null && ordersState.items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text(ordersState.error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => ref.read(shopOrdersProvider.notifier).load(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredOrders.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.creamDark,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 48,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No orders yet',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'When you purchase products, your order status and details will show up here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => context.go('/shop'),
                                    child: const Text('Start Shopping'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: () => ref.read(shopOrdersProvider.notifier).load(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredOrders.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final order = filteredOrders[index];
                                return _buildOrderCard(order);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cream,
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _selectedStatusFilter = value),
    );
  }

  Widget _buildOrderCard(ShopOrder order) {
    final statusColor = _statusColor(order.status);
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/shop/orders/${order.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order # & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),

              // Item Thumbnails Row
              Row(
                children: [
                  ...order.items.take(3).map((item) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 48,
                      height: 48,
                      child: ShopImage(
                        url: item.productImage,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }),
                  if (order.items.length > 3)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.creamDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '+${order.items.length - 3}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Total price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${order.items.length} ${order.items.length == 1 ? "item" : "items"}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatShopPrice(order.totalAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
