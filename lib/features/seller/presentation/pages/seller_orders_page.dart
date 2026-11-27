import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/seller_order_model.dart';
import '../providers/seller_provider.dart';

class SellerOrdersPage extends ConsumerStatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  ConsumerState<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends ConsumerState<SellerOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['All', 'Pending', 'Received', 'Delivered'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return AppColors.success;
      case 'RECEIVED':
        return AppColors.primary;
      case 'PENDING':
        return AppColors.terracotta;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  List<SellerCustomerOrder> _filterOrders(
      List<SellerCustomerOrder> orders, String tab) {
    switch (tab) {
      case 'Pending':
        return orders
            .where((o) => o.orderStatus.toUpperCase() == 'PENDING')
            .toList();
      case 'Received':
        return orders
            .where((o) => o.orderStatus.toUpperCase() == 'RECEIVED')
            .toList();
      case 'Delivered':
        return orders
            .where((o) => o.orderStatus.toUpperCase() == 'DELIVERED')
            .toList();
      default:
        return orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Customer Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load orders: ${state.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(sellerOrdersProvider.notifier)
                              .loadOrders(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _tabs.map((tab) {
                    final filtered = _filterOrders(state.orders, tab);
                    if (filtered.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () => ref
                            .read(sellerOrdersProvider.notifier)
                            .loadOrders(),
                        child: ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 56,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No ${tab == "All" ? "" : tab.toLowerCase()} orders found.',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () => ref
                          .read(sellerOrdersProvider.notifier)
                          .loadOrders(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          final statusColor = _statusColor(order.orderStatus);
                          final dateStr =
                              DateFormat('MMM d, yyyy • h:mm a')
                                  .format(order.createdAt);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  context.push('/seller/orders/${order.id}'),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Order Header
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Order #${order.orderNumber}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(
                                                alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            order.orderStatus,
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
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const Divider(color: AppColors.border),
                                    const SizedBox(height: 4),

                                    // Customer Details
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline,
                                            size: 16,
                                            color: AppColors.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          order.customerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (order.customerPhone.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '• ${order.customerPhone}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (order.deliveryAddress.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 16,
                                              color: AppColors.textSecondary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              order.deliveryAddress,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 10),

                                    // Items preview
                                    ...order.items.take(2).map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 3),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${item.quantity}x ${item.productName}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Rs. ${item.totalPrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    if (order.items.length > 2)
                                      Text(
                                        '+${order.items.length - 2} more item(s)...',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    const Divider(color: AppColors.border),

                                    // Subtotal & Action Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Subtotal: Rs. ${order.subtotal.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            if (order.orderStatus.toUpperCase() ==
                                                'PENDING')
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.primary,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4),
                                                ),
                                                onPressed: () async {
                                                  final ok = await ref
                                                      .read(sellerOrdersProvider
                                                          .notifier)
                                                      .updateStatus(
                                                          order.id, 'RECEIVED');
                                                  if (ok && context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            'Order marked as Received'),
                                                        backgroundColor:
                                                            AppColors.success,
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                    Icons.check_circle_outline,
                                                    size: 16),
                                                label: const Text('Receive'),
                                              )
                                            else if (order.orderStatus
                                                    .toUpperCase() ==
                                                'RECEIVED')
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.success,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4),
                                                ),
                                                onPressed: () async {
                                                  final ok = await ref
                                                      .read(sellerOrdersProvider
                                                          .notifier)
                                                      .updateStatus(order.id,
                                                          'DELIVERED');
                                                  if (ok && context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            'Order marked as Delivered'),
                                                        backgroundColor:
                                                            AppColors.success,
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                    Icons.local_shipping_outlined,
                                                    size: 16),
                                                label: const Text('Deliver'),
                                              ),
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 18,
                                              color: AppColors.textSecondary,
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
                        },
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
