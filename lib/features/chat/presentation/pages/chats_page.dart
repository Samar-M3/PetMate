import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../home/presentation/pages/requests_page.dart';
import '../../../home/presentation/providers/requests_provider.dart';
import '../../data/models/match_conversation_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_settings_provider.dart';
import '../widgets/chat_privacy_settings_sheet.dart';
import '../widgets/date_separator.dart';
import '../widgets/matched_pair_avatar.dart';
import '../widgets/message_status_widget.dart';
import 'chat_detail_page.dart';

class ChatsPage extends ConsumerWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentFirebaseUidProvider);

    // Mark delivery watermark for all conversations where new messages have
    // arrived while the user is on this screen (not inside a specific chat).
    // This advances deliveredAt so the sender sees grey double-ticks.
    ref.listen<AsyncValue<List<FirestoreConversation>>>(
      firestoreConversationsStreamProvider,
      (_, next) {
        final convs = next.value;
        if (convs == null || myUid.isEmpty) return;
        final repo = ref.read(chatRepositoryProvider);
        for (final conv in convs) {
          if (!conv.participantUids.contains(myUid)) continue;
          if (conv.status != 'ACTIVE') continue;
          final lastMsgAt = conv.lastMessageAt;
          if (lastMsgAt == null ||
              conv.lastMessageSenderUid == null ||
              conv.lastMessageSenderUid == myUid) {
            continue;
          }
          // Only mark delivered if there's a message we haven't delivered yet
          final myDelivered = conv.deliveredAtFor(myUid);
          if (myDelivered == null || lastMsgAt.isAfter(myDelivered)) {
            repo.markDelivered(conv.matchId, myUid, lastMessageAt: lastMsgAt);
          }
        }
      },
    );

    final conversationsState = ref.watch(chatConversationsProvider);
    final requestsState = ref.watch(requestsProvider);
    final pendingCount = requestsState.pendingCount;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Header with Title and "Requests" Button in Top-Right
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Matches & Conversations',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Top Right Action Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        tooltip: 'Chat Privacy',
                        onPressed: () => showChatPrivacySettingsSheet(context),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RequestsPage(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: pendingCount > 0
                                  ? AppColors.terracotta
                                  : AppColors.border,
                              width: pendingCount > 0 ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 18,
                                color: pendingCount > 0
                                    ? AppColors.terracotta
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Requests',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: pendingCount > 0
                                      ? AppColors.terracotta
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (pendingCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.terracotta,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$pendingCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Main Body with Matches & Conversations
            Expanded(
              child: Builder(
                builder: (context) {
                  if (conversationsState.isLoading &&
                      conversationsState.conversations.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (conversationsState.errorMessage != null &&
                      conversationsState.conversations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load matches: ${conversationsState.errorMessage}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref
                                .read(chatConversationsProvider.notifier)
                                .loadConversations(),
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    );
                  }

                  final conversations = conversationsState.conversations;
                  if (conversations.isEmpty) {
                    return _buildEmptyMatchesView(context);
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref
                        .read(chatConversationsProvider.notifier)
                        .loadConversations(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        // Instagram-Style "Recent Matches" horizontal bubble tray
                        _buildRecentMatchesTray(context, conversations),

                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(
                            'Conversations',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),

                        // Chat List Tiles
                        ...conversations.map(
                          (conv) => _buildConversationTile(context, conv),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMatchesTray(
    BuildContext context,
    List<MatchConversationModel> conversations,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Text(
            'New Matches',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(
          height: 98,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (ctx, index) {
              final conv = conversations[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailPage(match: conv),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    MatchedPairAvatar(
                      petImageUrl: conv.otherPet.imageUrl,
                      petName: conv.otherPet.name,
                      ownerImageUrl: conv.otherOwner.imageUrl,
                      ownerName: conv.otherOwner.name,
                      size: 60,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 66,
                      child: Text(
                        conv.otherPet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 12, indent: 20, endIndent: 20),
      ],
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    MatchConversationModel conv,
  ) {
    final timeStr = conv.lastMessageTime != null
        ? formatChatListTimestamp(conv.lastMessageTime!)
        : formatChatListTimestamp(conv.matchedAt);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatDetailPage(match: conv)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Row(
          children: [
            // Left: Slanted Overlapping Pet & Owner Avatar
            MatchedPairAvatar(
              petImageUrl: conv.otherPet.imageUrl,
              petName: conv.otherPet.name,
              ownerImageUrl: conv.otherOwner.imageUrl,
              ownerName: conv.otherOwner.name,
              size: 56,
            ),
            const SizedBox(width: 14),

            // Middle: Name, Pet & Last Message Snippet
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${conv.otherPet.name} • ${conv.otherOwner.name}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: conv.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: conv.unreadCount > 0
                              ? AppColors.terracotta
                              : AppColors.textMuted,
                          fontWeight: conv.unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            // Show tick for my last message
                            final myUid = ref.watch(currentFirebaseUidProvider);
                            final convAsync = ref.watch(
                              singleConversationProvider(conv.matchId),
                            );
                            final fConv = convAsync.value;
                            final isMyLastMessage =
                                fConv?.lastMessageSenderUid == myUid &&
                                myUid.isNotEmpty;

                            final snippet =
                                conv.lastMessage ??
                                '🐾 Tap to start chatting...';
                            if (isMyLastMessage && fConv != null) {
                              final readReceipts = ref.watch(
                                readReceiptsSettingProvider,
                              );
                              // Approximate status from conversation watermarks
                              final convOtherUid = fConv.otherUid(myUid);
                              MessageStatus listStatus = MessageStatus.sent;
                              if (readReceipts) {
                                final otherSeen = fConv.seenAtFor(convOtherUid);
                                if (otherSeen != null &&
                                    fConv.lastMessageAt != null &&
                                    !fConv.lastMessageAt!.isAfter(otherSeen)) {
                                  listStatus = MessageStatus.read;
                                }
                              }
                              if (listStatus != MessageStatus.read) {
                                final otherDelivered = fConv.deliveredAtFor(
                                  convOtherUid,
                                );
                                if (otherDelivered != null &&
                                    fConv.lastMessageAt != null &&
                                    !fConv.lastMessageAt!.isAfter(
                                      otherDelivered,
                                    )) {
                                  listStatus = MessageStatus.delivered;
                                }
                              }
                              return Row(
                                children: [
                                  MessageStatusWidget(
                                    status: listStatus,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      snippet,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: conv.unreadCount > 0
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                        fontWeight: conv.unreadCount > 0
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Text(
                              snippet,
                              style: TextStyle(
                                fontSize: 13,
                                color: conv.unreadCount > 0
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: conv.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.terracotta,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMatchesView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Matches Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When you and another pet parent match or accept a playdate request, your conversations will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
