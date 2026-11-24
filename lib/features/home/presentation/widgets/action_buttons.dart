import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class ActionButtons extends StatefulWidget {
  final VoidCallback onPass;
  final VoidCallback onLike;
  final bool enabled;

  const ActionButtons({
    super.key,
    required this.onPass,
    required this.onLike,
    this.enabled = true,
  });

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons> {
  double _passScale = 1.0;
  double _likeScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: AnimatedOpacity(
        opacity: isEnabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. PASS BUTTON (X icon, Clean Tactile Surface with Crimson Accent)
            GestureDetector(
              onTapDown: (_) {
                if (isEnabled) setState(() => _passScale = 0.86);
              },
              onTapUp: (_) {
                if (isEnabled) {
                  setState(() => _passScale = 1.0);
                  widget.onPass();
                }
              },
              onTapCancel: () {
                if (isEnabled) setState(() => _passScale = 1.0);
              },
              child: AnimatedScale(
                scale: _passScale,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close_rounded,
                      color: Color(0xFFFF4757),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),

            // 2. LIKE BUTTON (Hero Heart icon, Radiant Sunset Gradient)
            GestureDetector(
              onTapDown: (_) {
                if (isEnabled) setState(() => _likeScale = 0.88);
              },
              onTapUp: (_) {
                if (isEnabled) {
                  setState(() => _likeScale = 1.0);
                  widget.onLike();
                }
              },
              onTapCancel: () {
                if (isEnabled) setState(() => _likeScale = 1.0);
              },
              child: AnimatedScale(
                scale: _likeScale,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF5E62),
                        Color(0xFFE56345),
                        AppColors.terracotta,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5E62).withValues(alpha: 0.40),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.terracottaDark.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 34,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
