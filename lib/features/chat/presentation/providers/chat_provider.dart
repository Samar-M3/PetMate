import 'package:firebase_auth/firebase_auth.dart';
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
  final directUid =
      authState.firebaseUser?.uid ??
      FirebaseAuth.instance.currentUser?.uid ??
      authState.user?.firebaseUid ??
      '';
  return directUid;
});

// ---------------------------------------------------------------------------
// Firestore Conversations Stream
// ---------------------------------------------------------------------------

final firestoreConversationsStreamProvider =
    StreamProvider.autoDispose<List<FirestoreConversation>>((ref) {
      final myUid = ref.watch(currentFirebaseUidProvider);
      final repo = ref.watch(chatRepositoryProvider);
      return repo.watchConversations(myUid);
    });

// ---------------------------------------------------------------------------
// Raw PostgreSQL Matches List Provider
// ---------------------------------------------------------------------------

final postgresMatchesProvider = FutureProvider<List<MatchConversationModel>>((
  ref,
) async {
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

      final otherUid = fConv.participantUids.firstWhere(
        (uid) => uid != myUid,
        orElse: () => '',
      );

      return match.copyWith(
        lastMessage: fConv.lastMessageText ?? match.lastMessage,
        lastMessageTime: fConv.lastMessageAt ?? match.lastMessageTime,
        unreadCount: fConv.unreadFor(myUid),
        otherFirebaseUid: otherUid.isNotEmpty ? otherUid : null,
      );
    }).toList();

    // Sort descending by latest message / match time
    joined.sort((a, b) {
      final timeA = a.lastMessageTime ?? a.matchedAt;
      final timeB = b.lastMessageTime ?? b.matchedAt;
      return timeB.compareTo(timeA);
    });

    return ChatConversationsState(conversations: joined, isLoading: false);
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

final singleConversationProvider = StreamProvider.autoDispose
    .family<FirestoreConversation?, String>((ref, matchId) {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.watchConversation(matchId);
    });

// ---------------------------------------------------------------------------
// Messages Stream Provider (family by matchId and pagination limit)
// ---------------------------------------------------------------------------

final messagesStreamProvider = StreamProvider.autoDispose
    .family<List<FirestoreMessage>, ({String matchId, int limit})>((ref, arg) {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.watchMessages(arg.matchId, limit: arg.limit);
    });

// ---------------------------------------------------------------------------
// Media URL Cache Provider
// ---------------------------------------------------------------------------

class CachedMediaUrl {
  final String url;
  final DateTime expiresAt;
  const CachedMediaUrl({required this.url, required this.expiresAt});
}

class MediaUrlCache extends Notifier<Map<String, CachedMediaUrl>> {
  final Map<String, Future<String?>> _inFlightSingle = {};
  final Map<String, Future<Map<String, String>>> _inFlightBatch = {};

  @override
  Map<String, CachedMediaUrl> build() => {};

  Future<String?> getUrl(
    String conversationId,
    String publicId, {
    String? kind,
    bool isThumbnail = false,
  }) async {
    final cached = state[publicId];
    if (cached != null &&
        cached.expiresAt.isAfter(
          DateTime.now().add(const Duration(minutes: 5)),
        )) {
      return cached.url;
    }

    final existing = _inFlightSingle[publicId];
    if (existing != null) {
      return existing;
    }

    final future = _fetchSingle(
      conversationId,
      publicId,
      kind: kind,
      isThumbnail: isThumbnail,
    );
    _inFlightSingle[publicId] = future;
    try {
      return await future;
    } finally {
      _inFlightSingle.remove(publicId);
    }
  }

  Future<String?> _fetchSingle(
    String conversationId,
    String publicId, {
    String? kind,
    bool isThumbnail = false,
  }) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final urls = await repo.getMediaUrls(
        conversationId,
        [publicId],
        items: [
          {
            'publicId': publicId,
            'kind': kind ?? 'image',
            'thumbnail': isThumbnail,
          },
        ],
      );
      final url = urls[publicId];
      if (url != null) {
        state = {
          ...state,
          publicId: CachedMediaUrl(
            url: url,
            expiresAt: DateTime.now().add(const Duration(minutes: 55)),
          ),
        };
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> getUrls(
    String conversationId,
    List<String> publicIds, {
    List<Map<String, dynamic>>? items,
  }) async {
    final needed = <String>[];
    final result = <String, String>{};

    for (final id in publicIds) {
      final cached = state[id];
      if (cached != null &&
          cached.expiresAt.isAfter(
            DateTime.now().add(const Duration(minutes: 5)),
          )) {
        result[id] = cached.url;
      } else {
        needed.add(id);
      }
    }

    if (needed.isEmpty) {
      return result;
    }

    final batchKey = needed.join(',');
    final existing = _inFlightBatch[batchKey];
    if (existing != null) {
      final fetched = await existing;
      result.addAll(fetched);
      return result;
    }

    final future = _fetchBatch(conversationId, needed, items: items);
    _inFlightBatch[batchKey] = future;
    try {
      final fetched = await future;
      result.addAll(fetched);
      return result;
    } finally {
      _inFlightBatch.remove(batchKey);
    }
  }

  Future<Map<String, String>> _fetchBatch(
    String conversationId,
    List<String> needed, {
    List<Map<String, dynamic>>? items,
  }) async {
    final fetched = <String, String>{};
    try {
      final repo = ref.read(chatRepositoryProvider);
      final neededItems = items
          ?.where((it) => needed.contains(it['publicId']))
          .toList();
      final urls = await repo.getMediaUrls(
        conversationId,
        needed,
        items: neededItems,
      );
      final newState = Map<String, CachedMediaUrl>.from(state);
      for (final entry in urls.entries) {
        fetched[entry.key] = entry.value;
        newState[entry.key] = CachedMediaUrl(
          url: entry.value,
          expiresAt: DateTime.now().add(const Duration(minutes: 55)),
        );
      }
      state = newState;
    } catch (_) {
      // Return what was fetched so far
    }
    return fetched;
  }

  void clear() => state = {};
}

final mediaUrlCacheProvider =
    NotifierProvider<MediaUrlCache, Map<String, CachedMediaUrl>>(
      MediaUrlCache.new,
    );
