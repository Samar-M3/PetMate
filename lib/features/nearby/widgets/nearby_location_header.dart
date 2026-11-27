import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/nearby_provider.dart';

class NearbyLocationHeader extends StatelessWidget {
  final String? currentArea;
  final NearbyPermissionStatus permissionStatus;
  final bool locationEnabled;
  final bool isLoadingLocation;
  final bool isUpdatingVisibility;
  final VoidCallback onRefreshTap;
  final ValueChanged<bool> onVisibilityChanged;

  const NearbyLocationHeader({
    super.key,
    required this.currentArea,
    required this.permissionStatus,
    required this.locationEnabled,
    required this.isLoadingLocation,
    required this.isUpdatingVisibility,
    required this.onRefreshTap,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final permissionBadge = _buildPermissionBadge();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
                tooltip: 'Back',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby Pet Owners',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Discover pet owners around you.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: isLoadingLocation ? null : onRefreshTap,
                tooltip: 'Refresh GPS location',
                icon: isLoadingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: AppColors.primary,
                        size: 21,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (currentArea != null && currentArea!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AppColors.terracotta,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                currentArea!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    permissionBadge,
                  ],
                ),
              ),
              InkWell(
                onTap: isUpdatingVisibility
                    ? null
                    : () => onVisibilityChanged(!locationEnabled),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: locationEnabled
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.inputFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: locationEnabled
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        locationEnabled
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_outlined,
                        size: 14,
                        color: locationEnabled
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        locationEnabled ? 'Visible' : 'Hidden',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: locationEnabled
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBadge() {
    late final Color bgColor;
    late final Color textColor;
    late final IconData icon;
    late final String label;

    switch (permissionStatus) {
      case NearbyPermissionStatus.granted:
        bgColor = AppColors.success.withValues(alpha: 0.12);
        textColor = AppColors.success;
        icon = Icons.gps_fixed_rounded;
        label = 'GPS Active';
      case NearbyPermissionStatus.serviceDisabled:
        bgColor = AppColors.warning.withValues(alpha: 0.14);
        textColor = const Color(0xFFB76E00);
        icon = Icons.location_disabled_rounded;
        label = 'GPS Off';
      case NearbyPermissionStatus.denied:
      case NearbyPermissionStatus.deniedForever:
        bgColor = AppColors.warning.withValues(alpha: 0.14);
        textColor = const Color(0xFFB76E00);
        icon = Icons.location_off_rounded;
        label = 'Permission Needed';
      case NearbyPermissionStatus.checking:
        bgColor = AppColors.inputFill;
        textColor = AppColors.textSecondary;
        icon = Icons.hourglass_top_rounded;
        label = 'Checking GPS...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
