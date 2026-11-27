import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../shop/presentation/widgets/shop_widgets.dart';
import '../../data/models/seller_order_model.dart';
import '../providers/seller_provider.dart';

class SellerOrderDetailPage extends ConsumerWidget {
  final String orderId;

  const SellerOrderDetailPage({super.key, required this.orderId});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(sellerOrderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Seller Order Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Error loading order: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(sellerOrderDetailProvider(orderId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (order) => _buildBody(context, ref, order),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, SellerCustomerOrder order) {
    final statusColor = _statusColor(order.orderStatus);
    final dateStr =
        DateFormat('MMMM d, yyyy • h:mm a').format(order.createdAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Banner Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        order.orderStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Placed on $dateStr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customer & Delivery Information Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_pin_circle_outlined,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Customer & Delivery Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.border),
                const SizedBox(height: 6),
                _infoRow(
                  icon: Icons.person_outline,
                  label: 'Customer Name',
                  value: order.customerName,
                ),
                const SizedBox(height: 8),
                _infoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone Number',
                  value: order.customerPhone.isNotEmpty
                      ? order.customerPhone
                      : 'Not provided',
                ),
                const SizedBox(height: 8),
                _infoRow(
                  icon: Icons.home_outlined,
                  label: 'Delivery Address',
                  value: order.deliveryAddress.isNotEmpty
                      ? order.deliveryAddress
                      : 'Not specified',
                ),
                if (order.landmark != null && order.landmark!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.near_me_outlined,
                    label: 'Landmark',
                    value: order.landmark!,
                  ),
                ],
                if (order.deliveryInstructions != null &&
                    order.deliveryInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.comment_outlined,
                    label: 'Instructions',
                    value: order.deliveryInstructions!,
                  ),
                ],
                const SizedBox(height: 8),
                _infoRow(
                  icon: Icons.payment_outlined,
                  label: 'Payment Method',
                  value:
                      '${order.paymentMethod ?? "COD"} (${order.paymentStatus ?? "UNPAID"})',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ordered Items Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Products to Fulfill',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${order.items.length} item(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.border),
                const SizedBox(height: 6),
                ...order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: ShopImage(
                            url: item.productImage,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (item.variantName != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Variant: ${item.variantName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                'Qty: ${item.quantity} × Rs. ${item.unitPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Rs. ${item.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Store Subtotal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs. ${order.subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Button: Update Order Status
          if (order.orderStatus.toUpperCase() == 'PENDING') ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final ok = await ref
                    .read(sellerOrdersProvider.notifier)
                    .updateStatus(order.id, 'RECEIVED');
                if (ok) {
                  ref.invalidate(sellerOrderDetailProvider(order.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order marked as Received'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Mark Order as Received',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ] else if (order.orderStatus.toUpperCase() == 'RECEIVED') ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final ok = await ref
                    .read(sellerOrdersProvider.notifier)
                    .updateStatus(order.id, 'DELIVERED');
                if (ok) {
                  ref.invalidate(sellerOrderDetailProvider(order.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order marked as Delivered'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text(
                'Mark Order as Delivered',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ] else if (order.orderStatus.toUpperCase() == 'DELIVERED') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: 8),
                  Text(
                    'This order has been completed & delivered.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
