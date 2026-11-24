import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

class AdminHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String breadcrumb;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenDrawer;
  final bool showMenuButton;
  final List<Widget>? actions;

  const AdminHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.breadcrumb,
    required this.onRefresh,
    this.onOpenDrawer,
    this.showMenuButton = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(
          bottom: BorderSide(color: AdminColors.border, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Mobile Menu Drawer Button
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: AdminColors.textPrimary,
              ),
              tooltip: 'Open navigation',
              onPressed: onOpenDrawer,
            ),
            const SizedBox(width: 8),
          ],

          // Title & Breadcrumb Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      breadcrumb,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Actions on the Right
          if (actions != null) ...actions!,

          // Live System Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AdminColors.successLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AdminColors.success.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 7, color: AdminColors.success),
                SizedBox(width: 5),
                Text(
                  'Connected',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Refresh Button
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AdminColors.textSecondary,
              size: 20,
            ),
            tooltip: 'Refresh data',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}
