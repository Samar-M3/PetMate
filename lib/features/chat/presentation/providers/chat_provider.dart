import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_conversation_model.dart';
import '../../data/repositories/chat_repository.dart';

// ---------------------------------------------------------------------------
// Conversations list state & notifier
// ---------------------------------------------------------------------------

class ChatConversationsState {
  final List<MatchConversationModel> conversations;
  final bool isLoading;
  final String? errorMessage;

  const ChatConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ChatConversationsState copyWith({
    List<MatchConversationModel>? conversations,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChatConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChatConversationsNotifier extends Notifier<ChatConversationsState> {
  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  @override
  ChatConversationsState build() {
    Future.microtask(() => loadConversations());
    return const ChatConversationsState(isLoading: true);
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getMatches();
      state = state.copyWith(conversations: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void updateLastMessage(String matchId, String text) {
    final updated = state.conversations.map((conv) {
      if (conv.matchId == matchId) {
        return conv.copyWith(
          lastMessage: text,
          lastMessageTime: DateTime.now(),
        );
      }
      return conv;
    }).toList();
    state = state.copyWith(conversations: updated);
  }
}

final chatConversationsProvider =
    NotifierProvider<ChatConversationsNotifier, ChatConversationsState>(
  ChatConversationsNotifier.new,
);

// ---------------------------------------------------------------------------
// Active 1-on-1 chat room (family provider keyed by match)
// ---------------------------------------------------------------------------

class ActiveChatNotifier extends Notifier<List<ChatMessageModel>> {
  final MatchConversationModel match;

  ActiveChatNotifier(this.match);

  @override
  List<ChatMessageModel> build() {
    final now = DateTime.now();
    return [
      ChatMessageModel(
        id: 'msg-1',
        senderId: match.otherOwner.id,
        text:
            'Hello! I saw ${match.myPet.name} on PetMate! Such an adorable pet! 🐾',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
        isMine: false,
      ),
      ChatMessageModel(
        id: 'msg-2',
        senderId: 'my-user-id',
        text:
            'Hi ${match.otherOwner.name}! Thank you! ${match.otherPet.name} is super cute too! How old are they?',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 45)),
        isMine: true,
      ),
      ChatMessageModel(
        id: 'msg-3',
        senderId: match.otherOwner.id,
        text: match.lastMessage ??
            'Would love to set up a weekend playdate at the park if you are free!',
        createdAt:
            match.lastMessageTime ?? now.subtract(const Duration(minutes: 20)),
        isMine: false,
      ),
    ];
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final newMsg = ChatMessageModel(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'my-user-id',
      text: text.trim(),
      createdAt: DateTime.now(),
      isMine: true,
      isRead: true,
    );

    state = [...state, newMsg];

    // Update conversation list preview
    ref
        .read(chatConversationsProvider.notifier)
        .updateLastMessage(match.matchId, text.trim());

    // Friendly auto-reply simulation after 1.4 seconds
    Timer(const Duration(milliseconds: 1400), () {
      final replies = [
        'That sounds like a wonderful plan! ${match.otherPet.name} will be thrilled! 🐕✨',
        'Awesome! Saturday afternoon around 4 PM works great for us at the park.',
        'Sounds good! Let\'s coordinate closer to the time. See you soon! 🐾',
      ];
      final randomReply = (replies..shuffle()).first;

      final replyMsg = ChatMessageModel(
        id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
        senderId: match.otherOwner.id,
        text: randomReply,
        createdAt: DateTime.now(),
        isMine: false,
      );

      state = [...state, replyMsg];

      ref
          .read(chatConversationsProvider.notifier)
          .updateLastMessage(match.matchId, randomReply);
    });
  }
}

final activeChatProvider = NotifierProvider.family<ActiveChatNotifier,
    List<ChatMessageModel>, MatchConversationModel>(
  (match) => ActiveChatNotifier(match),
);
