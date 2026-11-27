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
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
      child: AnimatedOpacity(
        opacity: isEnabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 160),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. PASS BUTTON (Quiet, tactile surface with clean semantic accent)
            GestureDetector(
              onTapDown: (_) {
                if (isEnabled) setState(() => _passScale = 0.94);
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
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.error,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),

            // 2. LIKE BUTTON (Terracotta accent with clear contrast, no neon glow)
            GestureDetector(
              onTapDown: (_) {
                if (isEnabled) setState(() => _likeScale = 0.94);
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
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.terracotta,
                    border: Border.all(
                      color: AppColors.terracottaDark.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 28,
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
