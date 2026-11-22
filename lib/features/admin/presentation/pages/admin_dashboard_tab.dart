import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/admin_provider.dart';
import '../widgets/stat_card.dart';

class AdminDashboardTab extends ConsumerWidget {
  final VoidCallback onNavigateToUsers;
  final VoidCallback onNavigateToApplications;
  final VoidCallback onNavigateToEvents;
  final VoidCallback onNavigateToVets;
  final void Function(String role)? onRoleTap;

  const AdminDashboardTab({
    super.key,
    required this.onNavigateToUsers,
    required this.onNavigateToApplications,
    required this.onNavigateToEvents,
    required this.onNavigateToVets,
    this.onRoleTap,
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
                                  title: 'Total Events',
                                  value: stats.safeTotalEvents.toString(),
                                  icon: Icons.event_available_rounded,
                                  iconColor: AppColors.info,
                                  subtitle: 'Community care',
                                );
                              default:
                                return StatCard(
                                  title: 'Pending Apps',
                                  value: stats.pendingApplications.toString(),
                                  icon: Icons.assignment_late_rounded,
                                  iconColor: AppColors.warning,
                                  subtitle: stats.pendingApplications > 0
                                      ? 'Action required'
                                      : 'Up to date',
                                );
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Quick Actions ──
                    const _SectionTitle('Administrative Quick Actions'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _actionBtn(
                          icon: Icons.event_available_rounded,
                          label: 'Manage Events',
                          color: AppColors.terracotta,
                          onPressed: onNavigateToEvents,
                        ),
                        _actionBtn(
                          icon: Icons.medical_services_rounded,
                          label: 'Manage Vets',
                          color: AppColors.success,
                          onPressed: onNavigateToVets,
                        ),
                        _actionBtn(
                          icon: Icons.manage_accounts_rounded,
                          label: 'Manage Users',
                          color: AppColors.primaryDark,
                          onPressed: onNavigateToUsers,
                        ),
                        _actionBtn(
                          icon: Icons.approval_rounded,
                          label: 'Review Applications',
                          color: AppColors.warning,
                          onPressed: onNavigateToApplications,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Role Breakdown ──
                    const _SectionTitle('User Base by Role'),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap any role to view and manage users of that role',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    _RoleBreakdownCard(
                      usersByRole: stats.usersByRole,
                      onRoleTap: onRoleTap,
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

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
            'Monitor platform metrics, publish events, manage veterinarians, verify applications, and manage accounts securely.',
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
  final void Function(String role)? onRoleTap;
  const _RoleBreakdownCard({required this.usersByRole, this.onRoleTap});

  static const _roles = [
    ('Pet Owners', 'PET_OWNER', Icons.favorite_rounded, AppColors.terracotta),
    ('Sellers', 'SELLER', Icons.storefront_rounded, AppColors.info),
    ('Veterinarians', 'VETERINARIAN', Icons.medical_services_rounded, AppColors.success),
    ('System Admins', 'ADMIN', Icons.security_rounded, AppColors.primaryDark),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _roles.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: i == _roles.length - 1 ? const Radius.circular(16) : Radius.zero,
                ),
                onTap: () => onRoleTap?.call(_roles[i].$2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _RoleRow(
                    title: _roles[i].$1,
                    count: usersByRole[_roles[i].$2] ?? 0,
                    icon: _roles[i].$3,
                    color: _roles[i].$4,
                  ),
                ),
              ),
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
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
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
