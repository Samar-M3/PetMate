import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/pets_activation_provider.dart';

class SlotsPurchasePage extends ConsumerStatefulWidget {
  const SlotsPurchasePage({super.key});

  @override
  ConsumerState<SlotsPurchasePage> createState() => _SlotsPurchasePageState();
}

class _SlotsPurchasePageState extends ConsumerState<SlotsPurchasePage> {
  int _quantity = 1;
  String _selectedGateway = 'esewa';
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(petsActivationProvider.notifier).loadSummary();
    });
  }

  Future<void> _handlePayment() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Connecting to $_selectedGateway sandbox gateway...';
    });

    try {
      final notifier = ref.read(petsActivationProvider.notifier);
      final checkoutResult = await notifier.checkout(
        quantity: _quantity,
        gateway: _selectedGateway,
      );

      final paymentId = checkoutResult['paymentId'] as String;
      final transactionId = checkoutResult['transactionId'] as String?;

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Verifying payment with server...';
      });

      // Poll/Simulate gateway verification
      await Future.delayed(const Duration(seconds: 2));

      final verifyResult = await notifier.verify(
        paymentId: paymentId,
        transactionId: transactionId,
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      final message =
          verifyResult['message'] as String? ?? 'Slots purchased successfully!';

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Text('Success!'),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: const Text(
                'Back to My Pets',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petsActivationProvider);
    final summary = state.summary;
    final unitPrice = summary?.pricePerSlotNpr ?? 500.0;
    final duration = summary?.slotDurationDays ?? 30;
    final available = summary?.availableSlotsToPurchase ?? 5;
    final totalAmount = unitPrice * _quantity;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text(
          'Get Extra Active Slots',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.terracotta, Color(0xFFE88A6E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.terracotta.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Boost Your Pet Visibility',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Activate multiple pets at the same time so other pet parents can find them simultaneously in discovery decks.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Rs. ${unitPrice.toStringAsFixed(0)} / slot for $duration days',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quantity Selector
            const Text(
              'Select Number of Slots',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_quantity slot${_quantity > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Up to $available available',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: _quantity < available
                            ? () => setState(() => _quantity++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Gateway Selection
            const Text(
              'Select Payment Gateway',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedGateway = 'esewa'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedGateway == 'esewa'
                              ? const Color(0xFF60BB46)
                              : AppColors.border,
                          width: _selectedGateway == 'esewa' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: const Color(0xFF60BB46),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'eSewa',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            'Sandbox/Digital',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedGateway = 'khalti'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedGateway == 'khalti'
                              ? const Color(0xFF5C2D91)
                              : AppColors.border,
                          width: _selectedGateway == 'khalti' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.payment,
                            color: const Color(0xFF5C2D91),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Khalti',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            'Sandbox/Digital',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Order Summary
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_quantity x Active Slot ($duration Days)'),
                      Text('Rs. ${totalAmount.toStringAsFixed(0)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Platform / Gateway Fee',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      Text(
                        'Rs. 0',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Rs. ${totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.terracotta,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Status or progress indicator
            if (_isProcessing) ...[
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.terracotta,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage ?? 'Processing payment...',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],

            // Pay Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isProcessing || available == 0
                  ? null
                  : _handlePayment,
              child: Text(
                available == 0
                    ? 'Maximum Slots Reached ($available)'
                    : 'Pay Rs. ${totalAmount.toStringAsFixed(0)} with ${_selectedGateway.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
