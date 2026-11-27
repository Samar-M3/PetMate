import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class NearbyEmptyState extends StatelessWidget {
  final int currentRadius;
  final VoidCallback onExpandRadius;

  const NearbyEmptyState({
    super.key,
    required this.currentRadius,
    required this.onExpandRadius,
  });

  @override
  Widget build(BuildContext context) {
    final canExpand = currentRadius < 20;
    final nextRadius = currentRadius == 5 ? 10 : 20;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
            child: const Icon(
              Icons.location_searching_rounded,
              size: 38,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No pet owners nearby yet!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try expanding your search radius to discover more pet families.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onExpandRadius,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              canExpand ? Icons.zoom_out_map_rounded : Icons.refresh_rounded,
              size: 18,
            ),
            label: Text(
              canExpand
                  ? 'Expand Radius to $nextRadius km'
                  : 'Refresh Nearby Search',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
