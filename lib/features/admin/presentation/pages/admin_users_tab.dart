import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/admin_user_model.dart';
import '../providers/admin_provider.dart';
import '../widgets/user_role_dialog.dart';
import 'package:petmatee/features/care_events/models/vet_model.dart';
import 'package:petmatee/features/care_events/providers/care_events_provider.dart';

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _roleOptions = [
    'ALL',
    'PET_OWNER',
    'SELLER',
    'VETERINARIAN',
    'ADMIN',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String val) {
    ref.read(adminUsersProvider.notifier).loadUsers(search: val);
  }

  void _onRoleFilterSelected(String role) {
    ref.read(adminUsersProvider.notifier).loadUsers(roleFilter: role);
  }

  Future<void> _promptRoleChange(
    AdminUserModel user,
    String currentAdminId,
  ) async {
    final isCurrent = user.id == currentAdminId;
    await showDialog(
      context: context,
      builder: (ctx) => UserRoleDialog(
        user: user,
        isCurrentUser: isCurrent,
        onRoleSelected: (newRole) async {
          try {
            await ref
                .read(adminUsersProvider.notifier)
                .changeRole(user.id, newRole);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('User role updated to $newRole'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update role: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _promptStatusToggle(
    AdminUserModel user,
    String currentAdminId,
  ) async {
    if (user.id == currentAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot deactivate your own admin account'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final newStatus = !user.isActive;
    final actionText = newStatus ? 'Reactivate' : 'Suspend';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$actionText User Account?'),
        content: Text(
          newStatus
              ? 'Are you sure you want to reactivate access for ${user.fullName ?? user.email}?'
              : 'Suspending this account will block all logins and API requests immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(adminUsersProvider.notifier)
            .toggleUserStatus(user.id, newStatus);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User ${newStatus ? "reactivated" : "suspended"} successfully',
              ),
              backgroundColor:
                  newStatus ? AppColors.success : AppColors.warning,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update user status: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(adminUsersProvider);
    final currentUserId = ref.watch(authStateProvider).user?.id ?? '';

    return Column(
      children: [
        // Top Search & Filter Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearchSubmitted,
                      onChanged: (val) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        prefixIcon: IconButton(
                          icon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                          ),
                          tooltip: 'Search',
                          onPressed: () =>
                              _onSearchSubmitted(_searchController.text),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchSubmitted('');
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Role Filter Chips
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _roleOptions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final role = _roleOptions[index];
                          final isSelected = usersState.roleFilter == role;
                          return ChoiceChip(
                            label: Text(_formatRoleName(role)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.inputFill,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            onSelected: (_) => _onRoleFilterSelected(role),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // User List Body
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: _buildUserList(usersState, currentUserId),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(AdminUsersState state, String currentUserId) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
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
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(adminUsersProvider.notifier).loadUsers(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.users.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async =>
            ref.read(adminUsersProvider.notifier).loadUsers(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.person_off_rounded,
                    size: 56,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No users found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Try adjusting your search or role filter.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.read(adminUsersProvider.notifier).loadUsers(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = state.users[index];
          return _buildUserCard(user, currentUserId);
        },
      ),
    );
  }

  Widget _buildUserCard(AdminUserModel user, String currentAdminId) {
    final isMe = user.id == currentAdminId;
    final roleColor = _getRoleBadgeColor(user.role);
    final isVetRecord = user.isVeterinarianRecord;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isVetRecord ? null : () => _promptRoleChange(user, currentAdminId),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: user.isActive
                  ? AppColors.border
                  : AppColors.error.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: roleColor.withValues(alpha: 0.15),
                    backgroundImage:
                        user.imageUrl != null && user.imageUrl!.isNotEmpty
                            ? NetworkImage(user.imageUrl!)
                            : null,
                    child: (user.imageUrl == null || user.imageUrl!.isEmpty)
                        ? Text(
                            (user.fullName ?? user.email ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: roleColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.fullName ?? 'Unnamed User',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVetRecord) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'VET RECORD',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ] else if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Show veterinarian-specific info for vet records
                        if (isVetRecord) ...[
                          if (user.clinicName != null) ...[
                            Text(
                              'Clinic: ${user.clinicName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (user.specialty != null) ...[
                            Text(
                              'Specialty: ${user.specialty}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (user.address != null) ...[
                            Text(
                              'Address: ${user.address}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (user.fee != null) ...[
                            Text(
                              'Fee: ₹${user.fee}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ] else ...[
                          Text(
                            user.email ?? user.phoneNumber ?? 'No contact info',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: user.isActive
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      user.isActive ? 'Active' : 'Suspended',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color:
                            user.isActive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Role, Pets count, and Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatRoleName(user.role),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVetRecord
                            ? '${user.isAcceptingBookings == true ? "Accepting bookings" : "Not accepting bookings"}'
                            : '${user.petsCount} pet${user.petsCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (!isVetRecord) ...[
                        OutlinedButton(
                          onPressed: () =>
                              _promptRoleChange(user, currentAdminId),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child:
                              const Text('Role', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            user.isActive
                                ? Icons.block_rounded
                                : Icons.check_circle_outline_rounded,
                            color: user.isActive
                                ? AppColors.error
                                : AppColors.success,
                            size: 20,
                          ),
                          tooltip: user.isActive ? 'Suspend' : 'Reactivate',
                          onPressed: () =>
                              _promptStatusToggle(user, currentAdminId),
                        ),
                      ] else ...[
                        // For vet records, show a button to edit in Manage Vets tab
                        OutlinedButton.icon(
                          onPressed: () {
                            // Navigate to Manage Vets tab
                            // This would need a callback or navigation
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Use "Manage Vets" tab to edit veterinarian details'),
                                backgroundColor: AppColors.info,
                              ),
                            );
                          },
                          icon: const Icon(Icons.medical_services_rounded, size: 16),
                          label: const Text('Manage Vets', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                            side: const BorderSide(color: AppColors.success),
                          ),
                        ),
                      ],
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

  String _formatRoleName(String role) {
    switch (role) {
      case 'PET_OWNER':
        return 'Pet Owner';
      case 'SELLER':
        return 'Seller';
      case 'VETERINARIAN':
        return 'Veterinarian';
      case 'ADMIN':
        return 'Admin';
      default:
        return role;
    }
  }

  Color _getRoleBadgeColor(String role) {
    switch (role) {
      case 'PET_OWNER':
        return AppColors.terracotta;
      case 'SELLER':
        return AppColors.info;
      case 'VETERINARIAN':
        return AppColors.success;
      case 'ADMIN':
        return AppColors.primaryDark;
      default:
        return AppColors.textSecondary;
    }
  }
}
