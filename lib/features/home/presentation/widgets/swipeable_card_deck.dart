import 'package:flutter/material.dart';
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
  bool _isAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _animController.addListener(() {
      setState(() {
        _dragOffset = _slideAnimation.value;
      });
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isAnimatingOut) {
        final wasSwipeRight = _dragOffset.dx > 0;
        _isAnimatingOut = false;
        _dragOffset = Offset.zero;
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
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _rotateAnimation = Tween<double>(
      begin: _dragOffset.dx / 1000,
      end: targetRotation,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward(from: 0.0);
  }

  void _animateCardBack() {
    _isAnimatingOut = false;
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _rotateAnimation = Tween<double>(
      begin: _dragOffset.dx / 1000,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _animController.forward(from: 0.0);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimatingOut) return;
    setState(() {
      _dragOffset += details.delta;
    });
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
    final nextPet = (currentIndex + 1 < pets.length) ? pets[currentIndex + 1] : null;

    final screenWidth = MediaQuery.of(context).size.width;
    final swipeRatio = (_dragOffset.dx / (screenWidth * 0.35)).clamp(-1.0, 1.0);
    final absRatio = swipeRatio.abs();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Next Card in Stack (peeking underneath)
            if (nextPet != null)
              Transform.scale(
                scale: 0.93 + (0.07 * absRatio),
                child: Transform.translate(
                  offset: Offset(0, 14 * (1.0 - absRatio)),
                  child: Opacity(
                    opacity: 0.80 + (0.20 * absRatio),
                    child: PetProfileCard(
                      pet: nextPet,
                      swipeProgress: 0.0,
                    ),
                  ),
                ),
              ),

            // 2. Active Front Card
            GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Transform.translate(
                offset: _dragOffset,
                child: Transform.rotate(
                  angle: (_isAnimatingOut)
                      ? _rotateAnimation.value
                      : (_dragOffset.dx / 1000) * 0.7,
                  child: PetProfileCard(
                    pet: currentPet,
                    swipeProgress: swipeRatio,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyDeckState() {
    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
    );
  }
}
