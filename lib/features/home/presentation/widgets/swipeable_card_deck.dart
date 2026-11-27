import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/storage_service.dart';
import '../../domain/entities/discovery_pet.dart';
import 'pet_profile_card.dart';

class SwipeableCardDeck extends ConsumerStatefulWidget {
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
  ConsumerState<SwipeableCardDeck> createState() => SwipeableCardDeckState();
}

class SwipeableCardDeckState extends ConsumerState<SwipeableCardDeck>
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
  bool _showTutorialHint = false;
  bool _tutorialRunning = false;
  Timer? _tutorialTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slideAnimation = AlwaysStoppedAnimation(Offset.zero);
    _rotateAnimation = const AlwaysStoppedAnimation(0.0);

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRunFirstTimeTutorial();
    });
  }

  @override
  void didUpdateWidget(covariant SwipeableCardDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pets.isEmpty && widget.pets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeRunFirstTimeTutorial();
      });
    }
  }

  Future<void> _maybeRunFirstTimeTutorial() async {
    if (!mounted ||
        _tutorialRunning ||
        widget.currentIndex >= widget.pets.length) {
      return;
    }

    final storage = ref.read(storageServiceProvider);
    if (storage.hasSeenDiscoverSwipeTutorial) return;

    _tutorialRunning = true;
    await storage.setDiscoverSwipeTutorialSeen();

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted || _isAnimatingOut || _dragOffset.dx.abs() > 4) {
      _tutorialRunning = false;
      return;
    }

    setState(() => _showTutorialHint = true);

    // Subtle right nudge (Like preview)
    await _animateTutorialNudge(const Offset(54, -4), 0.05);
    if (!mounted || _isAnimatingOut) return;
    await _animateTutorialNudge(Offset.zero, 0.0);
    if (!mounted || _isAnimatingOut) return;

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted || _isAnimatingOut) return;

    // Subtle left nudge (Pass preview)
    await _animateTutorialNudge(const Offset(-54, -4), -0.05);
    if (!mounted || _isAnimatingOut) return;
    await _animateTutorialNudge(Offset.zero, 0.0);

    _tutorialRunning = false;
    _tutorialTimer?.cancel();
    _tutorialTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showTutorialHint = false);
      }
    });
  }

  Future<void> _animateTutorialNudge(Offset target, double rot) async {
    if (!mounted) return;
    _slideAnimation = Tween<Offset>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );
    _rotateAnimation = Tween<double>(
      begin: _dragOffset.dx / 1000,
      end: rot,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );
    await _animController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _tutorialTimer?.cancel();
    _animController.dispose();
    _dragOffsetListenable.dispose();
    super.dispose();
  }

  void swipeRightProgrammatic() {
    if (_isAnimatingOut || widget.currentIndex >= widget.pets.length) return;
    _animateCardOut(const Offset(520, 24), 0.24);
  }

  void swipeLeftProgrammatic() {
    if (_isAnimatingOut || widget.currentIndex >= widget.pets.length) return;
    _animateCardOut(const Offset(-520, 24), -0.24);
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
    if (_showTutorialHint) {
      _tutorialTimer?.cancel();
      setState(() => _showTutorialHint = false);
    }
    _dragOffset += details.delta;
    _dragOffsetListenable.value = _dragOffset;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimatingOut) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.28;
    final velocityX = details.velocity.pixelsPerSecond.dx;

    if (_dragOffset.dx > threshold || velocityX > 720) {
      _animateCardOut(Offset(screenWidth * 1.45, _dragOffset.dy), 0.24);
    } else if (_dragOffset.dx < -threshold || velocityX < -720) {
      _animateCardOut(Offset(-screenWidth * 1.45, _dragOffset.dy), -0.24);
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

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Third Card in Stack
          if (thirdPet != null)
            _buildStackedBackgroundCard(
              key: ValueKey('stack-3-${thirdPet.id}'),
              screenWidth: screenWidth,
              baseScale: 0.91,
              targetScale: 0.955,
              baseOffset: const Offset(0, -18),
              targetOffset: const Offset(0, -9),
              baseOpacity: 0.84,
              targetOpacity: 0.94,
              card: RepaintBoundary(
                child: PetProfileCard(
                  pet: thirdPet,
                  swipeProgress: 0.0,
                  enableHero: false,
                ),
              ),
            ),

          // 2. Second Card in Stack
          if (nextPet != null)
            _buildStackedBackgroundCard(
              key: ValueKey('stack-2-${nextPet.id}'),
              screenWidth: screenWidth,
              baseScale: 0.955,
              targetScale: 1.0,
              baseOffset: const Offset(0, -9),
              targetOffset: Offset.zero,
              baseOpacity: 0.94,
              targetOpacity: 1.0,
              card: RepaintBoundary(
                child: PetProfileCard(
                  pet: nextPet,
                  swipeProgress: 0.0,
                  enableHero: false,
                ),
              ),
            ),

          // 3. Active Front Card with drag physics (no permanent buttons)
          ValueListenableBuilder<Offset>(
            valueListenable: _dragOffsetListenable,
            builder: (context, dragOffset, _) {
              final swipeRatio = (dragOffset.dx / (screenWidth * 0.32)).clamp(
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
                        : (dragOffset.dx / 1000) * 0.45,
                    child: RepaintBoundary(
                      child: PetProfileCard(
                        key: ValueKey('active-${currentPet.id}'),
                        pet: currentPet,
                        swipeProgress: swipeRatio,
                        enableHero: true,
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

          // 4. Subtle first-time user swipe tutorial hint
          if (_showTutorialHint)
            Positioned(
              top: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _darkText.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Swipe right to like · Swipe left to pass',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
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
                    const Positioned(
                      top: 12,
                      right: 12,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: _softCoral,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'You\'re all caught up',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: _darkText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Check back soon for new companions nearby, or refresh to see pets you may have missed.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF6B7B76),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deepTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                onPressed: widget.onReset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Refresh Feed',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _warmCream,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'New profiles are added daily',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: _deepTeal,
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
