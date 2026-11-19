import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/admin_provider.dart';
import '../widgets/stat_card.dart';

class AdminDashboardTab extends ConsumerWidget {
  final VoidCallback onNavigateToUsers;
  final VoidCallback onNavigateToApplications;

  const AdminDashboardTab({
    super.key,
    required this.onNavigateToUsers,
    required this.onNavigateToApplications,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, stack) => Center(
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
                'Failed to load admin stats',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                err.toString().replaceAll('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(adminStatsProvider.notifier).refresh(),
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
      ),
      data: (stats) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await ref.read(adminStatsProvider.notifier).refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Admin Overview',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Monitor platform metrics, verify seller/vet applications, and manage user accounts securely.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Top Stats Grid
                const Text(
                  'Key Platform Metrics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    StatCard(
                      title: 'Total Users',
                      value: stats.totalUsers.toString(),
                      icon: Icons.people_alt_rounded,
                      iconColor: AppColors.primaryDark,
                    ),
                    StatCard(
                      title: 'Total Pets',
                      value: stats.totalPets.toString(),
                      icon: Icons.pets_rounded,
                      iconColor: AppColors.terracotta,
                    ),
                    StatCard(
                      title: 'Pending Apps',
                      value: stats.pendingApplications.toString(),
                      icon: Icons.assignment_late_rounded,
                      iconColor: AppColors.warning,
                      subtitle: stats.pendingApplications > 0
                          ? 'Action required'
                          : 'Up to date',
                    ),
                    StatCard(
                      title: 'Total Orders',
                      value: stats.totalOrders.toString(),
                      icon: Icons.shopping_bag_rounded,
                      iconColor: AppColors.info,
                      subtitle: 'Marketplace',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // User Roles Breakdown
                const Text(
                  'User Base by Role',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                  child: Column(
                    children: [
                      _buildRoleRow(
                        title: 'Pet Owners',
                        count: stats.usersByRole['PET_OWNER'] ?? 0,
                        icon: Icons.favorite_rounded,
                        color: AppColors.terracotta,
                      ),
                      const Divider(height: 20),
                      _buildRoleRow(
                        title: 'Sellers',
                        count: stats.usersByRole['SELLER'] ?? 0,
                        icon: Icons.storefront_rounded,
                        color: AppColors.info,
                      ),
                      const Divider(height: 20),
                      _buildRoleRow(
                        title: 'Veterinarians',
                        count: stats.usersByRole['VETERINARIAN'] ?? 0,
                        icon: Icons.medical_services_rounded,
                        color: AppColors.success,
                      ),
                      const Divider(height: 20),
                      _buildRoleRow(
                        title: 'System Admins',
                        count: stats.usersByRole['ADMIN'] ?? 0,
                        icon: Icons.security_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onNavigateToUsers,
                        icon: const Icon(Icons.manage_accounts_rounded),
                        label: const Text('Manage Users'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onNavigateToApplications,
                        icon: const Icon(Icons.approval_rounded),
                        label: const Text('Review Apps'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.terracotta,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleRow({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
