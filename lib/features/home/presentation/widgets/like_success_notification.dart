import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/discovery_provider.dart';

class LikeSuccessNotification extends StatefulWidget {
  final LikeSuccessEvent event;
  final VoidCallback onAddMessage;
  final VoidCallback onOpenMatchChat;
  final VoidCallback onDismiss;

  const LikeSuccessNotification({
    super.key,
    required this.event,
    required this.onAddMessage,
    required this.onOpenMatchChat,
    required this.onDismiss,
  });

  @override
  State<LikeSuccessNotification> createState() =>
      _LikeSuccessNotificationState();
}

class _LikeSuccessNotificationState extends State<LikeSuccessNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LikeSuccessNotification oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.eventId != widget.event.eventId) {
      _startTimer();
      _controller.forward(from: 0.4);
    }
  }

  void _startTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) {
        _dismissSmoothly();
      }
    });
  }

  Future<void> _dismissSmoothly() async {
    _dismissTimer?.cancel();
    try {
      await _controller.reverse();
    } catch (_) {}
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMatch = widget.event.matched;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF0F5C57),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8A65).withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMatch ? Icons.auto_awesome : Icons.favorite_rounded,
                    color: const Color(0xFFFF8A65),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMatch
                            ? "It's a match with ${widget.event.petName}! 🎉"
                            : 'You liked ${widget.event.petName}! ❤️',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          _dismissTimer?.cancel();
                          if (isMatch) {
                            widget.onOpenMatchChat();
                          } else {
                            widget.onAddMessage();
                          }
                        },
                        child: Text(
                          isMatch
                              ? 'Tap to say hello in chat'
                              : 'Want to introduce yourself? Add a message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFB199),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFFFB199),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () {
                    _dismissTimer?.cancel();
                    if (isMatch) {
                      widget.onOpenMatchChat();
                    } else {
                      widget.onAddMessage();
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A65),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isMatch ? 'Chat' : 'Add',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
}
