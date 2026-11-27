import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/admin_user_model.dart';
import '../providers/admin_provider.dart';
import '../theme/admin_colors.dart';
import '../widgets/user_role_dialog.dart';

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
                  backgroundColor: AdminColors.success,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update role: $e'),
                  backgroundColor: AdminColors.error,
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
          backgroundColor: AdminColors.warning,
        ),
      );
      return;
    }

    final newStatus = !user.isActive;
    final actionText = newStatus ? 'Reactivate' : 'Suspend';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$actionText User Account?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AdminColors.textPrimary,
          ),
        ),
        content: Text(
          newStatus
              ? 'Are you sure you want to reactivate access for ${user.fullName ?? user.email}?'
              : 'Suspending this account will immediately revoke auth tokens and block API access.',
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
              backgroundColor: newStatus
                  ? AdminColors.success
                  : AdminColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
              backgroundColor: newStatus
                  ? AdminColors.success
                  : AdminColors.warning,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update user status: $e'),
              backgroundColor: AdminColors.error,
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

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          // Filter & Search Toolbar
          _buildToolbar(usersState),

          // Main Table / List Body
          Expanded(child: _buildBody(usersState, currentUserId)),
        ],
      ),
    );
  }

  Widget _buildToolbar(AdminUsersState usersState) {
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
          Row(
            children: [
              // Search Input
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _onSearchSubmitted,
                    onChanged: (val) {
                      setState(() {});
                      if (val.isEmpty) _onSearchSubmitted('');
                    },
                    style: const TextStyle(
                      fontSize: 13,
                      color: AdminColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by full name, email, or phone...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AdminColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AdminColors.textMuted,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              color: AdminColors.textMuted,
                              onPressed: () {
                                _searchController.clear();
                                _onSearchSubmitted('');
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AdminColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
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
                        borderSide: const BorderSide(
                          color: AdminColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Search Action Button
              ElevatedButton.icon(
                onPressed: () => _onSearchSubmitted(_searchController.text),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Role Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _roleOptions.map((role) {
                final isSelected = usersState.roleFilter == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _onRoleFilterSelected(role),
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AdminColors.primary
                            : AdminColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? AdminColors.primary
                              : AdminColors.border,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        _formatRoleName(role),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
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

  Widget _buildBody(AdminUsersState state, String currentUserId) {
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
                onPressed: () =>
                    ref.read(adminUsersProvider.notifier).loadUsers(),
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

    if (state.users.isEmpty) {
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
                Icons.people_outline_rounded,
                size: 36,
                color: AdminColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No users found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search terms or filter criteria.',
              style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 850;

        return RefreshIndicator(
          color: AdminColors.primary,
          onRefresh: () async =>
              ref.read(adminUsersProvider.notifier).loadUsers(),
          child: isWideScreen
              ? _buildDataTable(state.users, currentUserId)
              : _buildCardList(state.users, currentUserId),
        );
      },
    );
  }

  // Desktop Data Table View
  Widget _buildDataTable(List<AdminUserModel> users, String currentUserId) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Table Header
            Container(
              color: AdminColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'USER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'ROLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'PETS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'JOINED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: Text(
                      'ACTIONS',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AdminColors.border),

            // Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AdminColors.borderLight,
              ),
              itemBuilder: (context, index) {
                final user = users[index];
                final isMe = user.id == currentUserId;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // User Column (Avatar + Name + Email)
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: AdminColors.primaryLight,
                              backgroundImage:
                                  user.imageUrl != null &&
                                      user.imageUrl!.isNotEmpty
                                  ? NetworkImage(user.imageUrl!)
                                  : null,
                              child:
                                  (user.imageUrl == null ||
                                      user.imageUrl!.isEmpty)
                                  ? Text(
                                      (user.fullName ?? user.email ?? 'U')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AdminColors.primaryDark,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
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
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: AdminColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AdminColors.primaryLight,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'YOU',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: AdminColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email ??
                                        user.phoneNumber ??
                                        'No contact',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Role Column
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildRoleBadge(user.role),
                        ),
                      ),

                      // Pets Column
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${user.petsCount}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                      ),

                      // Status Column
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStatusPill(user.isActive),
                        ),
                      ),

                      // Joined Date Column
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatDate(user.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ),

                      // Actions Column
                      SizedBox(
                        width: 140,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  _promptRoleChange(user, currentUserId),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AdminColors.border,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(56, 30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                'Role',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AdminColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                user.isActive
                                    ? Icons.block_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 18,
                                color: user.isActive
                                    ? AdminColors.error
                                    : AdminColors.success,
                              ),
                              tooltip: user.isActive
                                  ? 'Suspend User'
                                  : 'Reactivate User',
                              onPressed: () =>
                                  _promptStatusToggle(user, currentUserId),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Mobile / Narrow Card View
  Widget _buildCardList(List<AdminUserModel> users, String currentUserId) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        final isMe = user.id == currentUserId;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AdminColors.primaryLight,
                    backgroundImage:
                        user.imageUrl != null && user.imageUrl!.isNotEmpty
                        ? NetworkImage(user.imageUrl!)
                        : null,
                    child: (user.imageUrl == null || user.imageUrl!.isEmpty)
                        ? Text(
                            (user.fullName ?? user.email ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.primaryDark,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
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
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: AdminColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AdminColors.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email ?? user.phoneNumber ?? 'No contact',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusPill(user.isActive),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(
                height: 1,
                thickness: 1,
                color: AdminColors.borderLight,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildRoleBadge(user.role),
                      const SizedBox(width: 8),
                      Text(
                        '${user.petsCount} pet${user.petsCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => _promptRoleChange(user, currentUserId),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AdminColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Role',
                          style: TextStyle(
                            fontSize: 12,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          user.isActive
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: user.isActive
                              ? AdminColors.error
                              : AdminColors.success,
                        ),
                        tooltip: user.isActive ? 'Suspend' : 'Reactivate',
                        onPressed: () =>
                            _promptStatusToggle(user, currentUserId),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg;
    Color fg;

    switch (role) {
      case 'ADMIN':
        bg = AdminColors.purpleLight;
        fg = AdminColors.purple;
        break;
      case 'VETERINARIAN':
        bg = AdminColors.successLight;
        fg = AdminColors.success;
        break;
      case 'SELLER':
        bg = AdminColors.infoLight;
        fg = AdminColors.info;
        break;
      case 'PET_OWNER':
      default:
        bg = AdminColors.background;
        fg = AdminColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Text(
        _formatRoleName(role),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildStatusPill(bool isActive) {
    final color = isActive ? AdminColors.success : AdminColors.error;
    final bg = isActive ? AdminColors.successLight : AdminColors.errorLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Suspended',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
