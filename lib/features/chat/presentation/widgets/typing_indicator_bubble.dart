import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class TypingIndicatorBubble extends StatefulWidget {
  const TypingIndicatorBubble({super.key});

  @override
  State<TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  final delay = index * 0.2;
                  final value = ((_animController.value - delay) % 1.0).clamp(0.0, 1.0);
                  // Sine curve wave
                  final scale = 0.6 + 0.4 * (1.0 - (value - 0.5).abs() * 2);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.3 + 0.7 * scale),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}
