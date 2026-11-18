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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. PASS BUTTON (X icon, Left, Clean Outline)
          GestureDetector(
            onTapDown: (_) {
              if (widget.enabled) setState(() => _passScale = 0.88);
            },
            onTapUp: (_) {
              if (widget.enabled) {
                setState(() => _passScale = 1.0);
                widget.onPass();
              }
            },
            onTapCancel: () {
              if (widget.enabled) setState(() => _passScale = 1.0);
            },
            child: AnimatedScale(
              scale: _passScale,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.close, color: AppColors.error, size: 32),
                ),
              ),
            ),
          ),

          // 2. LIKE BUTTON (Heart icon, Right, Attractive Gradient)
          GestureDetector(
            onTapDown: (_) {
              if (widget.enabled) setState(() => _likeScale = 0.88);
            },
            onTapUp: (_) {
              if (widget.enabled) {
                setState(() => _likeScale = 1.0);
                widget.onLike();
              }
            },
            onTapCancel: () {
              if (widget.enabled) setState(() => _likeScale = 1.0);
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), AppColors.terracotta],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.terracotta.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.favorite, color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
