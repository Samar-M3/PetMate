import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_widgets.dart';

class ShopCheckoutPage extends ConsumerStatefulWidget {
  const ShopCheckoutPage({super.key});

  @override
  ConsumerState<ShopCheckoutPage> createState() => _ShopCheckoutPageState();
}

class _ShopCheckoutPageState extends ConsumerState<ShopCheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _instructionsController = TextEditingController();

  String? _selectedSavedAddressId;
  String _paymentMethod = 'CASH_ON_DELIVERY';
  final String _deliveryMethod = 'STANDARD';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(shopCartProvider.notifier).load();
      await ref.read(shopAddressesProvider.notifier).load();

      // Prepopulate customer details from user profile
      final authState = ref.read(authStateProvider);
      final authUser = authState.user;
      final fbUser = authState.firebaseUser;

      final name = authUser?.profile?.fullName ?? fbUser?.displayName ?? '';
      final phone = authUser?.phoneNumber ?? fbUser?.phoneNumber ?? '';

      if (_nameController.text.isEmpty && name.isNotEmpty) {
        _nameController.text = name;
      }
      if (_phoneController.text.isEmpty && phone.isNotEmpty) {
        _phoneController.text = phone;
      }

      // Check default saved address if available
      final addresses = ref.read(shopAddressesProvider).items;
      if (addresses.isNotEmpty) {
        final def = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
        _applySavedAddress(def);
      }
    });
  }

  void _applySavedAddress(ShopAddress addr) {
    setState(() {
      _selectedSavedAddressId = addr.id;
      if (_nameController.text.isEmpty) _nameController.text = addr.fullName;
      if (_phoneController.text.isEmpty) _phoneController.text = addr.phoneNumber;
      _addressController.text = addr.formattedSummary;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required delivery fields.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final rand = Random().nextInt(9000) + 1000;
    final idempotencyKey =
        'PM_ORD_${DateTime.now().millisecondsSinceEpoch}_$rand';

    final order = await ref.read(shopOrdersProvider.notifier).placeOrder(
          deliveryAddressId: _selectedSavedAddressId,
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          deliveryAddress: _addressController.text.trim(),
          landmark: _landmarkController.text.trim().isEmpty
              ? null
              : _landmarkController.text.trim(),
          deliveryInstructions: _instructionsController.text.trim().isEmpty
              ? null
              : _instructionsController.text.trim(),
          idempotencyKey: idempotencyKey,
          paymentMethod: _paymentMethod,
          customerNotes: _instructionsController.text.trim().isEmpty
              ? null
              : _instructionsController.text.trim(),
        );

    if (mounted) {
      if (order != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Confirmed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thank you for your order!\nOrder ID: #${order.orderNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(formatShopPrice(order.totalAmount),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment Status',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(order.paymentStatus,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.terracotta)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/shop/orders/${order.id}');
                    },
                    child: const Text('View Order Details'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/shop');
                  },
                  child: const Text('Continue Shopping'),
                ),
              ],
            ),
          ),
        );
      } else {
        final err = ref.read(shopOrdersProvider).error ??
            'Failed to place order. Please check item stock and try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesState = ref.watch(shopAddressesProvider);
    final cartState = ref.watch(shopCartProvider);
    final ordersState = ref.watch(shopOrdersProvider);

    final isStandardFree =
        _deliveryMethod == 'STANDARD' && cartState.subtotal >= 1500;
    final deliveryFee =
        _deliveryMethod == 'EXPRESS' ? 200 : (isStandardFree ? 0 : 100);
    final total = cartState.subtotal + deliveryFee;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: cartState.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 56,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your cart is empty. Add products to proceed.',
                      style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => context.go('/shop'),
                      child: const Text('Browse Products'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Customer & Delivery Details
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
                              Icon(Icons.location_on_outlined,
                                  color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Delivery Information',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 8),

                          // Saved addresses shortcut chips
                          if (addressesState.items.isNotEmpty) ...[
                            const Text(
                              'Select from saved addresses:',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: addressesState.items.map((addr) {
                                final isSelected =
                                    _selectedSavedAddressId == addr.id;
                                return ChoiceChip(
                                  label: Text(
                                    addr.city.isNotEmpty ? addr.city : addr.fullName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: AppColors.inputFill,
                                  onSelected: (val) {
                                    if (val) _applySavedAddress(addr);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Full Name (Required)
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name *',
                              hintText: 'Enter your full name',
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              filled: true,
                              fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Full name is required'
                                    : null,
                          ),
                          const SizedBox(height: 12),

                          // Phone Number (Required)
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number *',
                              hintText: '98XXXXXXXX',
                              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                              filled: true,
                              fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Phone number is required';
                              }
                              if (val.trim().length < 7) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Delivery Address (Required)
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Delivery Address *',
                              hintText: 'Street address, House No, Area / Ward',
                              prefixIcon: const Icon(Icons.home_outlined, size: 20),
                              filled: true,
                              fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Delivery address is required'
                                    : null,
                          ),
                          const SizedBox(height: 12),

                          // Landmark (Optional)
                          TextFormField(
                            controller: _landmarkController,
                            decoration: InputDecoration(
                              labelText: 'Landmark (Optional)',
                              hintText: 'Nearby school, hospital, or temple',
                              prefixIcon: const Icon(Icons.near_me_outlined, size: 20),
                              filled: true,
                              fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Delivery Instructions (Optional)
                          TextFormField(
                            controller: _instructionsController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Delivery Instructions (Optional)',
                              hintText: 'e.g. Call upon arrival, leave with security...',
                              prefixIcon: const Icon(Icons.comment_outlined, size: 20),
                              filled: true,
                              fillColor: AppColors.inputFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Items in Order
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
                              const Row(
                                children: [
                                  Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Order Summary',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${cartState.items.length} items',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 8),
                          ...cartState.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: ShopImage(
                                      url: item.product.images.firstOrNull,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'Qty: ${item.quantity} × ${formatShopPrice(item.unitPrice)}${item.variant != null ? " • ${item.variant!.optionKey}" : ""}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatShopPrice(item.lineSubtotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Payment Method
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
                              Icon(
                                Icons.payment_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Payment',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 4),
                          RadioGroup<String>(
                            groupValue: _paymentMethod,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _paymentMethod = val);
                              }
                            },
                            child: const RadioListTile<String>(
                              value: 'CASH_ON_DELIVERY',
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Cash on Delivery (COD)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                'Pay when your order arrives at your doorstep. No advance online payment required.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 4: Price Breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                formatShopPrice(cartState.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Delivery Charge',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                deliveryFee == 0
                                    ? 'FREE'
                                    : formatShopPrice(deliveryFee.toDouble()),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: deliveryFee == 0
                                      ? AppColors.success
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (isStandardFree) ...[
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Free Delivery Threshold (Over Rs. 1500)',
                                    style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                Text('Applied',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppColors.success)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formatShopPrice(total),
                                style: const TextStyle(
                                  fontSize: 20,
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

                    // Place Order Primary Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 1,
                      ),
                      onPressed:
                          ordersState.isPlacingOrder ? null : _placeOrder,
                      child: ordersState.isPlacingOrder
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Place Order (${formatShopPrice(total)})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
