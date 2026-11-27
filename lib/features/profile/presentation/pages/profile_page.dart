import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  // No initState refresh needed — auth provider already syncs profile on auth state change.
  // Profile data is available via ref.watch(authStateProvider).

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of PetMate?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final profile = user?.profile;
    final pets = user?.pets ?? [];
    final activePetsCount = pets.where((p) => p.isActive).length;

    final avatarUrl = profile?.effectiveImageUrl ?? profile?.profilePictureUrl;
    final displayName =
        (profile?.fullName != null && profile!.fullName!.trim().isNotEmpty)
        ? profile.fullName!.trim()
        : (user?.email?.split('@').first ?? 'Pet Owner');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Modern Collapsing Hero Banner with Back Button
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primary,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => context.push('/settings/notifications'),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient Warm Banner
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Subtle Decorative Paw Prints
                  Positioned(
                    right: -20,
                    top: 20,
                    child: Opacity(
                      opacity: 0.12,
                      child: Icon(Icons.pets, size: 140, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 40,
                    child: Opacity(
                      opacity: 0.08,
                      child: Icon(Icons.pets, size: 80, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Profile Details & Settings List
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -42),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A. Hero Identity Card (Floating Over Banner)
                    _buildIdentityCard(
                      context: context,
                      avatarUrl: avatarUrl,
                      initial: initial,
                      displayName: displayName,
                      email: user?.email,
                      role: user?.role ?? UserRole.petOwner,
                      location: profile?.location ?? profile?.area,
                      bio: profile?.bio,
                    ),
                    const SizedBox(height: 18),

                    // B. Quick Stats Summary
                    _buildStatsBar(
                      totalPets: pets.length,
                      activeInDeck: activePetsCount,
                      roleName: _formatRoleName(user?.role),
                    ),
                    const SizedBox(height: 22),

                    // C. "My Furry Family" Section (Pets horizontal list + Add card)
                    _buildPetsSection(context, pets),
                    const SizedBox(height: 24),

                    // D. Section: Account & Pet Management
                    _buildSectionHeader('Account & Pets'),
                    const SizedBox(height: 8),
                    _buildSettingsGroup([
                      _SettingsItem(
                        icon: Icons.person_outline_rounded,
                        iconColor: AppColors.primary,
                        title: 'Edit Owner Profile',
                        subtitle: 'Update your name, bio, location, and photo',
                        onTap: () => context.push('/onboarding/owner'),
                      ),
                      _SettingsItem(
                        icon: Icons.tune_rounded,
                        iconColor: AppColors.terracotta,
                        title: 'Manage Pets & Visibility',
                        subtitle: 'Control which pets appear in discovery feed',
                        onTap: () => context.push('/my-pets'),
                      ),
                      _SettingsItem(
                        icon: Icons.add_circle_outline_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Extra Pet Slots',
                        subtitle: 'Purchase additional active discovery slots',
                        onTap: () => context.push('/slots'),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // E. Section: Commerce & Services
                    _buildSectionHeader('Marketplace & Services'),
                    const SizedBox(height: 8),
                    _buildSettingsGroup([
                      _SettingsItem(
                        icon: Icons.storefront_rounded,
                        iconColor: AppColors.terracotta,
                        title: user?.role == UserRole.seller
                            ? 'Seller Portal'
                            : 'Seller Hub',
                        subtitle: user?.role == UserRole.seller
                            ? 'Manage inventory, listings, and orders'
                            : 'Apply to sell pet food, supplies & products',
                        badge: user?.role == UserRole.seller ? 'Active' : null,
                        badgeColor: AppColors.success,
                        onTap: () {
                          if (user?.role == UserRole.seller) {
                            context.push('/seller');
                          } else {
                            context.push('/seller/status');
                          }
                        },
                      ),
                      _SettingsItem(
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppColors.primaryDark,
                        title: 'My Orders',
                        subtitle: 'Track purchases and view order history',
                        onTap: () => context.push('/shop/orders'),
                      ),
                      _SettingsItem(
                        icon: Icons.favorite_outline_rounded,
                        iconColor: const Color(0xFFE91E63),
                        title: 'Saved Wishlist',
                        subtitle: 'Products saved for your furry friends',
                        onTap: () => context.push('/shop/wishlist'),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // F. Section: Preferences
                    _buildSectionHeader('Preferences & Alerts'),
                    const SizedBox(height: 8),
                    _buildSettingsGroup([
                      _SettingsItem(
                        icon: Icons.notifications_none_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        title: 'Push Notifications',
                        subtitle:
                            'Customize alerts for messages, matches & orders',
                        onTap: () => context.push('/settings/notifications'),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // G. Sign Out Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _confirmSignOut(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildIdentityCard({
    required BuildContext context,
    required String? avatarUrl,
    required String initial,
    required String displayName,
    required String? email,
    required UserRole role,
    required String? location,
    required String? bio,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // User Avatar with edit badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: UserAvatar(
                  imageUrl: avatarUrl,
                  radius: 46,
                  initials: initial,
                  onTap: () => context.push('/onboarding/owner'),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/onboarding/owner'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.terracotta,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Full Name
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Role Badge & Location Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Role Tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getRoleIcon(role),
                      size: 13,
                      color: _getRoleColor(role),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatRoleName(role),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(role),
                      ),
                    ),
                  ],
                ),
              ),
              if (location != null && location.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: AppColors.terracotta,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      location.trim(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              email,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ],

          // Bio if present
          if (bio != null && bio.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                bio.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsBar({
    required int totalPets,
    required int activeInDeck,
    required String roleName,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            'Total Pets',
            '$totalPets',
            Icons.pets_rounded,
            AppColors.primary,
          ),
          _buildStatDivider(),
          _buildStatItem(
            'Active in Deck',
            '$activeInDeck',
            Icons.visibility_rounded,
            AppColors.success,
          ),
          _buildStatDivider(),
          _buildStatItem(
            'Account',
            roleName,
            Icons.verified_user_rounded,
            AppColors.terracotta,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 28, width: 1, color: AppColors.border);
  }

  Widget _buildPetsSection(BuildContext context, List pets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.pets, size: 18, color: AppColors.terracotta),
                const SizedBox(width: 6),
                Text(
                  'My Pets (${pets.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => context.push('/my-pets'),
                  child: const Text(
                    'Manage',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/onboarding/pet'),
                  icon: const Icon(
                    Icons.add,
                    size: 16,
                    color: AppColors.terracotta,
                  ),
                  label: const Text(
                    'Add Pet',
                    style: TextStyle(
                      color: AppColors.terracotta,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (pets.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.pets_rounded,
                  size: 40,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(height: 10),
                const Text(
                  'No pets registered yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add your pet\'s profile to start discovering friends!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => context.push('/onboarding/pet'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add My Pet',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: pets.length + 1, // +1 for Add Pet shortcut card
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == pets.length) {
                  // Add Pet Shortcut Card
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/onboarding/pet'),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.terracotta.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.cream,
                              child: Icon(
                                Icons.add_rounded,
                                color: AppColors.terracotta,
                                size: 24,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add Pet',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.terracotta,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final pet = pets[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => context.push('/pet/${pet.id}'),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 124,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: pet.isActive
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : AppColors.border,
                          width: pet.isActive ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              AppNetworkImage(
                                imageUrl:
                                    pet.effectiveImageUrl ??
                                    pet.profilePictureUrl,
                                width: 52,
                                height: 52,
                                shape: BoxShape.circle,
                                fallbackIcon: Icons.pets,
                              ),
                              Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: pet.isActive
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pet.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            pet.breed ?? pet.animalType ?? 'Pet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (pet.isActive
                                          ? AppColors.success
                                          : AppColors.textSecondary)
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pet.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: pet.isActive
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(18) : Radius.zero,
                    bottom: isLast ? const Radius.circular(18) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        // Icon Squircle
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: item.iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.icon,
                            size: 20,
                            color: item.iconColor,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (item.badge != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (item.badgeColor ??
                                                    AppColors.primary)
                                                .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.badge!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              item.badgeColor ??
                                              AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Chevron
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 0.7,
                  indent: 68,
                  endIndent: 16,
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.deepPurple;
      case UserRole.veterinarian:
        return const Color(0xFF0284C7);
      case UserRole.seller:
        return AppColors.terracotta;
      case UserRole.petOwner:
        return AppColors.primaryDark;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.veterinarian:
        return Icons.medical_services_rounded;
      case UserRole.seller:
        return Icons.storefront_rounded;
      case UserRole.petOwner:
        return Icons.pets_rounded;
    }
  }

  String _formatRoleName(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.veterinarian:
        return 'Veterinarian';
      case UserRole.seller:
        return 'Seller';
      case UserRole.petOwner:
      default:
        return 'Pet Owner';
    }
  }
}

class _SettingsItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });
}
