import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/domain/entities/user_entity.dart';

class _PetSlot {
  final String id;
  final String name;
  final String? imageUrl;
  final bool isCurrent;

  const _PetSlot({
    required this.id,
    required this.name,
    this.imageUrl,
    this.isCurrent = false,
  });
}

/// Compact, Instagram/game-style radial pet switcher overlay anchored above
/// the Profile bottom navigation item.
class PetSwitcherOverlay {
  PetSwitcherOverlay._();

  static OverlayEntry? _entry;
  static final GlobalKey<_RadialSwitcherState> _switcherKey =
      GlobalKey<_RadialSwitcherState>();

  static bool get isShowing => _entry != null;

  static void show({
    required BuildContext context,
    required RenderBox anchor,
    required List<PetEntity> pets,
    required String? activePetId,
    required ValueChanged<String> onPetSelected,
  }) {
    if (pets.length <= 1) return;
    dismissImmediate();

    final overlay = Overlay.of(context, rootOverlay: true);
    final anchorPos = anchor.localToGlobal(Offset.zero);
    final anchorSize = anchor.size;

    _entry = OverlayEntry(
      builder: (_) => _RadialSwitcher(
        key: _switcherKey,
        anchorRect: Rect.fromLTWH(
          anchorPos.dx,
          anchorPos.dy,
          anchorSize.width,
          anchorSize.height,
        ),
        pets: pets
            .map(
              (p) => _PetSlot(
                id: p.id,
                name: p.name,
                imageUrl: p.effectiveImageUrl,
                isCurrent: p.id == activePetId,
              ),
            )
            .toList(),
        onSelected: (id) {
          onPetSelected(id);
        },
        onClosed: dismissImmediate,
      ),
    );

    overlay.insert(_entry!);
  }

  static void updateDrag(Offset globalPosition) {
    _switcherKey.currentState?.updatePointer(globalPosition);
  }

  static void endDrag(Offset globalPosition) {
    final state = _switcherKey.currentState;
    if (state != null) {
      state.completePointer(globalPosition);
    } else {
      dismissImmediate();
    }
  }

  static void cancel() {
    final state = _switcherKey.currentState;
    if (state != null) {
      state.closeAnimated();
    } else {
      dismissImmediate();
    }
  }

  static void dismissImmediate() {
    _entry?.remove();
    _entry = null;
  }
}

class _RadialSwitcher extends StatefulWidget {
  final Rect anchorRect;
  final List<_PetSlot> pets;
  final ValueChanged<String> onSelected;
  final VoidCallback onClosed;

  const _RadialSwitcher({
    super.key,
    required this.anchorRect,
    required this.pets,
    required this.onSelected,
    required this.onClosed,
  });

  @override
  State<_RadialSwitcher> createState() => _RadialSwitcherState();
}

