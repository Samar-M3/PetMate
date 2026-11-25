import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/shop_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_widgets.dart';

class ShopCheckoutPage extends ConsumerStatefulWidget {
  const ShopCheckoutPage({super.key});

  @override
  ConsumerState<ShopCheckoutPage> createState() => _ShopCheckoutPageState();
}

class _ShopCheckoutPageState extends ConsumerState<ShopCheckoutPage> {
  String? _selectedAddressId;
  String _paymentMethod = 'CASH_ON_DELIVERY';
  String _deliveryMethod = 'STANDARD';
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(shopAddressesProvider.notifier).load();
      await ref.read(shopCartProvider.notifier).load();
      final addresses = ref.read(shopAddressesProvider).items;
      if (addresses.isNotEmpty) {
        final def = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        setState(() => _selectedAddressId = def.id);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showAddAddressDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addr1Ctrl = TextEditingController();
    final addr2Ctrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Kathmandu');
    final provinceCtrl = TextEditingController(text: 'Bagmati Province');
    final postalCtrl = TextEditingController();
    bool isDefault = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Delivery Address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addr1Ctrl,
                    decoration: InputDecoration(
                      labelText: 'Street Address / Landmark *',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Street address is required' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityCtrl,
                          decoration: InputDecoration(
                            labelText: 'City *',
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'City is required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: provinceCtrl,
                          decoration: InputDecoration(
                            labelText: 'Province *',
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Province is required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: postalCtrl,
                    decoration: InputDecoration(
                      labelText: 'Postal Code (Optional)',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text('Set as default delivery address', style: TextStyle(fontSize: 13)),
                    value: isDefault,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setSheetState(() => isDefault = val ?? false),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final addr = ShopAddress(
                        id: '',
                        fullName: nameCtrl.text.trim(),
                        phoneNumber: phoneCtrl.text.trim(),
                        addressLine1: addr1Ctrl.text.trim(),
                        addressLine2: addr2Ctrl.text.trim().isEmpty ? null : addr2Ctrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        province: provinceCtrl.text.trim(),
                        postalCode: postalCtrl.text.trim().isEmpty ? null : postalCtrl.text.trim(),
                        isDefault: isDefault,
                      );
                      final created = await ref.read(shopAddressesProvider.notifier).add(addr);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (created != null) {
                        setState(() => _selectedAddressId = created.id);
                      }
                    },
                    child: const Text('Save Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a delivery address.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final order = await ref.read(shopOrdersProvider.notifier).placeOrder(
          deliveryAddressId: _selectedAddressId!,
          paymentMethod: _paymentMethod,
          customerNotes: _notesController.text.trim(),
        );

    if (mounted) {
      if (order != null) {
        // Show success modal then navigate to orders
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Confirmed!',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thank you for your order!\nOrder #${order.orderNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/shop/orders/${order.id}');
                  },
                  child: const Text('View Order Details'),
                ),
              ],
            ),
          ),
        );
      } else {
        final err = ref.read(shopOrdersProvider).error ?? 'Failed to place order. Please check stock and try again.';
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

    final isStandardFree = _deliveryMethod == 'STANDARD' && cartState.subtotal >= 1500;
    final deliveryFee = _deliveryMethod == 'EXPRESS'
        ? 200
        : (isStandardFree ? 0 : 100);
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
                    const Icon(Icons.shopping_bag_outlined, size: 56, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    const Text('Your cart is empty. Please add items to checkout.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/shop'),
                      child: const Text('Browse Products'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: Delivery Address
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
                                Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Delivery Address',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _showAddAddressDialog,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add New'),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 8),
                        if (addressesState.items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Column(
                                children: [
                                  const Text(
                                    'No delivery addresses saved yet.',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _showAddAddressDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Address'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Column(
                            children: addressesState.items.map((addr) {
                              final isSelected = _selectedAddressId == addr.id;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.08)
                                      : AppColors.inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: RadioListTile<String>(
                                  value: addr.id,
                                  groupValue: _selectedAddressId,
                                  activeColor: AppColors.primary,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  title: Row(
                                    children: [
                                      Text(addr.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (addr.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('Default', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      Text(addr.formattedSummary, style: const TextStyle(fontSize: 12)),
                                      Text('Phone: ${addr.phoneNumber}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  onChanged: (val) => setState(() => _selectedAddressId = val),
                                ),
                              );
                            }).toList(),
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
                                Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Order Items',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              '${cartState.items.length} items',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 8),
                        ...cartState.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: ShopImage(
                                    url: item.product.images.firstOrNull,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'Qty: ${item.quantity} ${item.variant != null ? "• ${item.variant!.optionKey}" : ""}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatShopPrice(item.lineSubtotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Delivery Method
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
                            Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Delivery Method',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 8),
                        RadioListTile<String>(
                          value: 'STANDARD',
                          groupValue: _deliveryMethod,
                          activeColor: AppColors.primary,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Standard Delivery (2-3 Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                isStandardFree ? 'FREE' : 'Rs. 100',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isStandardFree ? AppColors.success : AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          subtitle: const Text('Regular safe doorstep courier shipping', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          onChanged: (val) => setState(() => _deliveryMethod = val!),
                        ),
                        RadioListTile<String>(
                          value: 'EXPRESS',
                          groupValue: _deliveryMethod,
                          activeColor: AppColors.primary,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          title: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Express Priority (Next Day)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Rs. 200', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark)),
                            ],
                          ),
                          subtitle: const Text('Fast priority dispatch for urgent pet supplies', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          onChanged: (val) => setState(() => _deliveryMethod = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 4: Payment Method
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
                            Icon(Icons.payment_outlined, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Payment Method',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 8),
                        RadioListTile<String>(
                          value: 'CASH_ON_DELIVERY',
                          groupValue: _paymentMethod,
                          activeColor: AppColors.primary,
                          title: const Text('Cash on Delivery (COD)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: const Text('Pay with cash or QR scan when your package arrives', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          onChanged: (val) => setState(() => _paymentMethod = val!),
                        ),
                        RadioListTile<String>(
                          value: 'ESEWA',
                          groupValue: _paymentMethod,
                          activeColor: AppColors.primary,
                          title: const Text('eSewa Mobile Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: const Text('Digital payment verified upon order placement', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          onChanged: (val) => setState(() => _paymentMethod = val!),
                        ),
                        RadioListTile<String>(
                          value: 'KHALTI',
                          groupValue: _paymentMethod,
                          activeColor: AppColors.primary,
                          title: const Text('Khalti Digital Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: const Text('Fast wallet checkout confirmation', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          onChanged: (val) => setState(() => _paymentMethod = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 4: Delivery Notes
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
                            Icon(Icons.notes_rounded, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Delivery Instructions (Optional)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'e.g. Call before delivery, leave with guard...',
                            filled: true,
                            fillColor: AppColors.inputFill,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 5: Order Breakdown
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
                            const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            Text(formatShopPrice(cartState.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _deliveryMethod == 'EXPRESS' ? 'Express Delivery' : 'Delivery Charge',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            Text(
                              deliveryFee == 0 ? 'FREE' : formatShopPrice(deliveryFee.toDouble()),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: deliveryFee == 0 ? AppColors.success : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (isStandardFree) ...[
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Delivery Discount', style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('-Rs. 100 (FREE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              formatShopPrice(total),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Place Order Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 1,
                    ),
                    onPressed: ordersState.isPlacingOrder ? null : _placeOrder,
                    child: ordersState.isPlacingOrder
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            'Confirm & Place Order (${formatShopPrice(total)})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
