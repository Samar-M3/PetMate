import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../care_events/providers/care_events_provider.dart';
import '../../../care_events/screens/appointments/health_records_screen.dart';
import '../../../care_events/screens/appointments/my_appointments_screen.dart';
import '../../../care_events/screens/events_home_screen.dart';
import '../../../home/presentation/providers/requests_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  /// When true, the page is embedded as a bottom nav tab (no back button).
  /// When false (default), it's pushed via GoRouter and shows a back arrow.
  final bool embeddedInTab;

  const ProfilePage({super.key, this.embeddedInTab = false});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  static const Color _primaryTeal = Color(0xFF0B625B);
  static const Color _coralAccent = Color(0xFFE8795B);
  static const Color _warmIvory = Color(0xFFF8F6F0);
  static const Color _cardWhite = Color(0xFFFFFFFF);
  static const Color _charcoalText = Color(0xFF26332F);
  static const Color _mutedText = Color(0xFF7B8880);
  static const Color _softBorder = Color(0xFFE5E8E2);
  static const Color _dangerRed = Color(0xFFC84343);
  static const Color _activeGreen = Color(0xFF1F8A5B);

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign out',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _charcoalText,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out of PetMate?',
          style: TextStyle(fontSize: 14, color: _mutedText, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text(
              'Sign out',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final profile = user?.profile;
    final pets = user?.pets ?? [];
    final activePetsCount = pets.where((p) => p.isActive).length;

    final pendingRequestsCount = ref.watch(
      requestsProvider.select((s) => s.pendingCount),
    );
    final upcomingApptsCount = ref
        .watch(appointmentsProvider)
        .maybeWhen(
          data: (list) => list.where((a) => a.isUpcoming).length,
          orElse: () => 0,
        );

    final avatarUrl = profile?.effectiveImageUrl ?? profile?.profilePictureUrl;
    final displayName =
        (profile?.fullName != null && profile!.fullName!.trim().isNotEmpty)
        ? profile.fullName!.trim()
        : (user?.email?.split('@').first ?? 'Pet Owner');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P';
    final locationText = [
      profile?.area,
      profile?.location,
    ].where((e) => e != null && e.trim().isNotEmpty).firstOrNull?.trim();

    if (authState.isLoading && user == null) {
      return const Scaffold(
        backgroundColor: _warmIvory,
        body: Center(
          child: CircularProgressIndicator(color: _primaryTeal, strokeWidth: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _warmIvory,
      body: SafeArea(
        bottom: !widget.embeddedInTab,
        child: RefreshIndicator(
          color: _primaryTeal,
          onRefresh: () async {
            await ref.read(authStateProvider.notifier).refreshUserProfile();
            await ref
                .read(requestsProvider.notifier)
                .loadRequests(refresh: true);
            ref.invalidate(appointmentsProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // 1. Quiet Compact Header
              SliverToBoxAdapter(
                child: _buildCompactHeader(context),
              ),

              // 2. Scrollable Profile Content (8pt spacing rhythm)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Profile Identity Card
                    _buildProfileInfoCard(
                      context: context,
                      avatarUrl: avatarUrl,
                      initial: initial,
                      displayName: displayName,
                      role: user?.role ?? UserRole.petOwner,
                      location: locationText,
                      email: user?.email,
                      bio: profile?.bio,
                    ),
                    const SizedBox(height: 12),

                    // Clean Tabular Statistics Strip
                    _buildStatsBar(
                      totalPets: pets.length,
                      activePets: activePetsCount,
                      activeRequests: pendingRequestsCount,
                    ),
                    const SizedBox(height: 24),

                    // My Pets Showcase (the visual moment)
                    _buildMyPetsSection(context, pets),
                    const SizedBox(height: 24),

                    // Appointments & Activity
                    _buildSectionTitle('Appointments & activity'),
                    const SizedBox(height: 8),
                    _buildGroupedList([
                      _ActionRowItem(
                        icon: Icons.medical_services_outlined,
                        title: 'Upcoming vet appointments',
                        subtitle: upcomingApptsCount > 0
                            ? '$upcomingApptsCount scheduled'
                            : 'Clinic visits and history',
                        count: upcomingApptsCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyAppointmentsScreen(),
                          ),
                        ),
                      ),
                      _ActionRowItem(
                        icon: Icons.favorite_border_rounded,
                        title: 'Mating requests',
                        subtitle: pendingRequestsCount > 0
                            ? '$pendingRequestsCount awaiting response'
                            : 'Incoming and sent requests',
                        count: pendingRequestsCount,
                        highlightDot: pendingRequestsCount > 0,
                        onTap: () => context.push('/requests'),
                      ),
                      _ActionRowItem(
                        icon: Icons.calendar_today_outlined,
                        title: 'My events',
                        subtitle: 'Discover and manage pet events',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _EventsWrapper(),
                          ),
                        ),
                      ),
                      _ActionRowItem(
                        icon: Icons.assignment_outlined,
                        title: 'Pet health records',
                        subtitle: 'Vaccinations and medical notes',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HealthRecordsScreen(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Account & Marketplace
                    _buildSectionTitle('Account & marketplace'),
                    const SizedBox(height: 8),
                    _buildGroupedList([
                      _ActionRowItem(
                        icon: Icons.tune_rounded,
                        title: 'Manage pets',
                        subtitle: 'Visibility in Discover feed',
                        onTap: () => context.push('/my-pets'),
                      ),
                      _ActionRowItem(
                        icon: Icons.add_circle_outline_rounded,
                        title: 'Pet slots',
                        subtitle: 'Add active discovery slots',
                        onTap: () => context.push('/slots'),
                      ),
                      _ActionRowItem(
                        icon: Icons.storefront_outlined,
                        title: user?.role == UserRole.seller
                            ? 'Seller portal'
                            : 'Seller hub',
                        subtitle: user?.role == UserRole.seller
                            ? 'Inventory, listings and orders'
                            : 'Sell pet food and supplies',
                        statusLabel:
                            user?.role == UserRole.seller ? 'Active' : null,
                        onTap: () {
                          if (user?.role == UserRole.seller) {
                            context.push('/seller');
                          } else {
                            context.push('/seller/status');
                          }
                        },
                      ),
                      _ActionRowItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'My orders',
                        subtitle: 'Purchases and order history',
                        onTap: () => context.push('/shop/orders'),
                      ),
                      _ActionRowItem(
                        icon: Icons.bookmark_border_rounded,
                        title: 'Saved wishlist',
                        subtitle: 'Products saved for your pets',
                        onTap: () => context.push('/shop/wishlist'),
                      ),
                      _ActionRowItem(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notification settings',
                        subtitle: 'Push alerts and preferences',
                        onTap: () => context.push('/settings/notifications'),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Sign Out
                    _buildSignOutButton(context),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if (!widget.embeddedInTab) ...[
            _HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => context.pop(),
            ),
            const SizedBox(width: 12),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icons/petmate-logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          const Text.rich(
            TextSpan(
              text: 'Pet',
              children: [
                TextSpan(
                  text: 'Mate',
                  style: TextStyle(color: _coralAccent),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: _charcoalText,
            ),
          ),
          const Spacer(),
          _HeaderIconButton(
            icon: Icons.settings_outlined,
            onTap: () => context.push('/settings/notifications'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard({
    required BuildContext context,
    required String? avatarUrl,
    required String initial,
    required String displayName,
    required UserRole role,
    required String? location,
    required String? email,
    required String? bio,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _softBorder, width: 1.5),
                ),
                child: UserAvatar(
                  imageUrl: avatarUrl,
                  radius: 28,
                  initials: initial,
                  onTap: () => context.push('/onboarding/owner'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _charcoalText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _formatRoleName(role),
                        if (location != null && location.isNotEmpty) location,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _mutedText,
                      ),
                    ),
                    if (email != null && email.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.push('/onboarding/owner'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _charcoalText,
                  side: const BorderSide(color: _softBorder),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (bio != null && bio.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.8, color: _softBorder),
            const SizedBox(height: 12),
            Text(
              bio.trim(),
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: _charcoalText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsBar({
    required int totalPets,
    required int activePets,
    required int activeRequests,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _softBorder),
      ),
      child: Row(
        children: [
          _buildStatColumn(
            value: '$totalPets',
            label: 'Total pets',
          ),
          Container(width: 1, height: 28, color: _softBorder),
          _buildStatColumn(
            value: '$activePets',
            label: 'Active pets',
          ),
          Container(width: 1, height: 28, color: _softBorder),
          _buildStatColumn(
            value: '$activeRequests',
            label: 'Mating requests',
            accentValue: activeRequests > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required String value,
    required String label,
    bool accentValue = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: accentValue ? _primaryTeal : _charcoalText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPetsSection(BuildContext context, List<PetEntity> pets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'My pets',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _charcoalText,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.push('/onboarding/pet'),
              style: TextButton.styleFrom(
                foregroundColor: _primaryTeal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text(
                'Add pet',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pets.isEmpty)
          _buildEmptyPetsCard(context)
        else
          SizedBox(
            height: 224,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: pets.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == pets.length) {
                  return _buildAddPetCard(context);
                }
                return _buildPetProfileCard(context, pets[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyPetsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.pets_outlined,
            size: 28,
            color: _mutedText,
          ),
          const SizedBox(height: 12),
          const Text(
            'No pets added yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _charcoalText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add your pet profile to start matching nearby',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _mutedText),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/onboarding/pet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Add pet',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetProfileCard(BuildContext context, PetEntity pet) {
    final subtitleParts = <String>[
      if (pet.gender != null && pet.gender!.trim().isNotEmpty)
        _formatGender(pet.gender!),
      if (pet.dateOfBirth != null) pet.ageString.replaceFirst(' old', ''),
    ];

    return Material(
      color: _cardWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/pet/${pet.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 172,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _softBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual focus: Pet photo
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: SizedBox(
                      height: 132,
                      width: double.infinity,
                      child: AppNetworkImage(
                        imageUrl: pet.effectiveImageUrl,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.pets_rounded,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _cardWhite.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: pet.isActive ? _activeGreen : _mutedText,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            pet.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: pet.isActive ? _charcoalText : _mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Pet Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _charcoalText,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: _mutedText,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.breed?.trim().isNotEmpty == true
                                ? pet.breed!.trim()
                                : (pet.animalType ?? 'Pet'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _charcoalText,
                            ),
                          ),
                          if (subtitleParts.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitleParts.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _mutedText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPetCard(BuildContext context) {
    return Material(
      color: _cardWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/onboarding/pet'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _softBorder),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                color: _primaryTeal,
                size: 22,
              ),
              SizedBox(height: 6),
              Text(
                'Add pet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _primaryTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _mutedText,
        ),
      ),
    );
  }

  Widget _buildGroupedList(List<_ActionRowItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _softBorder),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(12) : Radius.zero,
                  bottom: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Icon(item.icon, size: 18, color: _mutedText),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _charcoalText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.highlightDot) ...[
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: _coralAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      if (item.count > 0) ...[
                        Text(
                          '${item.count}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _mutedText,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ] else if (item.statusLabel != null) ...[
                        Text(
                          item.statusLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _activeGreen,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: _mutedText,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 0.8,
                  indent: 50,
                  endIndent: 16,
                  color: _softBorder,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Material(
      color: _cardWhite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _confirmSignOut(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _softBorder),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: _dangerRed, size: 18),
              SizedBox(width: 8),
              Text(
                'Sign out',
                style: TextStyle(
                  color: _dangerRed,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  String _formatGender(String gender) {
    final upper = gender.trim().toUpperCase();
    if (upper == 'MALE') return 'Male';
    if (upper == 'FEMALE') return 'Female';
    return gender.trim();
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfilePageState._cardWhite,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _ProfilePageState._softBorder),
          ),
          child: Icon(
            icon,
            color: _ProfilePageState._charcoalText,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Wraps EventsHomeScreen in a Scaffold with AppBar when pushed from Profile.
class _EventsWrapper extends StatelessWidget {
  const _EventsWrapper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProfilePageState._warmIvory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: _ProfilePageState._charcoalText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pet events',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _ProfilePageState._charcoalText,
          ),
        ),
        centerTitle: true,
      ),
      body: const SafeArea(child: EventsHomeScreen()),
    );
  }
}

class _ActionRowItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final String? statusLabel;
  final bool highlightDot;
  final VoidCallback onTap;

  const _ActionRowItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.count = 0,
    this.statusLabel,
    this.highlightDot = false,
    required this.onTap,
  });
}
