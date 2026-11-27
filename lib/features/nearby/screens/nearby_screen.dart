import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/nearby_provider.dart';
import '../widgets/nearby_empty_state.dart';
import '../widgets/nearby_location_header.dart';
import '../widgets/nearby_map.dart';
import '../widgets/nearby_owner_card.dart';
import '../widgets/nearby_radius_selector.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nearbyProvider.notifier).onScreenEntered();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(nearbyProvider.notifier).onAppResumed();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 260;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(nearbyProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyProvider);
    final notifier = ref.read(nearbyProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            NearbyLocationHeader(
              currentArea: state.currentArea,
              permissionStatus: state.permissionStatus,
              locationEnabled: state.locationEnabled,
              isLoadingLocation: state.isLoadingLocation,
              isUpdatingVisibility: state.isUpdatingVisibility,
              onRefreshTap: notifier.refresh,
              onVisibilityChanged: notifier.toggleVisibility,
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: notifier.refresh,
                child: _buildBody(state, notifier),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(NearbyState state, NearbyNotifier notifier) {
    final isBlockedByLocation =
        state.permissionStatus == NearbyPermissionStatus.serviceDisabled ||
        state.permissionStatus == NearbyPermissionStatus.denied ||
        state.permissionStatus == NearbyPermissionStatus.deniedForever;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Distance selector (5 km, 10 km, 20 km) - rechecks GPS & permission on tap
        SliverToBoxAdapter(
          child: NearbyRadiusSelector(
            selectedRadius: state.selectedRadius,
            totalCount: state.total,
            onRadiusSelected: notifier.changeRadius,
          ),
        ),

        // Interactive Map (shows user's actual GPS + individual anonymized owner markers)
        SliverToBoxAdapter(
          child: NearbyMap(
            userLocation: state.userDeviceLocation,
            radiusKm: state.selectedRadius,
            owners: state.owners,
            isLoading: state.isLoadingLocation || state.isLoadingOwners,
          ),
        ),

        // Non-blocking GPS / Permission status banner when disabled or denied
        if (isBlockedByLocation)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildLocationStatusBanner(state, notifier),
            ),
          ),

        // Visibility Off notice banner
        if (state.permissionStatus == NearbyPermissionStatus.granted &&
            !state.locationEnabled &&
            state.userDeviceLocation != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 18,
                      color: Color(0xFFB76E00),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your profile is currently hidden from nearby discovery. Tap Visible above to appear to others.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 14)),

        // List States: Checking/Loading Skeleton, Blocked, Error, Empty, or Owners List
        if (state.permissionStatus == NearbyPermissionStatus.checking ||
            state.isLoadingLocation ||
            (state.isLoadingOwners && state.owners.isEmpty))
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, _) => const NearbyOwnerCardSkeleton(),
                childCount: 3,
              ),
            ),
          )
        else if (isBlockedByLocation && state.owners.isEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 12))
        else if (state.errorMessage != null && state.owners.isEmpty)
          SliverToBoxAdapter(
            child: _buildErrorState(state.errorMessage!, notifier),
          )
        else if (state.owners.isEmpty)
          SliverToBoxAdapter(
            child: NearbyEmptyState(
              currentRadius: state.selectedRadius,
              onExpandRadius: () {
                if (state.selectedRadius == 5) {
                  notifier.changeRadius(10);
                } else if (state.selectedRadius == 10) {
                  notifier.changeRadius(20);
                } else {
                  notifier.refresh();
                }
              },
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= state.owners.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }
                  return NearbyOwnerCard(owner: state.owners[index]);
                },
                childCount:
                    state.owners.length + (state.isLoadingMore ? 1 : 0),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationStatusBanner(
    NearbyState state,
    NearbyNotifier notifier,
  ) {
    final isServiceDisabled =
        state.permissionStatus == NearbyPermissionStatus.serviceDisabled;
    final isDeniedForever =
        state.permissionStatus == NearbyPermissionStatus.deniedForever;

    final String title;
    final String description;
    final String primaryLabel;
    final IconData icon;
    final VoidCallback onPrimaryTap;

    if (isServiceDisabled) {
      title = 'Location Services Turned Off';
      description = state.locationErrorMessage ??
          'Turn on your location to discover pet owners nearby.';
      primaryLabel = 'Turn On Location';
      icon = Icons.location_disabled_rounded;
      onPrimaryTap = notifier.enableLocationServiceAndLoad;
    } else if (isDeniedForever) {
      title = 'Location Permission Permanently Denied';
      description = state.locationErrorMessage ??
          'Enable location permission in app settings to discover nearby pet owners.';
      primaryLabel = 'Open App Settings';
      icon = Icons.settings_outlined;
      onPrimaryTap = notifier.openAppPermissionSettings;
    } else {
      title = 'Location Access Required';
      description = state.locationErrorMessage ??
          'Allow location access to discover pet owners around you.';
      primaryLabel = 'Allow Location';
      icon = Icons.my_location_rounded;
      onPrimaryTap = notifier.requestPermissionAndLoad;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warning.withValues(alpha: 0.14),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFFB76E00)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPrimaryTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(icon, size: 17),
                  label: Text(
                    primaryLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: notifier.refresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, NearbyNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 46,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load nearby owners',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
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
            onPressed: notifier.refresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
