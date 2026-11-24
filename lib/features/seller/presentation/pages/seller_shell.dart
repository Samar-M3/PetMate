import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/seller_provider.dart';

class SellerShell extends ConsumerStatefulWidget {
  const SellerShell({super.key});

  @override
  ConsumerState<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends ConsumerState<SellerShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final status = await ref.read(sellerProvider.notifier).loadSellerStatus();
      if (!mounted) return;
      if (status != null && !status.isApproved) {
        context.go('/seller/status');
        return;
      }
      ref.read(sellerProvider.notifier).loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sellerState = ref.watch(sellerProvider);
    final dashboard = sellerState.dashboardData;
    final storeName =
        dashboard?.store.name ??
        sellerState.statusResponse?.store?.name ??
        'My Store';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.info,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    storeName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 12,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Verified Seller Portal',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.badge_outlined,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: 'Store & Application Status',
            onPressed: () => context.go('/seller/status'),
          ),
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: 'Log Out',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: sellerState.isLoading && dashboard == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.info),
            )
          : RefreshIndicator(
              color: AppColors.info,
              onRefresh: () async {
                await ref.read(sellerProvider.notifier).loadDashboard();
              },
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Welcome Banner (Mobile Optimized)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.store_rounded,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, $storeName!',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Your seller account is verified and ready. Track sales, products, and customer orders.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Responsive Metric Cards (Mobile First: 2-column + full-width or 3-column on wide screens)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 600;

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildMetricCard(
                                            title: 'Total Products',
                                            value:
                                                '${dashboard?.metrics.totalProducts ?? 0}',
                                            icon: Icons.inventory_2_outlined,
                                            color: AppColors.info,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildMetricCard(
                                            title: 'Orders Received',
                                            value:
                                                '${dashboard?.metrics.totalOrders ?? 0}',
                                            icon: Icons.shopping_bag_outlined,
                                            color: AppColors.terracotta,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildMetricCard(
                                      title: 'Total Revenue',
                                      value:
                                          'NPR ${(dashboard?.metrics.totalRevenueNpr ?? 0).toStringAsFixed(2)}',
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      color: AppColors.success,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Total Products',
                                      value:
                                          '${dashboard?.metrics.totalProducts ?? 0}',
                                      icon: Icons.inventory_2_outlined,
                                      color: AppColors.info,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Orders Received',
                                      value:
                                          '${dashboard?.metrics.totalOrders ?? 0}',
                                      icon: Icons.shopping_bag_outlined,
                                      color: AppColors.terracotta,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Total Revenue',
                                      value:
                                          'NPR ${(dashboard?.metrics.totalRevenueNpr ?? 0).toStringAsFixed(2)}',
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),

                          // Quick Management Actions (Mobile Friendly Card List)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quick Store Actions',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildActionTile(
                                  icon: Icons.add_circle_outline_rounded,
                                  iconColor: AppColors.info,
                                  title: 'Add New Product',
                                  subtitle:
                                      'Publish pet food, toys, health or gear',
                                  onTap: () =>
                                      context.go('/seller/products/add'),
                                ),
                                const SizedBox(height: 8),
                                _buildActionTile(
                                  icon: Icons.storefront_outlined,
                                  iconColor: AppColors.terracotta,
                                  title: 'Visit PetMate Marketplace',
                                  subtitle: 'Browse all items live on the marketplace',
                                  onTap: () => context.go('/shop'),
                                ),
                                const SizedBox(height: 8),
                                _buildActionTile(
                                  icon: Icons.description_outlined,
                                  iconColor: AppColors.primary,
                                  title: 'Application & Business Info',
                                  subtitle: 'Review store documents, address and status',
                                  onTap: () => context.go('/seller/status'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
