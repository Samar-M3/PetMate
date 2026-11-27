import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/pets_activation_provider.dart';

class SlotsPurchasePage extends ConsumerStatefulWidget {
  const SlotsPurchasePage({super.key, this.targetPetId});

  final String? targetPetId;

  @override
  ConsumerState<SlotsPurchasePage> createState() => _SlotsPurchasePageState();
}

class _SlotsPurchasePageState extends ConsumerState<SlotsPurchasePage> {
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
    var paymentVerified = false;
    setState(() {
      _isProcessing = true;
      _statusMessage =
          'Starting mock ${_selectedGateway.toUpperCase()} checkout...';
    });

    try {
      final notifier = ref.read(petsActivationProvider.notifier);
      final checkoutResult = await notifier.checkout(
        quantity: 1,
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
      paymentVerified = true;

      if (widget.targetPetId != null) {
        await notifier.toggleActivation(
          petId: widget.targetPetId!,
          active: true,
        );
      }

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });

      final message = widget.targetPetId == null
          ? (verifyResult['message'] as String? ??
                'Additional active pet slot purchased.')
          : 'Mock payment succeeded. Your selected pet is now active alongside your other pet for ${ref.read(petsActivationProvider).summary?.slotDurationDays ?? 30} days.';

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
            '${paymentVerified ? 'Payment succeeded, but pet activation failed' : 'Payment failed'}: ${e.toString().replaceAll('Exception: ', '')}',
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
    final unitPrice = summary?.pricePerSlotNpr ?? 100.0;
    final duration = summary?.slotDurationDays ?? 30;
    final available = summary?.availableSlotsToPurchase ?? 1;
    final totalAmount = unitPrice;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text(
          'Activate Two Pets',
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
                    'Keep two pet profiles visible in discovery at the same time. This extra active slot lasts for one month.',
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
                      'Rs. ${unitPrice.toStringAsFixed(0)} for $duration days',
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

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.pets, color: AppColors.terracotta),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'One additional active pet for $duration days',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('1 slot'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Gateway Selection
            const Text(
              'Select Payment Method',
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
                            'Mock payment',
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
                    onTap: () => setState(() => _selectedGateway = 'fonepay'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedGateway == 'fonepay'
                              ? const Color(0xFFED1C24)
                              : AppColors.border,
                          width: _selectedGateway == 'fonepay' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.payment,
                            color: const Color(0xFFED1C24),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Fonepay',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            'Mock payment',
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
                      Text('Second active pet ($duration days)'),
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
                    ? 'Two-pet plan already active'
                    : 'Mock pay Rs. ${totalAmount.toStringAsFixed(0)} with ${_selectedGateway.toUpperCase()}',
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
