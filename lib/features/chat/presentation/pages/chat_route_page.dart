import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/chat_provider.dart';
import 'chat_detail_page.dart';

class ChatRoutePage extends ConsumerWidget {
  final String matchId;

  const ChatRoutePage({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(chatConversationsProvider);

    if (convsAsync.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F5F0),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final match = convsAsync.conversations
        .where((c) => c.matchId == matchId)
        .firstOrNull;

    if (match == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F5F0),
        appBar: AppBar(
          title: const Text('Chat'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Conversation Unavailable',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This conversation may have ended or was removed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => context.go('/'),
                  child: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChatDetailPage(match: match);
  }
}
