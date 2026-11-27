import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_network_image.dart';
import '../models/nearby_owner_model.dart';

class NearbyMap extends StatefulWidget {
  final ApproxLocation? userLocation;
  final int radiusKm;
  final List<NearbyOwnerModel> owners;
  final bool isLoading;

  const NearbyMap({
    super.key,
    required this.userLocation,
    required this.radiusKm,
    required this.owners,
    this.isLoading = false,
  });

  @override
  State<NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<NearbyMap> {
  final MapController _mapController = MapController();
  NearbyOwnerModel? _selectedOwner;

  LatLng get _center {
    final loc = widget.userLocation;
    if (loc != null) return LatLng(loc.latitude, loc.longitude);
    return const LatLng(27.7172, 85.3240);
  }

  double get _zoomForRadius {
    switch (widget.radiusKm) {
      case 5:
        return 12.8;
      case 20:
        return 10.7;
      case 10:
      default:
        return 11.7;
    }
  }

  @override
  void didUpdateWidget(covariant NearbyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.radiusKm != widget.radiusKm ||
        oldWidget.userLocation?.latitude != widget.userLocation?.latitude ||
        oldWidget.userLocation?.longitude != widget.userLocation?.longitude) {
      _selectedOwner = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(_center, _zoomForRadius);
        }
      });
    } else if (_selectedOwner != null &&
        !widget.owners.any((o) => o.ownerId == _selectedOwner!.ownerId)) {
      _selectedOwner = null;
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: AppColors.creamDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _zoomForRadius,
                  minZoom: 5,
                  maxZoom: 16,
                  onTap: (_, _) {
                    if (_selectedOwner != null) {
                      setState(() => _selectedOwner = null);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.petmate.app',
                  ),
                  if (widget.userLocation != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: center,
                          radius: widget.radiusKm * 1000.0,
                          useRadiusInMeter: true,
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.08),
                          borderColor:
                              const Color(0xFF1E88E5).withValues(alpha: 0.35),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // Individual nearby owner markers (using anonymized coordinates)
                      ...widget.owners.map((owner) {
                        final isSelected =
                            _selectedOwner?.ownerId == owner.ownerId;
                        final petImage = owner.pets.isNotEmpty
                            ? owner.pets.first.image
                            : null;
                        final avatarUrl = owner.profileImage ?? petImage;

                        return Marker(
                          point: LatLng(
                            owner.approxLocation.latitude,
                            owner.approxLocation.longitude,
                          ),
                          width: isSelected ? 52 : 44,
                          height: isSelected ? 52 : 44,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedOwner = owner);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.terracotta,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? AppNetworkImage(
                                        imageUrl: avatarUrl,
                                        fit: BoxFit.cover,
                                        fallbackIcon: Icons.pets_rounded,
                                        transformationWidth: 120,
                                      )
                                    : Container(
                                        color: AppColors.cream,
                                        child: const Icon(
                                          Icons.pets_rounded,
                                          size: 20,
                                          color: AppColors.terracotta,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      }),

                      // Current user's actual detected GPS location marker (blue dot)
                      if (widget.userLocation != null)
                        Marker(
                          point: center,
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E88E5)
                                  .withValues(alpha: 0.24),
                            ),
                            child: Center(
                              child: Container(
                                width: 15,
                                height: 15,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1E88E5),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        textStyle: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              // Privacy notice badge (top-left)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Approximate areas only',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Zoom / Recenter controls (top-right)
              Positioned(
                top: 10,
                right: 10,
                child: Column(
                  children: [
                    _MapControlButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          (zoom + 1).clamp(5.0, 16.0),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    _MapControlButton(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          (zoom - 1).clamp(5.0, 16.0),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    _MapControlButton(
                      icon: Icons.my_location_rounded,
                      onTap: () {
                        _mapController.move(center, _zoomForRadius);
                      },
                    ),
                  ],
                ),
              ),

              // Selected owner marker preview card (bottom)
              if (_selectedOwner != null)
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: _OwnerMarkerPreviewCard(
                    owner: _selectedOwner!,
                    onClose: () => setState(() => _selectedOwner = null),
                    onViewProfile: () {
                      context.push('/owner/${_selectedOwner!.ownerId}');
                    },
                  ),
                ),

              // Loading overlay while detecting GPS or fetching owners
              if (widget.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.48),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerMarkerPreviewCard extends StatelessWidget {
  final NearbyOwnerModel owner;
  final VoidCallback onClose;
  final VoidCallback onViewProfile;

  const _OwnerMarkerPreviewCard({
    required this.owner,
    required this.onClose,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final firstPet = owner.pets.isNotEmpty ? owner.pets.first : null;
    final extraPets = owner.pets.length > 1 ? owner.pets.length - 1 : 0;

    return GestureDetector(
      onTap: onViewProfile,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 48,
                height: 48,
                child: AppNetworkImage(
                  imageUrl: firstPet?.image ?? owner.profileImage,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.pets_rounded,
                  transformationWidth: 160,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    owner.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (firstPet != null)
                    Text(
                      extraPets > 0
                          ? '${firstPet.name} (+$extraPets more)'
                          : '${firstPet.name} • ${firstPet.breed}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        size: 11.5,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${owner.distanceKm.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onViewProfile,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Profile',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                size: 17,
                color: AppColors.textMuted,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
