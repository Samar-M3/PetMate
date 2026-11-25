import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/admin_provider.dart';

import 'package:petmatee/features/care_events/providers/care_events_provider.dart'
    show appointmentsProvider, careEventsProvider, careVetsProvider;

import '../theme/admin_colors.dart';
import '../widgets/admin_header.dart';
import '../widgets/admin_sidebar.dart';
import 'admin_applications_tab.dart';
import 'admin_appointments_tab.dart';
import 'admin_audit_logs_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_events_tab.dart';
import 'admin_users_tab.dart';
import 'admin_vets_tab.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop(); // close mobile drawer
    }
  }

  void _navigateToUsers() {
    _onTabSelected(1);
  }

  void _navigateToApplications() {
    _onTabSelected(2);
  }

  void _navigateToVets() {
    _onTabSelected(3);
  }

  void _navigateToAppointments() {
    _onTabSelected(4);
  }

  void _navigateToEvents() {
    _onTabSelected(5);
  }

  void _navigateBackToDashboard() {
    setState(() => _currentIndex = 0);
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out of Admin Portal?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AdminColors.textPrimary,
          ),
        ),
        content: const Text(
          'Your active administrative session will end and tokens will be cleared.',
          style: TextStyle(
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
              backgroundColor: AdminColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  void _refreshCurrentTab() {
    ref.read(adminStatsProvider.notifier).refresh();
    switch (_currentIndex) {
      case 0:
        ref.read(adminUsersProvider.notifier).loadUsers();
        ref.read(adminApplicationsProvider.notifier).loadApplications();
        break;
      case 1:
        ref.read(adminUsersProvider.notifier).loadUsers();
        break;
      case 2:
        ref.read(adminApplicationsProvider.notifier).loadApplications();
        break;
      case 3:
        ref.read(careVetsProvider.notifier).refresh();
        break;
      case 4:
        ref.read(appointmentsProvider.notifier).refresh();
        break;
      case 5:
        ref.invalidate(careEventsProvider);
        break;
      case 6:
        ref.read(adminAuditLogsProvider.notifier).refresh();
        break;
    }
  }

  (String, String, String) _getTabMetadata(int index) {
    switch (index) {
      case 0:
        return (
          'Dashboard Overview',
          'Real-time metrics, platform usage and pending approval queues',
          'Admin / Overview',
        );
      case 1:
        return (
          'User Management',
          'Browse, search, edit roles and manage account access',
          'Admin / Management / Users',
        );
      case 2:
        return (
          'Role Applications',
          'Review and approve pending seller and veterinarian applications',
          'Admin / Management / Role Applications',
        );
      case 3:
        return (
          'Veterinarians',
          'Manage verified veterinary doctors, clinics and consultation fees',
          'Admin / Services & Clinic / Veterinarians',
        );
      case 4:
        return (
          'Appointments',
          'Track upcoming, completed and cancelled clinical appointments',
          'Admin / Services & Clinic / Appointments',
        );
      case 5:
        return (
          'Community Events',
          'Publish and monitor official PetMate community gatherings',
          'Admin / Services & Clinic / Events',
        );
      case 6:
        return (
          'Security Audit Logs',
          'Immutable audit trail of administrative and security actions',
          'Admin / System / Audit Logs',
        );
      default:
        return ('Admin Portal', '', 'Admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminStatsProvider);
    final pendingCount = statsAsync.value?.pendingApplications ?? 0;
    final user = ref.watch(authStateProvider).user;
    final profileName = user?.profile?.fullName ?? 'Admin';
    final userEmail = user?.email ?? 'admin@petmate.app';
    final profileImage = user?.profile?.effectiveImageUrl;
    final isSubTab = _currentIndex != 0;

    final (title, subtitle, breadcrumb) = _getTabMetadata(_currentIndex);

    return PopScope(
      canPop: !isSubTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSubTab) {
          _navigateBackToDashboard();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          final sidebar = AdminSidebar(
            currentIndex: _currentIndex,
            onSelectTab: _onTabSelected,
            pendingApplicationsCount: pendingCount,
            adminName: profileName,
            adminEmail: userEmail,
            adminImageUrl: profileImage,
            onLogout: _handleLogout,
            isCollapsed: isDesktop && _isSidebarCollapsed,
            onToggleCollapse: isDesktop
                ? () =>
                      setState(() => _isSidebarCollapsed = !_isSidebarCollapsed)
                : null,
          );

          final pages = [
            AdminDashboardTab(
              onNavigateToUsers: _navigateToUsers,
              onNavigateToApplications: _navigateToApplications,
              onNavigateToVets: _navigateToVets,
              onNavigateToAppointments: _navigateToAppointments,
              onNavigateToEvents: _navigateToEvents,
            ),
            const AdminUsersTab(),
            const AdminApplicationsTab(),
            const AdminVetsTab(),
            const AdminAppointmentsTab(),
            const AdminEventsTab(),
            const AdminAuditLogsTab(),
          ];

          if (isDesktop) {
            // Fixed Desktop 2-column layout (Left Sidebar + Right Scrollable Content)
            return Scaffold(
              backgroundColor: AdminColors.background,
              body: Row(
                children: [
                  sidebar,
                  Expanded(
                    child: Column(
                      children: [
                        AdminHeader(
                          title: title,
                          subtitle: subtitle,
                          breadcrumb: breadcrumb,
                          onRefresh: _refreshCurrentTab,
                          showMenuButton: false,
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _currentIndex,
                            children: List.generate(
                              pages.length,
                              (i) => _visitedTabs.contains(i)
                                  ? pages[i]
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Mobile / Tablet layout with collapsible Drawer
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: AdminColors.background,
            drawer: Drawer(
              width: 280,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: sidebar,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  AdminHeader(
                    title: title,
                    subtitle: subtitle,
                    breadcrumb: breadcrumb,
                    onRefresh: _refreshCurrentTab,
                    showMenuButton: true,
                    onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: List.generate(
                        pages.length,
                        (i) => _visitedTabs.contains(i)
                            ? pages[i]
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
