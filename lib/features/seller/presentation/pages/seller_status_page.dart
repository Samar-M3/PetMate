import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/seller_application_model.dart';
import '../providers/seller_provider.dart';

class SellerStatusPage extends ConsumerStatefulWidget {
  const SellerStatusPage({super.key});

  @override
  ConsumerState<SellerStatusPage> createState() => _SellerStatusPageState();
}

class _SellerStatusPageState extends ConsumerState<SellerStatusPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerProvider.notifier).loadSellerStatus();
    });
  }

  void _openResubmitDialog(SellerStoreModel store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResubmitApplicationSheet(store: store),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sellerState = ref.watch(sellerProvider);
    final status = sellerState.statusResponse;
    final store = status?.store;
    final appStatus = status?.applicationStatus ?? 'PENDING';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text(
          'Application Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            tooltip: 'Refresh Status',
            onPressed: () {
              ref.read(sellerProvider.notifier).loadSellerStatus();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: 'Log Out',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: sellerState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.terracotta),
            )
          : RefreshIndicator(
              color: AppColors.terracotta,
              onRefresh: () async {
                await ref.read(sellerProvider.notifier).loadSellerStatus();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status Card (Pending / Approved / Rejected / Suspended)
                        _buildStatusHeader(appStatus, store),
                        const SizedBox(height: 16),

                        // Store & Applicant Information Card
                        if (store != null)
                          _buildStoreDetailsCard(status!, store),

                        const SizedBox(height: 16),

                        // Application Progress Timeline
                        _buildProgressTimeline(appStatus),

                        const SizedBox(height: 20),

                        // Action Buttons based on status
                        if (appStatus == 'APPROVED')
                          ElevatedButton.icon(
                            onPressed: () => context.go('/seller'),
                            icon: const Icon(Icons.dashboard_rounded),
                            label: const Text(
                              'Open Seller Dashboard',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        else if (appStatus == 'REJECTED' && store != null)
                          ElevatedButton.icon(
                            onPressed: () => _openResubmitDialog(store),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text(
                              'Resubmit Application for Review',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.terracotta,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => context.go('/'),
                            icon: const Icon(
                              Icons.storefront_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            label: const Text(
                              'Explore PetMate Marketplace',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatusHeader(String appStatus, SellerStoreModel? store) {
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusDescription;

    switch (appStatus) {
      case 'APPROVED':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusTitle = 'Seller Application Approved!';
        statusDescription =
            'Congratulations! Your seller application has been approved by the PetMate administrative team. You now have full access to create product listings, manage inventory, and process customer orders.';
        break;
      case 'REJECTED':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        statusTitle = 'Application Requires Revision';
        statusDescription =
            'Your application could not be approved in its current form. Please review the admin feedback below, update your details or documentation, and resubmit for review.';
        break;
      case 'SUSPENDED':
        statusColor = AppColors.error;
        statusIcon = Icons.warning_rounded;
        statusTitle = 'Seller Store Suspended';
        statusDescription =
            'This seller account is temporarily suspended. For inquiries or appeals, please contact our support desk at sellers@petmate.com.';
        break;
      case 'PENDING':
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.access_time_rounded;
        statusTitle = 'Application Under Review';
        statusDescription =
            'Thank you for applying to sell on PetMate! Our verification team is actively reviewing your store details and documents. Approvals typically take 24–48 business hours.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        appStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            statusDescription,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (appStatus == 'REJECTED' &&
              store?.rejectionReason != null &&
              store!.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.error,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Reason for Rejection:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    store.rejectionReason!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreDetailsCard(
    SellerStatusResponseModel status,
    SellerStoreModel store,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.badge_outlined,
                size: 20,
                color: AppColors.terracotta,
              ),
              SizedBox(width: 8),
              Text(
                'Submitted Store Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          _buildInfoRow('Store Name', store.name),
          _buildInfoRow('Seller Name', status.sellerName ?? 'N/A'),
          _buildInfoRow('Contact Email', status.email ?? 'N/A'),
          if (status.phoneNumber != null)
            _buildInfoRow('Phone Number', status.phoneNumber!),
          _buildInfoRow('Business Type', store.businessTypeLabel),
          if (store.businessAddress != null)
            _buildInfoRow(
              'Address',
              '${store.businessAddress}, ${store.city ?? ""}, ${store.province ?? ""}',
            ),
          if (store.submittedAt != null)
            _buildInfoRow(
              'Submission Date',
              '${store.submittedAt!.day}/${store.submittedAt!.month}/${store.submittedAt!.year}',
            ),
          if (store.reviewedAt != null)
            _buildInfoRow(
              'Reviewed Date',
              '${store.reviewedAt!.day}/${store.reviewedAt!.month}/${store.reviewedAt!.year}',
            ),
          if (store.registrationDocUrl != null &&
              store.registrationDocUrl!.isNotEmpty)
            _buildDocRow('Registration Document', 'Attached'),
          if (store.identityDocUrl != null && store.identityDocUrl!.isNotEmpty)
            _buildDocRow('Identity Document', 'Attached'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 13,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline(String appStatus) {
    final step1Done = true;
    final step2Done = appStatus == 'APPROVED' || appStatus == 'REJECTED';
    final step3Done = appStatus == 'APPROVED';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verification Timeline',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTimelineStep(
            number: '1',
            title: 'Application Submitted',
            description: 'Your business details and documents were received.',
            isComplete: step1Done,
            isActive: !step2Done,
          ),
          _buildTimelineStep(
            number: '2',
            title: 'Admin Document Verification',
            description:
                'Our team checks store registration and verification documents.',
            isComplete: step2Done,
            isActive: !step2Done,
          ),
          _buildTimelineStep(
            number: '3',
            title: 'Store Portal Activation',
            description:
                'Once approved, product catalog tools and order manager open.',
            isComplete: step3Done,
            isActive: false,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String number,
    required String title,
    required String description,
    required bool isComplete,
    required bool isActive,
    bool isLast = false,
  }) {
    Color iconBg = isComplete
        ? AppColors.success
        : (isActive ? AppColors.warning : AppColors.border);
    Color iconColor = isComplete || isActive ? Colors.white : AppColors.textMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isComplete
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        number,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isComplete ? AppColors.success : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isComplete || isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (!isLast) const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResubmitApplicationSheet extends ConsumerStatefulWidget {
  final SellerStoreModel store;

  const _ResubmitApplicationSheet({required this.store});

  @override
  ConsumerState<_ResubmitApplicationSheet> createState() =>
      _ResubmitApplicationSheetState();
}

class _ResubmitApplicationSheetState
    extends ConsumerState<_ResubmitApplicationSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _storeNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _postalCodeController;
  late String _businessType;

  String? _registrationDocUrl;
  String? _identityDocUrl;
  bool _isUploadingDoc = false;
  bool _isPickingDoc = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController(text: widget.store.name);
    _descriptionController =
        TextEditingController(text: widget.store.description ?? '');
    _addressController =
        TextEditingController(text: widget.store.businessAddress ?? '');
    _cityController = TextEditingController(text: widget.store.city ?? '');
    _provinceController =
        TextEditingController(text: widget.store.province ?? 'Bagmati Province');
    _postalCodeController =
        TextEditingController(text: widget.store.postalCode ?? '');
    _businessType = widget.store.businessType;
    _registrationDocUrl = widget.store.registrationDocUrl;
    _identityDocUrl = widget.store.identityDocUrl;
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(bool isRegDoc) async {
    if (_isPickingDoc) return;
    _isPickingDoc = true;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      File? file;
      if (!kIsWeb) {
        file = File(picked.path);
      }

      setState(() => _isUploadingDoc = true);

      final cloudinary = ref.read(cloudinaryServiceProvider);
      final url = await cloudinary.uploadSellerDocument(
        file,
        bytes: bytes,
        filename: picked.name,
      );

      if (mounted) {
        setState(() {
          _isUploadingDoc = false;
          if (isRegDoc) {
            _registrationDocUrl = url;
          } else {
            _identityDocUrl = url;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingDoc = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _isPickingDoc = false;
    }
  }

  Future<void> _submitResubmission() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'storeName': _storeNameController.text.trim(),
      'businessType': _businessType,
      'description': _descriptionController.text.trim(),
      'businessAddress': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'province': _provinceController.text.trim(),
      'postalCode': _postalCodeController.text.trim(),
      if (_registrationDocUrl != null)
        'registrationDocUrl': _registrationDocUrl,
      if (_identityDocUrl != null) 'identityDocUrl': _identityDocUrl,
    };

    final success =
        await ref.read(sellerProvider.notifier).resubmitApplication(data);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Application resubmitted successfully! It is now pending review.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final err = ref.read(sellerProvider).errorMessage ??
            'Resubmission failed. Please check your data.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(sellerProvider).isResubmitting;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Update Application',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _storeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Store Name *',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Business Address *',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _provinceController,
                      decoration: const InputDecoration(
                        labelText: 'Province *',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Store Description',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Documents',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: AppColors.terracotta,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Business Registration Document',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _registrationDocUrl != null
                                      ? 'Attached'
                                      : 'Not attached',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _registrationDocUrl != null
                                        ? AppColors.success
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _pickAndUpload(true),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            color: AppColors.terracotta,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Identity Document',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _identityDocUrl != null
                                      ? 'Attached'
                                      : 'Not attached',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _identityDocUrl != null
                                        ? AppColors.success
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _pickAndUpload(false),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (isSubmitting || _isUploadingDoc)
                                ? null
                                : _submitResubmission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.terracotta,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Resubmit Application',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
