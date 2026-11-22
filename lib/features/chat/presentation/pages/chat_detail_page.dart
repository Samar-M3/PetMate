import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/match_conversation_model.dart';
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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(activeChatProvider(widget.match).notifier).sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(activeChatProvider(widget.match));
    final match = widget.match;

    // Scroll down when new messages arrive
    ref.listen(activeChatProvider(widget.match), (_, _) {
      _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0), // Subtle warm cream wallpaper
      appBar: _buildWhatsAppAppBar(context, match),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Messages Stream
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                children: [
                  // Match Made Banner
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: AppColors.terracotta,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "It's a Match!",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "You and ${match.otherOwner.name} matched! ${match.myPet.name} & ${match.otherPet.name} can now plan playdates. Messages are completely private.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Date Separator Pill
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  // Message Bubbles
                  ...messages.map((msg) => _buildMessageBubble(msg)),
                ],
              ),
            ),

            // 2. WhatsApp-Style Input Bar
            _buildMessageInputBar(context),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildWhatsAppAppBar(
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
                showOnlineIndicator: true,
                isOnline: match.isOnline,
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
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          match.isOnline ? 'Online' : 'Active today',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
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
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_rounded, color: AppColors.primary),
          tooltip: 'Video Playdate Call',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Video call with ${match.otherOwner.name} coming soon!',
                ),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.call_rounded, color: AppColors.primary),
          tooltip: 'Voice Call',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Voice call with ${match.otherOwner.name} coming soon!',
                ),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          onSelected: (val) {
            if (val == 'info') {
              _showMatchInfoBottomSheet(context, match);
            } else if (val == 'clear') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat cleared')),
              );
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 10),
                  Text('View Match Info'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'mute',
              child: Row(
                children: [
                  Icon(Icons.notifications_off_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Mute Notifications'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                  SizedBox(width: 10),
                  Text('Clear Chat', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final timeStr = DateFormat('h:mm a').format(msg.createdAt);
    final isMine = msg.isMine;

    return Align(
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
                  const Icon(
                    Icons.done_all_rounded,
                    size: 15,
                    color: Color(0xFF34B7F1), // WhatsApp blue ticks
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      child: Row(
        children: [
          // Emoji / Attachment buttons
          IconButton(
            icon: const Icon(
              Icons.sentiment_satisfied_alt_outlined,
              color: AppColors.textSecondary,
              size: 24,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.attach_file_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Photo & media sharing coming soon!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),

          // Message Input Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send / Voice Button
          Material(
            color: _hasText ? AppColors.terracotta : AppColors.primary,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _hasText
                  ? _sendMessage
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voice note feature coming soon!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _hasText ? Icons.send_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 20,
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Matched on ${DateFormat.yMMMd().format(match.matchedAt)}. Both owners have verified profiles.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