class _RadialSwitcherState extends State<_RadialSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  int? _hoveredIndex;
  bool _isClosing = false;
  List<Offset> _cachedPositions = const [];

  static const Color _deepTeal = Color(0xFF0F5C57);
  static const Color _softCoral = Color(0xFFE16F52);
  static const Color _darkText = Color(0xFF293A37);

  static const double _avatarRadius = 25;
  static const double _avatarDiameter = _avatarRadius * 2;
  static const double _innerArcRadius = 78;
  static const double _outerArcRadius = 138;
  static const double _labelHeight = 24;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _animCtrl.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  List<Offset> _computePositions(Size screen) {
    final count = widget.pets.length;
    // Anchor slightly above the top-center of the Profile nav item.
    final origin = Offset(
      widget.anchorRect.center.dx,
      widget.anchorRect.top - 8,
    );

    final positions = <Offset>[];
    const int innerMax = 4;
    final innerCount = math.min(count, innerMax);
    final outerCount = math.max(0, count - innerMax);

    // Since Profile is the rightmost nav item, fan avatars upward and to the
    // left (-168° to -86°) so they stay comfortably inside the screen.
    void addRing(int ringCount, double radius, double minAngle, double maxAngle) {
      for (int i = 0; i < ringCount; i++) {
        final double angleDeg;
        if (ringCount == 1) {
          angleDeg = (minAngle + maxAngle) / 2;
        } else {
          angleDeg = minAngle + ((maxAngle - minAngle) / (ringCount - 1)) * i;
        }
        final rad = angleDeg * math.pi / 180;
        var x = origin.dx + radius * math.cos(rad);
        var y = origin.dy + radius * math.sin(rad);

        x = x.clamp(_avatarRadius + 12, screen.width - _avatarRadius - 12);
        y = y.clamp(
          _avatarRadius + _labelHeight + 16,
          widget.anchorRect.top - _avatarRadius - 6,
        );
        positions.add(Offset(x, y));
      }
    }

    if (innerCount == 2) {
      addRing(2, _innerArcRadius, -148, -96);
    } else if (innerCount == 3) {
      addRing(3, _innerArcRadius, -162, -90);
    } else {
      addRing(innerCount, _innerArcRadius, -170, -86);
    }

    if (outerCount > 0) {
      // Spread outer ring across a slightly wider arc for clean separation.
      addRing(outerCount, _outerArcRadius, -172, -88);
    }

    _cachedPositions = positions;
    return positions;
  }

  int? _hitTest(Offset globalPos) {
    const hitRadius = _avatarRadius + 14;
    int? closestIndex;
    double closestDist = double.infinity;

    for (int i = 0; i < _cachedPositions.length; i++) {
      final dist = (globalPos - _cachedPositions[i]).distance;
      if (dist <= hitRadius && dist < closestDist) {
        closestDist = dist;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  void updatePointer(Offset globalPos) {
    if (_isClosing || !mounted) return;
    final hit = _hitTest(globalPos);
    if (hit != _hoveredIndex) {
      setState(() => _hoveredIndex = hit);
      if (hit != null) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void completePointer(Offset globalPos) {
    if (_isClosing || !mounted) return;
    final hit = _hitTest(globalPos);
    if (hit != null) {
      final pet = widget.pets[hit];
      if (!pet.isCurrent) {
        HapticFeedback.lightImpact();
        widget.onSelected(pet.id);
      }
    }
    closeAnimated();
  }

  Future<void> closeAnimated() async {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    await _animCtrl.reverse();
    if (mounted) {
      widget.onClosed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final positions = _computePositions(screen);

    return GestureDetector(
      onTap: closeAnimated,
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Subtle localized radial backdrop anchored near bottom-right
            Positioned.fill(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        ((widget.anchorRect.center.dx / screen.width) * 2) - 1,
                        ((widget.anchorRect.top / screen.height) * 2) - 1,
                      ),
                      radius: 0.75,
                      colors: [
                        const Color(0xFF1A2926).withValues(alpha: 0.24),
                        const Color(0xFF1A2926).withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Pet avatars along the arc
            for (int i = 0; i < widget.pets.length; i++)
              _buildAvatar(i, positions[i]),

            // Floating name pill above hovered pet
            if (_hoveredIndex != null)
              _buildLabel(positions[_hoveredIndex!], screen),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(int index, Offset centre) {
    final pet = widget.pets[index];
    final isHovered = _hoveredIndex == index;
    final isCurrent = pet.isCurrent;

    return Positioned(
      left: centre.dx - _avatarRadius,
      top: centre.dy - _avatarRadius,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedScale(
          scale: isHovered ? 1.24 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: _avatarDiameter,
            height: _avatarDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: isHovered
                    ? _softCoral
                    : isCurrent
                        ? _deepTeal
                        : const Color(0xFFE4ECE6),
                width: isHovered
                    ? 3.0
                    : isCurrent
                        ? 2.5
                        : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHovered
                      ? _softCoral.withValues(alpha: 0.36)
                      : _darkText.withValues(alpha: 0.16),
                  blurRadius: isHovered ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: AppNetworkImage(
                    imageUrl: pet.imageUrl,
                    width: _avatarDiameter,
                    height: _avatarDiameter,
                    shape: BoxShape.circle,
                    fallbackIcon: Icons.pets,
                    fallbackInitials: pet.name,
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _deepTeal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(Offset centre, Size screen) {
    final pet = widget.pets[_hoveredIndex!];
    const pillWidth = 116.0;
    final left = (centre.dx - pillWidth / 2).clamp(
      8.0,
      screen.width - pillWidth - 8.0,
    );

    return Positioned(
      left: left,
      top: centre.dy - _avatarRadius - _labelHeight - 10,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SizedBox(
          width: pillWidth,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _darkText,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                pet.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
