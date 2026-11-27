import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';

class PetMateBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final int pendingRequestsCount;
  final String? avatarUrl;
  final String profileInitial;

  const PetMateBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.pendingRequestsCount = 0,
    this.avatarUrl,
    this.profileInitial = 'P',
  });

  static const Color _deepTeal = Color(0xFF0F5C57);
  static const Color _sageGreen = Color(0xFFE8F0EA);
  static const Color _softCoral = Color(0xFFE16F52);
  static const Color _darkText = Color(0xFF293A37);
  static const Color _inactiveGrey = Color(0xFF6B7B76);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE4ECE6), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2926).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.pets_outlined,
                activeIcon: Icons.pets_rounded,
                label: 'Discover',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chats',
                badgeCount: pendingRequestsCount,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront_rounded,
                label: 'Shop',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.medical_services_outlined,
                activeIcon: Icons.medical_services_rounded,
                label: 'Vets',
              ),
              _buildProfileNavItem(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = selectedIndex == index;
    final iconColor = isSelected ? _deepTeal : _inactiveGrey;
    final labelColor = isSelected ? _darkText : _inactiveGrey;

    return Expanded(
      child: InkWell(
        onTap: () => onItemSelected(index),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                backgroundColor: _softCoral,
                label: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? _sageGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 21,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileNavItem() {
    final isSelected = selectedIndex == 4;
    final labelColor = isSelected ? _darkText : _inactiveGrey;

    return Expanded(
      child: InkWell(
        onTap: () => onItemSelected(4),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _deepTeal : Colors.transparent,
                    width: 2.0,
                  ),
                ),
                child: UserAvatar(
                  imageUrl: avatarUrl,
                  radius: 13,
                  initials: profileInitial,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Profile',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
