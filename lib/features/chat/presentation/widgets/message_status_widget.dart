import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/chat_entities.dart';

class MessageStatusWidget extends StatelessWidget {
  final MessageStatus status;
  final double size;

  const MessageStatusWidget({
    super.key,
    required this.status,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MessageStatus.pending => Icon(
          Icons.access_time_rounded,
          size: size - 2,
          color: AppColors.textMuted,
          semanticLabel: 'Sending',
        ),
      MessageStatus.sent => Icon(
          Icons.done_rounded,
          size: size,
          color: AppColors.textMuted,
          semanticLabel: 'Sent',
        ),
      MessageStatus.delivered => SizedBox(
          width: size + 4,
          height: size,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: Icon(Icons.done_rounded, size: size, color: AppColors.textMuted),
              ),
              Positioned(
                left: size * 0.4,
                child: Icon(Icons.done_rounded, size: size, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      MessageStatus.read => SizedBox(
          width: size + 4,
          height: size,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: Icon(Icons.done_rounded, size: size, color: const Color(0xFF2196F3)),
              ),
              Positioned(
                left: size * 0.4,
                child: Icon(Icons.done_rounded, size: size, color: const Color(0xFF2196F3)),
              ),
            ],
          ),
        ),
      MessageStatus.failed => Icon(
          Icons.error_outline_rounded,
          size: size,
          color: AppColors.error,
          semanticLabel: 'Failed',
        ),
    };
  }
}
