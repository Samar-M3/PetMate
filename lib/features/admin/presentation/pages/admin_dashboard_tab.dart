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
      error: (err, _) => _ErrorView(
        message: err.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.read(adminStatsProvider.notifier).refresh(),
      ),
      data: (stats) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async =>
              ref.read(adminStatsProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Welcome Banner ──
                    _WelcomeBanner(),

                    const SizedBox(height: 20),

                    // ── Stat Cards Grid (Responsive, Compact Height) ──
                    const _SectionTitle('Key Platform Metrics'),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 850;
                        return GridView.builder(
                          itemCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 4 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 105,
                          ),
                          itemBuilder: (context, index) {
                            switch (index) {
                              case 0:
                                return StatCard(
                                  title: 'Total Users',
                                  value: stats.totalUsers.toString(),
                                  icon: Icons.people_alt_rounded,
                                  iconColor: AppColors.primaryDark,
                                );
                              case 1:
                                return StatCard(
                                  title: 'Total Pets',
                                  value: stats.totalPets.toString(),
                                  icon: Icons.pets_rounded,
                                  iconColor: AppColors.terracotta,
                                );
                              case 2:
                                return StatCard(
                                  title: 'Pending Apps',
                                  value: stats.pendingApplications.toString(),
                                  icon: Icons.assignment_late_rounded,
                                  iconColor: AppColors.warning,
                                  subtitle: stats.pendingApplications > 0
                                      ? 'Action required'
                                      : 'Up to date',
                                );
                              default:
                                return StatCard(
                                  title: 'Total Orders',
                                  value: stats.totalOrders.toString(),
                                  icon: Icons.shopping_bag_rounded,
                                  iconColor: AppColors.info,
                                  subtitle: 'Marketplace',
                                );
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Role Breakdown ──
                    const _SectionTitle('User Base by Role'),
                    const SizedBox(height: 12),
                    _RoleBreakdownCard(usersByRole: stats.usersByRole),
                    const SizedBox(height: 24),

                    // ── Quick Actions ──
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
            ),
          ),
        );
      },
    );
  }
}

// ── Reusable section title ──
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ── Welcome Banner ──
class _WelcomeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

// ── Role Breakdown Card ──
class _RoleBreakdownCard extends StatelessWidget {
  final Map<String, int> usersByRole;
  const _RoleBreakdownCard({required this.usersByRole});

  static const _roles = [
    ('Pet Owners', 'PET_OWNER', Icons.favorite_rounded, AppColors.terracotta),
    ('Sellers', 'SELLER', Icons.storefront_rounded, AppColors.info),
    ('Veterinarians', 'VETERINARIAN', Icons.medical_services_rounded, AppColors.success),
    ('System Admins', 'ADMIN', Icons.security_rounded, AppColors.primaryDark),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _roles.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _RoleRow(
              title: _roles[i].$1,
              count: usersByRole[_roles[i].$2] ?? 0,
              icon: _roles[i].$3,
              color: _roles[i].$4,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Single role row ──
class _RoleRow extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _RoleRow({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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

// ── Reusable error view ──
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'Failed to load admin stats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
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
}
