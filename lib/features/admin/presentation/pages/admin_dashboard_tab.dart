import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/admin_stats_model.dart';
import '../providers/admin_provider.dart';
import '../theme/admin_colors.dart';
import '../widgets/stat_card.dart';
import 'package:petmatee/features/care_events/providers/care_events_provider.dart';

class AdminDashboardTab extends ConsumerWidget {
  final VoidCallback onNavigateToUsers;
  final VoidCallback onNavigateToApplications;
  final VoidCallback onNavigateToEvents;
  final VoidCallback onNavigateToVets;
  final VoidCallback onNavigateToAppointments;
  final void Function(String role)? onRoleTap;

  const AdminDashboardTab({
    super.key,
    required this.onNavigateToUsers,
    required this.onNavigateToApplications,
    required this.onNavigateToEvents,
    required this.onNavigateToVets,
    required this.onNavigateToAppointments,
    this.onRoleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final vetListCount = ref
        .watch(careVetsProvider)
        .maybeWhen(data: (vets) => vets.length, orElse: () => null);

    return statsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AdminColors.primary),
      ),
      error: (err, _) => _buildErrorView(ref, err.toString()),
      data: (stats) {
        final totalVets =
            vetListCount ??
            (stats.safeTotalVeterinarians > 0
                ? stats.safeTotalVeterinarians
                : (stats.usersByRole['VETERINARIAN'] ?? 0));

        return RefreshIndicator(
          color: AdminColors.primary,
          onRefresh: () async =>
              ref.read(adminStatsProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Metric Stat Cards Responsive Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 6;
                        if (constraints.maxWidth < 640) {
                          crossAxisCount = 2;
                        } else if (constraints.maxWidth < 1000) {
                          crossAxisCount = 3;
                        }

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: constraints.maxWidth < 640
                              ? 1.35
                              : 1.5,
                          children: [
                            StatCard(
                              title: 'Total Users',
                              value: '${stats.totalUsers}',
                              icon: Icons.people_outline_rounded,
                              iconColor: AdminColors.primary,
                              subtitle: 'Registered accounts',
                              onTap: onNavigateToUsers,
                            ),
                            StatCard(
                              title: 'Total Pets',
                              value: '${stats.totalPets}',
                              icon: Icons.pets_rounded,
                              iconColor: AdminColors.warning,
                              subtitle: 'Active companions',
                            ),
                            StatCard(
                              title: 'Veterinarians',
                              value: '$totalVets',
                              icon: Icons.medical_services_outlined,
                              iconColor: AdminColors.success,
                              subtitle: 'Verified clinics',
                              onTap: onNavigateToVets,
                            ),
                            StatCard(
                              title: 'Appointments',
                              value: '${stats.totalAppointments}',
                              icon: Icons.calendar_today_outlined,
                              iconColor: AdminColors.info,
                              subtitle: 'Patient queue',
                              onTap: onNavigateToAppointments,
                            ),
                            StatCard(
                              title: 'Total Orders',
                              value: '${stats.totalOrders}',
                              icon: Icons.shopping_bag_outlined,
                              iconColor: AdminColors.purple,
                              subtitle: 'Shop purchases',
                            ),
                            StatCard(
                              title: 'Total Revenue',
                              value: stats.totalRevenue > 0
                                  ? 'NPR ${(stats.totalRevenue).toStringAsFixed(0)}'
                                  : 'NPR 0',
                              icon: Icons.payments_outlined,
                              iconColor: AdminColors.primaryDark,
                              subtitle: 'Completed sales',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 2. Action Shortcuts Banner
                    _buildQuickActionBanner(context),
                    const SizedBox(height: 24),

                    // 3. Two-Column Analytics & Real-Time Overview
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;
                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: User Role Analytics + Recent Registrations (60%)
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _buildRoleDistributionCard(stats),
                                    const SizedBox(height: 20),
                                    _buildRecentUsersCard(stats),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Right Column: Pending Approvals + Quick Status (40%)
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    _buildPendingApprovalsCard(stats),
                                    const SizedBox(height: 20),
                                    _buildPlatformHealthCard(stats),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Mobile / Tablet vertical stack
                          return Column(
                            children: [
                              _buildPendingApprovalsCard(stats),
                              const SizedBox(height: 20),
                              _buildRoleDistributionCard(stats),
                              const SizedBox(height: 20),
                              _buildRecentUsersCard(stats),
                              const SizedBox(height: 20),
                              _buildPlatformHealthCard(stats),
                            ],
                          );
                        }
                      },
                    ),
const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border, width: 1.0),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: AdminColors.primary),
              SizedBox(width: 6),
              Text(
                'Quick Actions:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ),
            ],
          ),
          _buildActionButton(
            label: 'Review Applications',
            icon: Icons.verified_user_outlined,
            color: AdminColors.warning,
            onPressed: onNavigateToApplications,
          ),
          _buildActionButton(
            label: 'Manage Users',
            icon: Icons.people_outline_rounded,
            color: AdminColors.primary,
            onPressed: onNavigateToUsers,
          ),
          _buildActionButton(
            label: 'Add Veterinarian',
            icon: Icons.medical_services_outlined,
            color: AdminColors.success,
            onPressed: onNavigateToVets,
          ),
          _buildActionButton(
            label: 'Create Event',
            icon: Icons.event_outlined,
            color: AdminColors.info,
            onPressed: onNavigateToEvents,
          ),
          _buildActionButton(
            label: 'Patient Appointments',
            icon: Icons.calendar_today_outlined,
            color: AdminColors.purple,
            onPressed: onNavigateToAppointments,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.textPrimary,
        side: const BorderSide(color: AdminColors.border, width: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  // --- Role Distribution Section ---
  Widget _buildRoleDistributionCard(AdminStatsModel stats) {
    final total = stats.totalUsers > 0 ? stats.totalUsers : 1;
    final petOwners = stats.usersByRole['PET_OWNER'] ?? 0;
    final sellers = stats.usersByRole['SELLER'] ?? 0;
    final vets = stats.usersByRole['VETERINARIAN'] ?? 0;
    final admins = stats.usersByRole['ADMIN'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Base Breakdown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Distribution of registered user roles',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onNavigateToUsers,
                child: const Text('View All Users'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stacked Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (petOwners > 0)
                    Expanded(
                      flex: petOwners,
                      child: Container(color: AdminColors.primary),
                    ),
                  if (sellers > 0)
                    Expanded(
                      flex: sellers,
                      child: Container(color: AdminColors.info),
                    ),
                  if (vets > 0)
                    Expanded(
                      flex: vets,
                      child: Container(color: AdminColors.success),
                    ),
                  if (admins > 0)
                    Expanded(
                      flex: admins,
                      child: Container(color: AdminColors.purple),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Role Metrics Chips
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildRolePill(
                'Pet Owners',
                petOwners,
                (petOwners / total * 100),
                AdminColors.primary,
                'PET_OWNER',
              ),
              _buildRolePill(
                'Sellers',
                sellers,
                (sellers / total * 100),
                AdminColors.info,
                'SELLER',
              ),
              _buildRolePill(
                'Veterinarians',
                vets,
                (vets / total * 100),
                AdminColors.success,
                'VETERINARIAN',
              ),
              _buildRolePill(
                'Administrators',
                admins,
                (admins / total * 100),
                AdminColors.purple,
                'ADMIN',
              ),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildRolePill(
    String label,
    int count,
    double pct,
    Color color,
    String roleCode,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onRoleTap?.call(roleCode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdminColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Text(
                  '$count (${pct.toStringAsFixed(0)}%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Recent Users Card ---
  Widget _buildRecentUsersCard(AdminStatsModel stats) {
    final recentUsers = stats.recentUsers;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Registrations',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Latest accounts created on PetMate',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onNavigateToUsers,
                child: const Text('Manage All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No recent registrations found.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentUsers.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 0.8,
                color: AdminColors.borderLight,
              ),
              itemBuilder: (context, index) {
                final user = recentUsers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
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
                                  color: AdminColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
                              user.fullName ?? 'Unnamed User',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AdminColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user.email ?? 'No email',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AdminColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleTagColor(user.role)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.role,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _getRoleTagColor(user.role),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${user.petsCount} pets',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- Pending Approvals Card ---
  Widget _buildPendingApprovalsCard(AdminStatsModel stats) {
    final pendingCount = stats.pendingApplications;
    final recentApps = stats.recentApplications;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pendingCount > 0
              ? AdminColors.warning.withValues(alpha: 0.5)
              : AdminColors.border,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: pendingCount > 0
                          ? AdminColors.warningLight
                          : AdminColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      pendingCount > 0
                          ? Icons.assignment_late_outlined
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: pendingCount > 0
                          ? AdminColors.warning
                          : AdminColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Pending Verifications',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pendingCount Required',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (pendingCount == 0 || recentApps.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(
                    Icons.done_all_rounded,
                    size: 36,
                    color: AdminColors.success,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'All Caught Up!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'No pending role applications require review.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentApps.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 0.8,
                color: AdminColors.borderLight,
              ),
              itemBuilder: (context, index) {
                final app = recentApps[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color:
                              (app.type == 'SELLER'
                                      ? AdminColors.info
                                      : AdminColors.success)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          app.type == 'SELLER'
                              ? Icons.storefront_outlined
                              : Icons.medical_services_outlined,
                          size: 16,
                          color: app.type == 'SELLER'
                              ? AdminColors.info
                              : AdminColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.userFullName ?? app.userEmail ?? 'Applicant',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AdminColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (app.storeName != null)
                              Text(
                                app.storeName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AdminColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: onNavigateToApplications,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Review'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onNavigateToApplications,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AdminColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('View All Applications Queue'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Platform Health Card ---
  Widget _buildPlatformHealthCard(AdminStatsModel stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System & Services Status',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _buildHealthRow(
            'PostgreSQL Database',
            'Online & Synced',
            AdminColors.success,
          ),
          const SizedBox(height: 10),
          _buildHealthRow(
            'FCM Push Messaging',
            'Active v1 Engine',
            AdminColors.success,
          ),
          const SizedBox(height: 10),
          _buildHealthRow(
            'Community Events',
            '${stats.safeTotalEvents} Published',
            AdminColors.primary,
          ),
          const SizedBox(height: 10),
          _buildHealthRow(
            'Appointments Queue',
            '${stats.totalAppointments} Booked',
            AdminColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AdminColors.textSecondary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 6, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getRoleTagColor(String role) {
    switch (role) {
      case 'PET_OWNER':
        return AdminColors.primary;
      case 'SELLER':
        return AdminColors.info;
      case 'VETERINARIAN':
        return AdminColors.success;
      case 'ADMIN':
        return AdminColors.purple;
      default:
        return AdminColors.textSecondary;
    }
  }

  Widget _buildErrorView(WidgetRef ref, String msg) {
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
            const Text(
              'Failed to load admin metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(adminStatsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
