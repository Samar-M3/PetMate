import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/match_conversation_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/entities/chat_entities.dart';

// ---------------------------------------------------------------------------
// Current Authenticated Firebase UID
// ---------------------------------------------------------------------------

final currentFirebaseUidProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.user?.firebaseUid ?? '';
});

// ---------------------------------------------------------------------------
// Firestore Conversations Stream
// ---------------------------------------------------------------------------

final firestoreConversationsStreamProvider =
    StreamProvider<List<FirestoreConversation>>((ref) {
  final myUid = ref.watch(currentFirebaseUidProvider);
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchConversations(myUid);
});

// ---------------------------------------------------------------------------
// Raw PostgreSQL Matches List Provider
// ---------------------------------------------------------------------------

final postgresMatchesProvider =
    FutureProvider<List<MatchConversationModel>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getMatches();
});

// ---------------------------------------------------------------------------
// Joined Conversations List (Matches + Real-time Firestore State)
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
  @override
  ChatConversationsState build() {
    final matchesAsync = ref.watch(postgresMatchesProvider);
    final firestoreAsync = ref.watch(firestoreConversationsStreamProvider);
    final myUid = ref.watch(currentFirebaseUidProvider);

    if (matchesAsync.isLoading && !matchesAsync.hasValue) {
      return const ChatConversationsState(isLoading: true);
    }

    if (matchesAsync.hasError) {
      return ChatConversationsState(
        isLoading: false,
        errorMessage: matchesAsync.error.toString(),
      );
    }

    final matches = matchesAsync.value ?? [];
    final firestoreConvs = firestoreAsync.value ?? [];
    final firestoreMap = {for (final c in firestoreConvs) c.matchId: c};

    // Join PostgreSQL match data with real-time Firestore conversation updates
    final joined = matches.map((match) {
      final fConv = firestoreMap[match.matchId];
      if (fConv == null) {
        return match;
      }

      return match.copyWith(
        lastMessage: fConv.lastMessageText ?? match.lastMessage,
        lastMessageTime: fConv.lastMessageAt ?? match.lastMessageTime,
        unreadCount: fConv.unreadFor(myUid),
      );
    }).toList();

    // Sort descending by latest message / match time
    joined.sort((a, b) {
      final timeA = a.lastMessageTime ?? a.matchedAt;
      final timeB = b.lastMessageTime ?? b.matchedAt;
      return timeB.compareTo(timeA);
    });

    return ChatConversationsState(
      conversations: joined,
      isLoading: false,
    );
  }

  Future<void> loadConversations() async {
    ref.invalidate(postgresMatchesProvider);
  }
}

final chatConversationsProvider =
    NotifierProvider<ChatConversationsNotifier, ChatConversationsState>(
  ChatConversationsNotifier.new,
);

// ---------------------------------------------------------------------------
// Total Unread Count Provider (for Badges)
// ---------------------------------------------------------------------------

final unreadChatsCountProvider = Provider<int>((ref) {
  final convsState = ref.watch(chatConversationsProvider);
  int count = 0;
  for (final c in convsState.conversations) {
    count += c.unreadCount;
  }
  return count;
});

// ---------------------------------------------------------------------------
// Single Conversation Document Stream
// ---------------------------------------------------------------------------

final singleConversationProvider =
    StreamProvider.family<FirestoreConversation?, String>((ref, matchId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchConversation(matchId);
});

// ---------------------------------------------------------------------------
// Messages Stream Provider (family by matchId and pagination limit)
// ---------------------------------------------------------------------------

final messagesStreamProvider =
    StreamProvider.family<List<FirestoreMessage>, ({String matchId, int limit})>(
  (ref, arg) {
    final repo = ref.watch(chatRepositoryProvider);
    return repo.watchMessages(arg.matchId, limit: arg.limit);
  },
);
