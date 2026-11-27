import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../home/data/models/connection_request_model.dart';
import '../../../home/presentation/providers/requests_provider.dart';
import '../../../home/presentation/widgets/intro_message_sheet.dart';
import '../../data/models/all_connection_item.dart';
import '../../data/models/match_conversation_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_settings_provider.dart';
import '../providers/connections_provider.dart';
import '../widgets/chat_filter_tabs.dart';
import '../widgets/chat_privacy_settings_sheet.dart';
import '../widgets/date_separator.dart';
import '../widgets/incoming_request_tile.dart';
import '../widgets/matched_pair_avatar.dart';
import '../widgets/message_status_widget.dart';
import '../widgets/outgoing_request_tile.dart';

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  ChatFilterTab _selectedTab = ChatFilterTab.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(outgoingRequestsProvider.notifier).loadOutgoingRequests();
    });
  }

  void _onTabSelected(ChatFilterTab tab) {
    setState(() => _selectedTab = tab);
    if (tab == ChatFilterTab.liked) {
      ref
          .read(outgoingRequestsProvider.notifier)
          .loadOutgoingRequests(refresh: true);
    } else if (tab == ChatFilterTab.all) {
      ref.invalidate(allConnectionsProvider);
      ref.read(requestsProvider.notifier).loadRequests(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentFirebaseUidProvider);

    // Mark delivery watermark for all active conversations while on ChatsPage
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
          final myDelivered = conv.deliveredAtFor(myUid);
          if (myDelivered == null || lastMsgAt.isAfter(myDelivered)) {
            repo.markDelivered(conv.matchId, myUid, lastMessageAt: lastMsgAt);
          }
        }
      },
    );

    final requestsState = ref.watch(requestsProvider);
    final pendingCount = requestsState.pendingCount;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Clean Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chats',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Matches, Likes & Requests',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    tooltip: 'Chat Privacy',
                    onPressed: () => showChatPrivacySettingsSheet(context),
                  ),
                ],
              ),
            ),

            // 2. Three Primary Filters: Active (default), Liked, All
            ChatFilterTabs(
              selectedTab: _selectedTab,
              onTabSelected: _onTabSelected,
              incomingRequestsCount: pendingCount,
            ),
            const SizedBox(height: 10),

            // 3. Tab Content
            Expanded(
              child: switch (_selectedTab) {
                ChatFilterTab.active => _buildActiveTab(context),
                ChatFilterTab.liked => _buildLikedTab(context),
                ChatFilterTab.all => _buildAllTab(context),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVE TAB
  // ---------------------------------------------------------------------------

  Widget _buildActiveTab(BuildContext context) {
    final conversationsState = ref.watch(chatConversationsProvider);

    if (conversationsState.isLoading &&
        conversationsState.conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F5C57)),
      );
    }

    if (conversationsState.errorMessage != null &&
        conversationsState.conversations.isEmpty) {
      return _buildErrorView(
        message: 'Failed to load chats: ${conversationsState.errorMessage}',
        onRetry: () =>
            ref.read(chatConversationsProvider.notifier).loadConversations(),
      );
    }

    final conversations = conversationsState.conversations;
    if (conversations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No Active Chats Yet',
        subtitle:
            'When a pet owner accepts your request or you accept theirs, your conversation will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(chatConversationsProvider.notifier).loadConversations(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: conversations.length,
        itemBuilder: (context, index) =>
            _buildConversationTile(context, conversations[index]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LIKED TAB (Outgoing Requests)
  // ---------------------------------------------------------------------------

  Widget _buildLikedTab(BuildContext context) {
    final outgoingState = ref.watch(outgoingRequestsProvider);

    if (outgoingState.isLoading && outgoingState.requests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F5C57)),
      );
    }

    if (outgoingState.errorMessage != null && outgoingState.requests.isEmpty) {
      return _buildErrorView(
        message: outgoingState.errorMessage!,
        onRetry: () => ref
            .read(outgoingRequestsProvider.notifier)
            .loadOutgoingRequests(refresh: true),
      );
    }

    final requests = outgoingState.requests;
    if (requests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No Liked Pets Yet',
        subtitle:
            'Pets you like in Discover will appear here so you can track requests or add an introductory message.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(outgoingRequestsProvider.notifier)
          .loadOutgoingRequests(refresh: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: requests.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 76, endIndent: 20),
        itemBuilder: (context, index) {
          final req = requests[index];
          return OutgoingRequestTile(
            request: req,
            onTap: () => _handleOutgoingTap(req),
            onAddOrEditIntro:
                req.isPending ? () => _openIntroComposerForOutgoing(req) : null,
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ALL TAB (Combined Active + Incoming + Outgoing)
  // ---------------------------------------------------------------------------

  Widget _buildAllTab(BuildContext context) {
    final allAsync = ref.watch(allConnectionsProvider);
    final conversationsState = ref.watch(chatConversationsProvider);

    // Build quick lookup of live Firestore-enriched conversations
    final liveConvMap = {
      for (final c in conversationsState.conversations) c.matchId: c,
    };

    return allAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F5C57)),
      ),
      error: (err, _) => _buildErrorView(
        message: 'Failed to load connections: $err',
        onRetry: () => ref.invalidate(allConnectionsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState(
            icon: Icons.pets_rounded,
            title: 'No Connections Yet',
            subtitle:
                'Your active chats, incoming requests, and liked pets will all appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allConnectionsProvider);
            await ref
                .read(chatConversationsProvider.notifier)
                .loadConversations();
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 76, endIndent: 20),
            itemBuilder: (context, index) {
              final item = items[index];
              switch (item.itemType) {
                case AllConnectionItemType.activeChat:
                  final match = item.match;
                  if (match == null) return const SizedBox.shrink();
                  final enriched = liveConvMap[match.matchId] ?? match;
                  return _buildConversationTile(context, enriched);

                case AllConnectionItemType.incomingRequest:
                  final req = item.incomingRequest;
                  if (req == null) return const SizedBox.shrink();
                  return IncomingRequestTile(
                    request: req,
                    onTap: () => _openIncomingRequest(req),
                  );

                case AllConnectionItemType.outgoingRequest:
                  final req = item.outgoingRequest;
                  if (req == null) return const SizedBox.shrink();
                  return OutgoingRequestTile(
                    request: req,
                    onTap: () => _handleOutgoingTap(req),
                    onAddOrEditIntro: req.isPending
                        ? () => _openIntroComposerForOutgoing(req)
                        : null,
                  );
              }
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION & ACTIONS
  // ---------------------------------------------------------------------------

  void _openIncomingRequest(ConnectionRequestModel req) {
    context.push('/request/${req.id}', extra: req).then((_) {
      ref.invalidate(allConnectionsProvider);
      ref.read(requestsProvider.notifier).loadRequests(refresh: true);
    });
  }

  void _handleOutgoingTap(OutgoingRequestModel req) {
    if (req.isAccepted && req.matchId != null && req.matchId!.isNotEmpty) {
      context.push('/chat/${req.matchId}');
      return;
    }

    if (!req.isPending) {
      context.push('/pet/${req.receiverPetId}');
      return;
    }

    _showPendingOutgoingSheet(req);
  }

  void _openIntroComposerForOutgoing(OutgoingRequestModel req) {
    showIntroMessageSheet(
      context: context,
      petName: req.receiverPetName,
      petImageUrl: req.receiverPetImageUrl,
      initialMessage: req.initialMessage,
      onSend: (msg) async {
        await ref
            .read(outgoingRequestsProvider.notifier)
            .updateIntroMessage(requestId: req.id, message: msg);
      },
    ).then((saved) {
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Introductory message saved for ${req.receiverPetName}'),
            backgroundColor: const Color(0xFF0F5C57),
          ),
        );
      }
    });
  }

  void _showPendingOutgoingSheet(OutgoingRequestModel req) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Request to ${req.receiverPetName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Waiting for ${req.receiverOwnerName} to respond',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (req.hasInitialMessage) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      req.initialMessage!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _openIntroComposerForOutgoing(req);
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: Text(
                    req.hasInitialMessage
                        ? 'Edit Introductory Message'
                        : 'Add Introductory Message',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F5C57),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          context.push('/pet/${req.receiverPetId}');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('View Pet'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.of(sheetCtx).pop();
                          try {
                            await ref
                                .read(outgoingRequestsProvider.notifier)
                                .cancelRequest(req.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Connection request cancelled'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to cancel: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancel Request'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED TILE & EMPTY/ERROR HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildConversationTile(
    BuildContext context,
    MatchConversationModel conv,
  ) {
    final timeStr = conv.lastMessageTime != null
        ? formatChatListTimestamp(conv.lastMessageTime!)
        : formatChatListTimestamp(conv.matchedAt);

    return InkWell(
      onTap: () {
        context.push('/chat/${conv.matchId}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            MatchedPairAvatar(
              petImageUrl: conv.otherPet.imageUrl,
              petName: conv.otherPet.name,
              ownerImageUrl: conv.otherOwner.imageUrl,
              ownerName: conv.otherOwner.name,
              size: 56,
            ),
            const SizedBox(width: 14),
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
                color: const Color(0xFF0F5C57).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: const Color(0xFF0F5C57),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

  Widget _buildErrorView({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F5C57),
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
