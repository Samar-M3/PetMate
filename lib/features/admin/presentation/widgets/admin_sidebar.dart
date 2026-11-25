import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminSidebarItem {
  final int index;
  final IconData icon;
  final String label;
  final int badgeCount;

  const AdminSidebarItem({
    required this.index,
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });
}

class AdminSidebarSection {
  final String title;
  final List<AdminSidebarItem> items;

  const AdminSidebarSection({required this.title, required this.items});
}

class AdminSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final int pendingApplicationsCount;
  final String adminName;
  final String adminEmail;
  final String? adminImageUrl;
  final VoidCallback onLogout;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const AdminSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    required this.pendingApplicationsCount,
    required this.adminName,
    required this.adminEmail,
    this.adminImageUrl,
    required this.onLogout,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  List<AdminSidebarSection> _buildSections() {
    return [
      const AdminSidebarSection(
        title: 'MAIN',
        items: [
          AdminSidebarItem(
            index: 0,
            icon: Icons.grid_view_rounded,
            label: 'Overview',
          ),
        ],
      ),
      AdminSidebarSection(
        title: 'MANAGEMENT',
        items: [
          const AdminSidebarItem(
            index: 1,
            icon: Icons.people_outline_rounded,
            label: 'User Management',
          ),
          AdminSidebarItem(
            index: 2,
            icon: Icons.verified_user_outlined,
            label: 'Role Applications',
            badgeCount: pendingApplicationsCount,
          ),
        ],
      ),
      const AdminSidebarSection(
        title: 'SERVICES & CLINIC',
        items: [
          AdminSidebarItem(
            index: 3,
            icon: Icons.medical_services_outlined,
            label: 'Veterinarians',
          ),
          AdminSidebarItem(
            index: 4,
            icon: Icons.calendar_today_outlined,
            label: 'Appointments',
          ),
          AdminSidebarItem(
            index: 5,
            icon: Icons.event_outlined,
            label: 'Community Events',
          ),
        ],
      ),
      const AdminSidebarSection(
        title: 'SYSTEM',
        items: [
          AdminSidebarItem(
            index: 6,
            icon: Icons.history_rounded,
            label: 'Audit Logs',
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections();

    return Container(
      width: isCollapsed ? 78 : 260,
      decoration: const BoxDecoration(
        color: AdminColors.sidebar,
        border: Border(
          right: BorderSide(color: AdminColors.border, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          // 1. Sidebar Brand Header
          _buildBrandHeader(),
          const Divider(height: 1, thickness: 1, color: AdminColors.border),

          // 2. Navigation Items List (Scrollable)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (final section in sections) ...[
                  if (!isCollapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 10),
                  for (final item in section.items) _buildNavItem(item),
                ],
              ],
            ),
          ),

          // 3. Admin Profile Footer & Logout
          const Divider(height: 1, thickness: 1, color: AdminColors.border),
          _buildProfileFooter(context),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 18),
      child: Row(
        mainAxisAlignment: isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminColors.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AdminColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 20),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PetMate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onToggleCollapse != null)
              IconButton(
                icon: const Icon(
                  Icons.menu_open_rounded,
                  size: 20,
                  color: AdminColors.textSecondary,
                ),
                tooltip: 'Collapse sidebar',
                onPressed: onToggleCollapse,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(AdminSidebarItem item) {
    final isSelected = currentIndex == item.index;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Tooltip(
          message: item.label,
          child: Material(
            color: isSelected
                ? AdminColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => onSelectTab(item.index),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Badge(
                  isLabelVisible: item.badgeCount > 0,
                  label: Text('${item.badgeCount}'),
                  backgroundColor: AdminColors.warning,
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: isSelected
                        ? AdminColors.primary
                        : AdminColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected
            ? AdminColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onSelectTab(item.index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? const Border(
                      left: BorderSide(color: AdminColors.primary, width: 3.0),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: isSelected
                      ? AdminColors.primary
                      : AdminColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? AdminColors.primary
                          : AdminColors.textPrimary,
                    ),
                  ),
                ),
                if (item.badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AdminColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AdminColors.warning.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${item.badgeCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AdminColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileFooter(BuildContext context) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: IconButton(
          icon: const Icon(
            Icons.logout_rounded,
            color: AdminColors.error,
            size: 20,
          ),
          tooltip: 'Sign Out',
          onPressed: onLogout,
        ),
      );
    }

    final initial = adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A';

    return Container(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AdminColors.primaryLight,
            backgroundImage: adminImageUrl != null && adminImageUrl!.isNotEmpty
                ? NetworkImage(adminImageUrl!)
                : null,
            child: (adminImageUrl == null || adminImageUrl!.isEmpty)
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: AdminColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  adminName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AdminColors.textPrimary,
                  ),
                ),
                Text(
                  adminEmail.isNotEmpty ? adminEmail : 'admin@petmate.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AdminColors.textSecondary,
              size: 18,
            ),
            tooltip: 'Sign Out',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
