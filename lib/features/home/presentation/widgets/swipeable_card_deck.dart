import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/discovery_pet.dart';
import 'pet_profile_card.dart';

class SwipeableCardDeck extends StatefulWidget {
  final List<DiscoveryPet> pets;
  final int currentIndex;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final VoidCallback onReset;

  const SwipeableCardDeck({
    super.key,
    required this.pets,
    required this.currentIndex,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onReset,
  });

  @override
  State<SwipeableCardDeck> createState() => SwipeableCardDeckState();
}

class SwipeableCardDeckState extends State<SwipeableCardDeck>
    with SingleTickerProviderStateMixin {
  static const Color _deepTeal = Color(0xFF0F5C57);
  static const Color _sageGreen = Color(0xFFE8F0EA);
  static const Color _warmCream = Color(0xFFFAF7F0);
  static const Color _softCoral = Color(0xFFFF8A65);
  static const Color _darkText = Color(0xFF293A37);

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;

  Offset _dragOffset = Offset.zero;
  final ValueNotifier<Offset> _dragOffsetListenable = ValueNotifier(
    Offset.zero,
  );
  bool _isAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _animController.addListener(() {
      _dragOffset = _slideAnimation.value;
      _dragOffsetListenable.value = _dragOffset;
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isAnimatingOut) {
        final wasSwipeRight = _dragOffset.dx > 0;
        _isAnimatingOut = false;
        _dragOffset = Offset.zero;
        _dragOffsetListenable.value = Offset.zero;
        if (wasSwipeRight) {
          widget.onSwipeRight();
        } else {
          widget.onSwipeLeft();
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _dragOffsetListenable.dispose();
    super.dispose();
  }

  void swipeRightProgrammatic() {
    if (_isAnimatingOut || widget.currentIndex >= widget.pets.length) return;
    _animateCardOut(const Offset(520, 24), 0.26);
  }

  void swipeLeftProgrammatic() {
    if (_isAnimatingOut || widget.currentIndex >= widget.pets.length) return;
    _animateCardOut(const Offset(-520, 24), -0.26);
  }

  void _animateCardOut(Offset targetOffset, double targetRotation) {
    _isAnimatingOut = true;
    _slideAnimation = Tween<Offset>(begin: _dragOffset, end: targetOffset)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _rotateAnimation =
        Tween<double>(
          begin: _dragOffset.dx / 1000,
          end: targetRotation,
        ).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward(from: 0.0);
  }

  void _animateCardBack() {
    _isAnimatingOut = false;
    _slideAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _rotateAnimation = Tween<double>(begin: _dragOffset.dx / 1000, end: 0.0)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward(from: 0.0);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimatingOut) return;
    _dragOffset += details.delta;
    _dragOffsetListenable.value = _dragOffset;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimatingOut) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.28;
    final velocityX = details.velocity.pixelsPerSecond.dx;

    if (_dragOffset.dx > threshold || velocityX > 720) {
      _animateCardOut(Offset(screenWidth * 1.45, _dragOffset.dy), 0.25);
    } else if (_dragOffset.dx < -threshold || velocityX < -720) {
      _animateCardOut(Offset(-screenWidth * 1.45, _dragOffset.dy), -0.25);
    } else {
      _animateCardBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = widget.pets;
    final currentIndex = widget.currentIndex;

    if (currentIndex >= pets.length) {
      return _buildEmptyDeckState();
    }

    final currentPet = pets[currentIndex];
    final nextPet = (currentIndex + 1 < pets.length)
        ? pets[currentIndex + 1]
        : null;
    final thirdPet = (currentIndex + 2 < pets.length)
        ? pets[currentIndex + 2]
        : null;

    final screenWidth = MediaQuery.of(context).size.width;

    // Reserve top space so stacked card top edges & rounded corners peek cleanly
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Third Card in Stack (peeks 22px above active card, scaled to 0.90 -> 0.95)
          if (thirdPet != null)
            _buildStackedBackgroundCard(
              key: ValueKey('stack-3-${thirdPet.id}'),
              screenWidth: screenWidth,
              baseScale: 0.90,
              targetScale: 0.95,
              baseOffset: const Offset(0, -22),
              targetOffset: const Offset(0, -11),
              baseOpacity: 0.84,
              targetOpacity: 0.94,
              card: RepaintBoundary(
                child: PetProfileCard(
                  pet: thirdPet,
                  swipeProgress: 0.0,
                  showActionButtons: false,
                  enableHero: false,
                ),
              ),
            ),

          // 2. Second Card in Stack (peeks 11px above active card, scaled to 0.95 -> 1.0)
          if (nextPet != null)
            _buildStackedBackgroundCard(
              key: ValueKey('stack-2-${nextPet.id}'),
              screenWidth: screenWidth,
              baseScale: 0.95,
              targetScale: 1.0,
              baseOffset: const Offset(0, -11),
              targetOffset: Offset.zero,
              baseOpacity: 0.94,
              targetOpacity: 1.0,
              card: RepaintBoundary(
                child: PetProfileCard(
                  pet: nextPet,
                  swipeProgress: 0.0,
                  showActionButtons: false,
                  enableHero: false,
                ),
              ),
            ),

          // 3. Active Front Card with drag physics and embedded action buttons
          ValueListenableBuilder<Offset>(
            valueListenable: _dragOffsetListenable,
            builder: (context, dragOffset, _) {
              final swipeRatio = (dragOffset.dx / (screenWidth * 0.35)).clamp(
                -1.0,
                1.0,
              );
              return GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Transform.translate(
                  offset: dragOffset,
                  child: Transform.rotate(
                    angle: (_isAnimatingOut)
                        ? _rotateAnimation.value
                        : (dragOffset.dx / 1000) * 0.52,
                    child: RepaintBoundary(
                      child: PetProfileCard(
                        key: ValueKey('active-${currentPet.id}'),
                        pet: currentPet,
                        swipeProgress: swipeRatio,
                        showActionButtons: true,
                        enableHero: true,
                        onPassTap: swipeLeftProgrammatic,
                        onLikeTap: swipeRightProgrammatic,
                        onCardTap: () {
                          if (!_isAnimatingOut && _dragOffset.distance < 8) {
                            context.push('/pet/${currentPet.id}');
                          }
                        },
                        onOwnerTap: () {
                          if (!_isAnimatingOut &&
                              _dragOffset.distance < 8 &&
                              currentPet.ownerId != null &&
                              currentPet.ownerId!.isNotEmpty) {
                            context.push('/owner/${currentPet.ownerId}');
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStackedBackgroundCard({
    required Key key,
    required double screenWidth,
    required double baseScale,
    required double targetScale,
    required Offset baseOffset,
    required Offset targetOffset,
    required double baseOpacity,
    required double targetOpacity,
    required Widget card,
  }) {
    return ValueListenableBuilder<Offset>(
      key: key,
      valueListenable: _dragOffsetListenable,
      child: card,
      builder: (context, dragOffset, cardChild) {
        final t = (dragOffset.dx / (screenWidth * 0.35))
            .clamp(-1.0, 1.0)
            .abs();
        final currentScale = baseScale + (targetScale - baseScale) * t;
        final currentOffset = Offset.lerp(baseOffset, targetOffset, t)!;
        final currentOpacity = baseOpacity + (targetOpacity - baseOpacity) * t;

        return IgnorePointer(
          child: Transform.translate(
            offset: currentOffset,
            child: Transform.scale(
              scale: currentScale,
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: currentOpacity,
                child: cardChild,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDeckState() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE0E8E2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A2926).withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Layered botanical/pet illustration
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _sageGreen,
                      ),
                    ),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _deepTeal.withValues(alpha: 0.12),
                      ),
                      child: const Icon(
                        Icons.pets_rounded,
                        size: 34,
                        color: _deepTeal,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _softCoral,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                "You've discovered all nearby pets!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _darkText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Check back soon for new furry friends in your area, or tap below to explore passed profiles again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Color(0xFF5D6E6A),
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deepTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 14,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: widget.onReset,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text(
                  'Explore Again',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _warmCream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Resets skipped profiles',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7B8C87),
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
