import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/match_conversation_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_provider.dart';
import '../widgets/matched_pair_avatar.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final MatchConversationModel match;

  const ChatDetailPage({super.key, required this.match});

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  int _charCount = 0;
  int _messageLimit = 30;
  bool _isLoadingOlder = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final len = _textController.text.length;
      if (len != _charCount) {
        setState(() => _charCount = len);
      }
    });

    _scrollController.addListener(_onScroll);

    // Ensure conversation exists in backend and mark as read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
  }

  Future<void> _initChat() async {
    final myUid = ref.read(currentFirebaseUidProvider);
    final repo = ref.read(chatRepositoryProvider);

    try {
      await repo.getMatchChat(widget.match.matchId);
    } catch (_) {
      // Backend may be offline or match already active
    }

    if (myUid.isNotEmpty) {
      repo.markRead(widget.match.matchId, myUid);
    }
  }

  void _onScroll() {
    // When scrolling near the top (since list is inverted/scrolled to top), load older
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingOlder) {
      setState(() {
        _isLoadingOlder = true;
        _messageLimit += 30;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _isLoadingOlder = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final myUid = ref.read(currentFirebaseUidProvider);
    if (myUid.isEmpty) return;

    final convAsync =
        ref.read(singleConversationProvider(widget.match.matchId));
    final conv = convAsync.value;
    final otherUid = conv?.otherUid(myUid) ?? '';

    setState(() => _isSending = true);
    _textController.clear();

    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.sendMessage(widget.match.matchId, text, myUid, otherUid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showUnmatchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unmatch Pet'),
        content: Text(
          'Are you sure you want to unmatch with ${widget.match.otherPet.name} and ${widget.match.otherOwner.name}? This will close the conversation for both of you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(chatRepositoryProvider)
                    .unmatch(widget.match.matchId);
                ref
                    .read(chatConversationsProvider.notifier)
                    .loadConversations();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unmatched successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to unmatch: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Unmatch', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${widget.match.otherOwner.name}?'),
        content: Text(
          'You will no longer see ${widget.match.otherOwner.name}\'s profile or pets, and all matches and chats between you will end.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(chatRepositoryProvider)
                    .blockUser(widget.match.otherOwner.id);
                ref
                    .read(chatConversationsProvider.notifier)
                    .loadConversations();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${widget.match.otherOwner.name} has been blocked.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to block user: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, {String? messageId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 18),
            Text(
              messageId != null ? 'Report Message' : 'Report Conversation',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select the reason for reporting. Our safety team will review the conversation history securely.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...[
              'Inappropriate or offensive messages',
              'Harassment or threatening behaviour',
              'Commercial solicitations or puppy mill scam',
              'Fake or stolen pet identity',
              'Safety concern',
              'Other',
            ].map(
              (reason) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(chatRepositoryProvider).reportChat(
                          widget.match.matchId,
                          messageId: messageId,
                          reason: reason,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Thank you. Report submitted for team review.',
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to submit report: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final myUid = ref.watch(currentFirebaseUidProvider);
    final convAsync = ref.watch(singleConversationProvider(match.matchId));
    final messagesAsync = ref.watch(
      messagesStreamProvider(
        (matchId: match.matchId, limit: _messageLimit),
      ),
    );

    final isEnded = convAsync.value?.status == 'ENDED';
    final endedReason = convAsync.value?.endedReason;

    // Mark as read when new messages are observed
    ref.listen(
      messagesStreamProvider(
        (matchId: match.matchId, limit: _messageLimit),
      ),
      (_, next) {
        if (myUid.isNotEmpty && (next.value?.isNotEmpty ?? false)) {
          ref.read(chatRepositoryProvider).markRead(match.matchId, myUid);
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: _buildAppBar(context, match),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Ended Banner if conversation was ended
            if (isEnded) _buildEndedBanner(endedReason),

            // 2. Real-time Messages Stream
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Unable to load messages: $err',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return _buildEmptyChatView(match);
                  }

                  // Messages arrive newest first (index 0 is newest)
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (ctx, index) {
                      final msg = messages[index];
                      final isMine = msg.senderUid == myUid;
                      return _buildMessageBubble(msg, isMine);
                    },
                  );
                },
              ),
            ),

            // 3. Message Input Bar or Disabled State
            if (isEnded)
              _buildDisabledInputBar()
            else
              _buildMessageInputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEndedBanner(String? reason) {
    String message = 'This conversation has ended.';
    if (reason == 'UNMATCHED') {
      message = 'This match has been ended.';
    } else if (reason == 'BLOCKED') {
      message = 'This user has been blocked.';
    } else if (reason == 'PET_DELETED') {
      message = 'This pet profile was deleted.';
    } else if (reason == 'ACCOUNT_SUSPENDED') {
      message = 'The pet owner\'s account is inactive.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.border.withValues(alpha: 0.6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MatchConversationModel match,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      leadingWidth: 32,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: InkWell(
        onTap: () => _showMatchInfoBottomSheet(context, match),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            children: [
              MatchedPairAvatar(
                petImageUrl: match.otherPet.imageUrl,
                petName: match.otherPet.name,
                ownerImageUrl: match.otherOwner.imageUrl,
                ownerName: match.otherOwner.name,
                size: 42,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${match.otherPet.name} • ${match.otherOwner.name}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      match.otherPet.breed ?? 'Playdate match',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          onSelected: (val) {
            if (val == 'pet_info') {
              context.push('/pet/${match.otherPet.id}');
            } else if (val == 'owner_info') {
              context.push('/owner/${match.otherOwner.id}');
            } else if (val == 'unmatch') {
              _showUnmatchDialog(context);
            } else if (val == 'block') {
              _showBlockDialog(context);
            } else if (val == 'report') {
              _showReportDialog(context);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'pet_info',
              child: Row(
                children: [
                  Icon(Icons.pets, size: 18),
                  SizedBox(width: 10),
                  Text('View Pet Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'owner_info',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 18),
                  SizedBox(width: 10),
                  Text('View Owner Profile'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'unmatch',
              child: Row(
                children: [
                  Icon(Icons.link_off_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('Unmatch', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('Block Owner', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Report Chat'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyChatView(MatchConversationModel match) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.terracotta,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "You matched with ${match.otherPet.name}!",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Say hello to ${match.otherOwner.name} to plan a playdate for ${match.myPet.name} and ${match.otherPet.name} 🐾",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(FirestoreMessage msg, bool isMine) {
    final timeStr = DateFormat('h:mm a').format(msg.createdAt);

    return GestureDetector(
      onLongPress: () {
        if (!isMine) {
          _showReportDialog(context, messageId: msg.id);
        }
      },
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine ? const Color(0xFFE7F3EF) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: isMine
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.border,
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.text,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isMine
                          ? AppColors.primary.withValues(alpha: 0.8)
                          : AppColors.textMuted,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isPending
                          ? Icons.access_time_rounded
                          : Icons.done_rounded,
                      size: 14,
                      color: msg.isPending
                          ? AppColors.textMuted
                          : AppColors.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: const Center(
        child: Text(
          'You can no longer send messages in this conversation.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInputBar(BuildContext context) {
    final canSend = _charCount > 0 && _charCount <= 1000 && !_isSending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Message Input Field
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _charCount > 1000
                          ? AppColors.error
                          : AppColors.border,
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 5,
                    minLines: 1,
                    maxLength: 1000,
                    buildCounter: (_, {required currentLength, maxLength, required isFocused}) =>
                        null, // custom counter below
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle:
                          TextStyle(fontSize: 14, color: AppColors.textMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) {
                      if (canSend) _sendMessage();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send Button
              Material(
                color: canSend ? AppColors.terracotta : AppColors.inputFill,
                shape: const CircleBorder(),
                elevation: canSend ? 2 : 0,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: canSend ? _sendMessage : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: canSend ? Colors.white : AppColors.textMuted,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),

          // Character limit feedback when typing near max limit
          if (_charCount > 800)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$_charCount / 1000',
                  style: TextStyle(
                    fontSize: 11,
                    color: _charCount > 1000
                        ? AppColors.error
                        : AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMatchInfoBottomSheet(
    BuildContext context,
    MatchConversationModel match,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MatchedPairAvatar(
              petImageUrl: match.otherPet.imageUrl,
              petName: match.otherPet.name,
              ownerImageUrl: match.otherOwner.imageUrl,
              ownerName: match.otherOwner.name,
              size: 72,
            ),
            const SizedBox(height: 14),
            Text(
              '${match.otherPet.name} & ${match.otherOwner.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${match.otherPet.breed ?? 'Pet'} • ${match.otherOwner.location ?? 'Nearby'}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/pet/${match.otherPet.id}');
                    },
                    icon: const Icon(Icons.pets, size: 16),
                    label: const Text(
                      'Pet Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/owner/${match.otherOwner.id}');
                    },
                    icon: const Icon(Icons.person, color: Colors.white, size: 16),
                    label: const Text(
                      'Owner Profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
