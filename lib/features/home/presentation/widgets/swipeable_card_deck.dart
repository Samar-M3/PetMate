import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
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
    _animateCardOut(const Offset(500, 20), 0.35);
  }

  void swipeLeftProgrammatic() {
    if (_isAnimatingOut || widget.currentIndex >= widget.pets.length) return;
    _animateCardOut(const Offset(-500, 20), -0.35);
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
          CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
        );

    _rotateAnimation = Tween<double>(begin: _dragOffset.dx / 1000, end: 0.0)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
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
    final threshold = screenWidth * 0.30;
    final velocityX = details.velocity.pixelsPerSecond.dx;

    if (_dragOffset.dx > threshold || velocityX > 750) {
      _animateCardOut(Offset(screenWidth * 1.4, _dragOffset.dy), 0.3);
    } else if (_dragOffset.dx < -threshold || velocityX < -750) {
      _animateCardOut(Offset(-screenWidth * 1.4, _dragOffset.dy), -0.3);
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
    final fourthPet = (currentIndex + 3 < pets.length)
        ? pets[currentIndex + 3]
        : null;

    final screenWidth = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 0. Base card deck background / decorative placeholder base
            if (nextPet == null)
              Container(
                width: constraints.maxWidth * 0.96,
                height: constraints.maxHeight * 0.96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.pets_rounded,
                    size: 64,
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
              ),

            // 1. Fourth Card in Stack (deepest background card)
            if (fourthPet != null)
              _buildDeckBackground(
                screenWidth: screenWidth,
                card: RepaintBoundary(
                  child: PetProfileCard(pet: fourthPet, swipeProgress: 0.0),
                ),
                scale: 0.86,
                scaleRange: 0.06,
                horizontalOffset: 20,
                verticalOffset: 26,
                opacity: 0.38,
                opacityRange: 0.32,
                shadowAlpha: 0.05,
                shadowBlur: 12,
                shadowOffset: const Offset(0, 8),
              ),

            // 2. Third Card in Stack
            if (thirdPet != null)
              _buildDeckBackground(
                screenWidth: screenWidth,
                card: RepaintBoundary(
                  child: PetProfileCard(pet: thirdPet, swipeProgress: 0.0),
                ),
                scale: 0.90,
                scaleRange: 0.05,
                horizontalOffset: 14,
                verticalOffset: 19,
                opacity: 0.52,
                opacityRange: 0.30,
                shadowAlpha: 0.06,
                shadowBlur: 14,
                shadowOffset: const Offset(0, 10),
              ),

            // 3. Next Card in Stack (peeking directly underneath active card)
            if (nextPet != null)
              _buildDeckBackground(
                screenWidth: screenWidth,
                card: RepaintBoundary(
                  child: PetProfileCard(pet: nextPet, swipeProgress: 0.0),
                ),
                scale: 0.93,
                scaleRange: 0.07,
                horizontalOffset: 8,
                verticalOffset: 11,
                opacity: 0.75,
                opacityRange: 0.25,
                shadowAlpha: 0.08,
                shadowBlur: 16,
                shadowOffset: const Offset(0, 8),
              ),

            // 3. Active Front Card with dynamic drag feedback
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
                          : (dragOffset.dx / 1000) * 0.7,
                      child: RepaintBoundary(
                        child: PetProfileCard(
                          pet: currentPet,
                          swipeProgress: swipeRatio,
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
        );
      },
    );
  }

  Widget _buildDeckBackground({
    required double screenWidth,
    required Widget card,
    required double scale,
    required double scaleRange,
    required double horizontalOffset,
    required double verticalOffset,
    required double opacity,
    required double opacityRange,
    required double shadowAlpha,
    required double shadowBlur,
    required Offset shadowOffset,
  }) {
    return ValueListenableBuilder<Offset>(
      valueListenable: _dragOffsetListenable,
      child: card,
      builder: (context, dragOffset, cardChild) {
        final swipeRatio = (dragOffset.dx / (screenWidth * 0.35))
            .clamp(-1.0, 1.0)
            .abs();
        return IgnorePointer(
          child: Transform.scale(
            scale: scale + (scaleRange * swipeRatio),
            child: Transform.translate(
              offset: Offset(
                horizontalOffset * (1.0 - swipeRatio),
                verticalOffset * (1.0 - swipeRatio),
              ),
              child: Opacity(
                opacity: opacity + (opacityRange * swipeRatio),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: shadowAlpha),
                        blurRadius: shadowBlur,
                        offset: shadowOffset,
                      ),
                    ],
                  ),
                  child: cardChild,
                ),
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
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'All Caught Up!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You have reviewed all available pet profiles in your area for now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 3,
                ),
                onPressed: widget.onReset,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                label: const Text(
                  'Explore Again',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
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
