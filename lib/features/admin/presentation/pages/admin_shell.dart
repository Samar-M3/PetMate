import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_applications_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_users_tab.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _currentIndex = 0;

  static const _navItems = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.people_alt_rounded, 'Users'),
    _NavItem(Icons.assignment_turned_in_rounded, 'Applications'),
  ];

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context); // close drawer
  }

  void _navigateBackToDashboard() {
    setState(() => _currentIndex = 0);
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out?'),
        content: const Text(
          'Are you sure you want to log out from the Admin Panel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  void _refreshAll() {
    ref.read(adminStatsProvider.notifier).refresh();
    ref.read(adminUsersProvider.notifier).loadUsers();
    ref.read(adminApplicationsProvider.notifier).loadApplications();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminStatsProvider);
    final pendingCount = statsAsync.value?.pendingApplications ?? 0;
    final user = ref.watch(authStateProvider).user;
    final profileName = user?.profile?.fullName ?? 'Admin';
    final profileImage = user?.profile?.effectiveImageUrl;
    final isSubTab = _currentIndex != 0;

    return PopScope(
      canPop: !isSubTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSubTab) {
          _navigateBackToDashboard();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          leading: isSubTab
              ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                  ),
                  tooltip: 'Back to Dashboard',
                  onPressed: _navigateBackToDashboard,
                )
              : Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: AppColors.textPrimary,
                    ),
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
          title: Text(
            _navItems[_currentIndex].label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Refresh',
              onPressed: _refreshAll,
            ),
            IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Log Out',
              onPressed: _handleLogout,
            ),
          ],
        ),
        drawer: _AdminDrawer(
          currentIndex: _currentIndex,
          pendingCount: pendingCount,
          userName: profileName,
          userEmail: user?.email ?? '',
          userImageUrl: profileImage,
          onTabSelected: _onTabSelected,
          onLogout: _handleLogout,
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            AdminDashboardTab(
              onNavigateToUsers: () => setState(() => _currentIndex = 1),
              onNavigateToApplications: () =>
                  setState(() => _currentIndex = 2),
            ),
            const AdminUsersTab(),
            const AdminApplicationsTab(),
          ],
        ),
      ),
    );
  }
}

// --- Private data class for nav items ---
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

// --- Sidebar Drawer Widget ---
class _AdminDrawer extends StatelessWidget {
  final int currentIndex;
  final int pendingCount;
  final String userName;
  final String userEmail;
  final String? userImageUrl;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onLogout;

  const _AdminDrawer({
    required this.currentIndex,
    required this.pendingCount,
    required this.userName,
    required this.userEmail,
    this.userImageUrl,
    required this.onTabSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header: logo + profile
            _buildHeader(),
            const Divider(height: 1, color: AppColors.border),

            const SizedBox(height: 12),
            // Section label
            _sectionLabel('NAVIGATION'),

            // Nav items
            _buildNavTile(0, Icons.dashboard_rounded, 'Dashboard'),
            _buildNavTile(1, Icons.people_alt_rounded, 'Users'),
            _buildNavTile(
              2,
              Icons.assignment_turned_in_rounded,
              'Applications',
              badgeCount: pendingCount,
            ),

            const Spacer(),
            const Divider(height: 1, color: AppColors.border),
            // Logout
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryDark,
            backgroundImage: userImageUrl != null && userImageUrl!.isNotEmpty
                ? NetworkImage(userImageUrl!)
                : null,
            child: (userImageUrl == null || userImageUrl!.isEmpty)
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Administrator',
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildNavTile(
    int index,
    IconData icon,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
        leading: Badge(
          isLabelVisible: badgeCount > 0,
          label: Text(badgeCount.toString()),
          backgroundColor: AppColors.warning,
          child: Icon(
            icon,
            color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
        onTap: () => onTabSelected(index),
      ),
    );
  }
}
