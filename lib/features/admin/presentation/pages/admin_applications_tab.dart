import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/role_application_model.dart';
import '../providers/admin_provider.dart';
import '../theme/admin_colors.dart';

class AdminApplicationsTab extends ConsumerStatefulWidget {
  const AdminApplicationsTab({super.key});

  @override
  ConsumerState<AdminApplicationsTab> createState() =>
      _AdminApplicationsTabState();
}

class _AdminApplicationsTabState extends ConsumerState<AdminApplicationsTab> {
  final List<String> _statusOptions = ['PENDING', 'APPROVED', 'REJECTED'];
  final List<String> _typeOptions = ['ALL', 'SELLER', 'VETERINARIAN'];

  void _onStatusFilterSelected(String status) {
    ref
        .read(adminApplicationsProvider.notifier)
        .loadApplications(status: status);
  }

  void _onTypeFilterSelected(String type) {
    ref.read(adminApplicationsProvider.notifier).loadApplications(type: type);
  }

  Future<void> _promptApprove(RoleApplicationModel app) async {
    final typeName = app.type == 'SELLER' ? 'Seller' : 'Veterinarian';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Approve $typeName Application?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AdminColors.textPrimary,
          ),
        ),
        content: Text(
          'This will immediately update ${app.userFullName ?? app.userEmail}\'s role to ${app.type} and grant full portal privileges.',
          style: const TextStyle(
            fontSize: 13.5,
            color: AdminColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AdminColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(adminApplicationsProvider.notifier).approve(app.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$typeName application approved! User role updated.',
              ),
              backgroundColor: AdminColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve application: $e'),
              backgroundColor: AdminColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _promptReject(RoleApplicationModel app) async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reject Application?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AdminColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject this ${app.type.toLowerCase()} application? You can provide a reason for the applicant.',
              style: const TextStyle(
                fontSize: 13.5,
                color: AdminColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesController,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Reason for rejection (optional)...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AdminColors.textMuted,
                ),
                filled: true,
                fillColor: AdminColors.background,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AdminColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AdminColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Reject Application'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(adminApplicationsProvider.notifier)
            .reject(app.id, notes: notesController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application rejected.'),
              backgroundColor: AdminColors.warning,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject application: $e'),
              backgroundColor: AdminColors.error,
            ),
          );
        }
      }
    }
  }

  void _viewDocument(BuildContext context, String title, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: AdminColors.surface,
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: AdminColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AdminColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AdminColors.border),
              Expanded(
                child: Container(
                  color: AdminColors.background,
                  child: InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AdminColors.primary,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Text(
                                'Unable to load document preview.',
                                style: TextStyle(
                                  color: AdminColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminApplicationsProvider);

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          // Filter Toolbar
          _buildToolbar(state),

          // Applications Content
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildToolbar(AdminApplicationsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(
          bottom: BorderSide(color: AdminColors.border, width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Selector Tabs
          Row(
            children: _statusOptions.map((status) {
              final isSelected = state.statusFilter == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _onStatusFilterSelected(status),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getStatusBgColor(status)
                          : AdminColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? _getStatusColor(status)
                            : AdminColors.border,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? _getStatusColor(status)
                                : AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // Role Type Filter (All / Seller / Vet)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _typeOptions.map((type) {
                final isSelected = state.typeFilter == type;
                final label = type == 'ALL'
                    ? 'All Roles'
                    : (type == 'SELLER' ? 'Sellers' : 'Veterinarians');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _onTypeFilterSelected(type),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AdminColors.primaryLight
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? AdminColors.primary
                              : AdminColors.border,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? AdminColors.primaryDark
                              : AdminColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AdminApplicationsState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AdminColors.primary),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AdminColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AdminColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref
                    .read(adminApplicationsProvider.notifier)
                    .loadApplications(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AdminColors.border),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 36,
                color: AdminColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No ${state.statusFilter.toLowerCase()} applications',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'New role requests submitted by users will appear here.',
              style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AdminColors.primary,
      onRefresh: () async =>
          ref.read(adminApplicationsProvider.notifier).loadApplications(),
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: state.applications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final app = state.applications[index];
          return _buildApplicationCard(app);
        },
      ),
    );
  }

  Widget _buildApplicationCard(RoleApplicationModel app) {
    final isPending = app.status == 'PENDING';
    final isSeller = app.type == 'SELLER';
    final roleColor = isSeller ? AdminColors.info : AdminColors.success;
    final roleBg = isSeller ? AdminColors.infoLight : AdminColors.successLight;

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Applicant Profile + Role & Status
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: roleBg,
                  backgroundImage:
                      app.userImageUrl != null && app.userImageUrl!.isNotEmpty
                      ? NetworkImage(app.userImageUrl!)
                      : null,
                  child: (app.userImageUrl == null || app.userImageUrl!.isEmpty)
                      ? Text(
                          (app.userFullName ?? app.userEmail ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.userFullName ?? 'Applicant',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.userEmail ?? 'No email',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AdminColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roleBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isSeller ? 'Seller' : 'Veterinarian',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: roleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(app.status),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getStatusColor(app.status).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    app.status,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(app.status),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            thickness: 1,
            color: AdminColors.borderLight,
          ),

          // Business / Clinic Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSeller && app.storeName != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 16,
                        color: AdminColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.storeName!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AdminColors.textPrimary,
                              ),
                            ),
                            if (app.storeDescription != null &&
                                app.storeDescription!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                app.storeDescription!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AdminColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (app.businessType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AdminColors.background,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AdminColors.border),
                          ),
                          child: Text(
                            app.businessType == 'REGISTERED_BUSINESS'
                                ? 'Registered Business'
                                : 'Individual',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AdminColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else if (!isSeller && app.clinicName != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.local_hospital_outlined,
                        size: 16,
                        color: AdminColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          app.clinicName!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                      ),
                      if (app.licenseNumber != null)
                        Text(
                          'Lic: ${app.licenseNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],

                // Verification Documents
                if (_hasDocuments(app)) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'VERIFICATION DOCUMENTS',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (app.govIdUrl != null)
                        _buildDocChip(
                          'Government ID',
                          Icons.badge_outlined,
                          () => _viewDocument(
                            context,
                            'Government ID',
                            app.govIdUrl!,
                          ),
                        ),
                      if (app.taxDocumentUrl != null)
                        _buildDocChip(
                          'Tax Document',
                          Icons.receipt_long_outlined,
                          () => _viewDocument(
                            context,
                            'Tax Document',
                            app.taxDocumentUrl!,
                          ),
                        ),
                      if (app.medicalLicenseUrl != null)
                        _buildDocChip(
                          'Medical License',
                          Icons.verified_outlined,
                          () => _viewDocument(
                            context,
                            'Medical License',
                            app.medicalLicenseUrl!,
                          ),
                        ),
                    ],
                  ),
                ],

                // Rejection Notes if any
                if (app.adminNotes != null && app.adminNotes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminColors.warningLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AdminColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AdminColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin note: ${app.adminNotes}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AdminColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bottom Action Bar (if PENDING)
          if (isPending) ...[
            const Divider(
              height: 1,
              thickness: 1,
              color: AdminColors.borderLight,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _promptReject(app),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AdminColors.error,
                    ),
                    label: const Text(
                      'Reject',
                      style: TextStyle(color: AdminColors.error, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AdminColors.errorLight),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _promptApprove(app),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text(
                      'Approve',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  bool _hasDocuments(RoleApplicationModel app) {
    return app.govIdUrl != null ||
        app.taxDocumentUrl != null ||
        app.medicalLicenseUrl != null;
  }

  Widget _buildDocChip(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AdminColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AdminColors.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.open_in_new_rounded,
              size: 12,
              color: AdminColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AdminColors.success;
      case 'REJECTED':
        return AdminColors.error;
      case 'PENDING':
      default:
        return AdminColors.warning;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AdminColors.successLight;
      case 'REJECTED':
        return AdminColors.errorLight;
      case 'PENDING':
      default:
        return AdminColors.warningLight;
    }
  }
}
