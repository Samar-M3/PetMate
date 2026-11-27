import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
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
    with TickerProviderStateMixin {
  static const Duration _displayDuration = Duration(seconds: 5);
  static const Color _primaryTeal = Color(0xFF0B625B);
  static const Color _coralAccent = Color(0xFFE8795B);
  static const Color _charcoalText = Color(0xFF26332F);
  static const Color _mutedText = Color(0xFF7B8880);
  static const Color _softBorder = Color(0xFFE5E8E2);

  late final AnimationController _entranceController;
  late final AnimationController _progressController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: _displayDuration,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _entranceController.forward();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LikeSuccessNotification oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.eventId != widget.event.eventId) {
      _startTimer();
      _entranceController.forward(from: 0.4);
    }
  }

  void _startTimer() {
    _dismissTimer?.cancel();
    _progressController.forward(from: 0.0);
    _dismissTimer = Timer(_displayDuration, () {
      if (mounted) {
        _dismissSmoothly();
      }
    });
  }

  Future<void> _dismissSmoothly() async {
    _dismissTimer?.cancel();
    _progressController.stop();
    try {
      await _entranceController.reverse();
    } catch (_) {}
    if (mounted) {
      widget.onDismiss();
    }
  }

  void _handleAction() {
    _dismissTimer?.cancel();
    _progressController.stop();
    if (widget.event.matched) {
      widget.onOpenMatchChat();
    } else {
      widget.onAddMessage();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entranceController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMatch = widget.event.matched;
    final hasImage = (widget.event.petImageUrl ?? '').trim().isNotEmpty;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dismissible(
          key: ValueKey('dismiss-${widget.event.eventId}'),
          direction: DismissDirection.horizontal,
          onDismissed: (_) {
            _dismissTimer?.cancel();
            widget.onDismiss();
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleAction,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _softBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Row(
                        children: [
                          // Pet thumbnail or subtle status icon
                          if (hasImage)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: AppNetworkImage(
                                  imageUrl: widget.event.petImageUrl,
                                  fit: BoxFit.cover,
                                  fallbackIcon: isMatch
                                      ? Icons.auto_awesome_outlined
                                      : Icons.favorite_border_rounded,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (isMatch ? _primaryTeal : _coralAccent)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isMatch
                                    ? Icons.auto_awesome_outlined
                                    : Icons.favorite_border_rounded,
                                color: isMatch ? _primaryTeal : _coralAccent,
                                size: 20,
                              ),
                            ),
                          const SizedBox(width: 12),

                          // Title & clear action prompt
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMatch
                                      ? 'Matched with ${widget.event.petName}'
                                      : 'Liked ${widget.event.petName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _charcoalText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isMatch
                                      ? 'Tap to open chat'
                                      : 'Tap to send an intro message',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _mutedText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Primary action button
                          ElevatedButton(
                            onPressed: _handleAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryTeal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              isMatch ? 'Chat' : 'Message',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Subtle 5-second countdown bar
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) {
                        return LinearProgressIndicator(
                          value: 1.0 - _progressController.value,
                          minHeight: 2.5,
                          backgroundColor: _softBorder.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isMatch ? _primaryTeal : _coralAccent,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
