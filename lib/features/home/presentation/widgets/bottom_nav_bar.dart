import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';

class PetMateBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final int pendingRequestsCount;
  final String? avatarUrl;
  final String profileInitial;

  /// Key attached to the profile nav item so the switcher overlay can anchor to it.
  final GlobalKey? profileItemKey;

  /// Called after an 800 ms long press on the Profile button.
  final ValueChanged<Offset>? onProfileLongPressStart;
  final ValueChanged<Offset>? onProfileLongPressMove;
  final ValueChanged<Offset>? onProfileLongPressEnd;
  final VoidCallback? onProfileLongPressCancel;

  const PetMateBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.pendingRequestsCount = 0,
    this.avatarUrl,
    this.profileInitial = 'P',
    this.profileItemKey,
    this.onProfileLongPressStart,
    this.onProfileLongPressMove,
    this.onProfileLongPressEnd,
    this.onProfileLongPressCancel,
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
              Expanded(
                child: _ProfileNavItem(
                  itemKey: profileItemKey,
                  isSelected: selectedIndex == 4,
                  avatarUrl: avatarUrl,
                  profileInitial: profileInitial,
                  onTap: () => onItemSelected(4),
                  onLongPressStart: onProfileLongPressStart,
                  onLongPressMove: onProfileLongPressMove,
                  onLongPressEnd: onProfileLongPressEnd,
                  onLongPressCancel: onProfileLongPressCancel,
                ),
              ),
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
}

class _ProfileNavItem extends StatefulWidget {
  final GlobalKey? itemKey;
  final bool isSelected;
  final String? avatarUrl;
  final String profileInitial;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onLongPressStart;
  final ValueChanged<Offset>? onLongPressMove;
  final ValueChanged<Offset>? onLongPressEnd;
  final VoidCallback? onLongPressCancel;

  const _ProfileNavItem({
    this.itemKey,
    required this.isSelected,
    required this.avatarUrl,
    required this.profileInitial,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressMove,
    this.onLongPressEnd,
    this.onLongPressCancel,
  });

  @override
  State<_ProfileNavItem> createState() => _ProfileNavItemState();
}

class _ProfileNavItemState extends State<_ProfileNavItem> {
  static const Duration _longPressThreshold = Duration(milliseconds: 250);
  static const double _preLongPressSlop = 24.0;

  Timer? _holdTimer;
  int? _activePointer;
  Offset? _downPosition;
  bool _longPressActive = false;
  bool _isPressed = false;
  bool _slopExceeded = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _resetState() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _activePointer = null;
    _downPosition = null;
    _longPressActive = false;
    _slopExceeded = false;
    if (_isPressed && mounted) {
      setState(() => _isPressed = false);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _downPosition = event.position;
    _longPressActive = false;
    _slopExceeded = false;
    setState(() => _isPressed = true);

    if (widget.onLongPressStart != null) {
      _holdTimer?.cancel();
      _holdTimer = Timer(_longPressThreshold, () {
        if (!mounted || _activePointer == null || _slopExceeded) return;
        _longPressActive = true;
        widget.onLongPressStart?.call(_downPosition ?? event.position);
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;

    if (_longPressActive) {
      widget.onLongPressMove?.call(event.position);
      return;
    }

    if (!_slopExceeded && _downPosition != null) {
      if ((event.position - _downPosition!).distance > _preLongPressSlop) {
        _slopExceeded = true;
        _holdTimer?.cancel();
        _holdTimer = null;
        if (_isPressed && mounted) {
          setState(() => _isPressed = false);
        }
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;

    if (_longPressActive) {
      widget.onLongPressEnd?.call(event.position);
      _resetState();
      return;
    }

    final shouldTap = !_slopExceeded;
    _resetState();
    if (shouldTap) {
      widget.onTap();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;

    if (_longPressActive) {
      widget.onLongPressCancel?.call();
    }
    _resetState();
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = widget.isSelected
        ? PetMateBottomNavBar._darkText
        : PetMateBottomNavBar._inactiveGrey;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedScale(
        scale: _isPressed && !_longPressActive ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Padding(
          key: widget.itemKey,
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
                    color: widget.isSelected
                        ? PetMateBottomNavBar._deepTeal
                        : Colors.transparent,
                    width: 2.0,
                  ),
                ),
                child: UserAvatar(
                  imageUrl: widget.avatarUrl,
                  radius: 13,
                  initials: widget.profileInitial,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Profile',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
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
