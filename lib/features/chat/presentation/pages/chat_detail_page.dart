import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/chat_constants.dart';
import '../../../../core/services/fcm_service.dart';
import '../../data/models/match_conversation_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/services/chat_media_service.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_settings_provider.dart';
import '../widgets/chat_media_grid.dart';
import '../widgets/chat_message_menu.dart';
import '../widgets/chat_privacy_settings_sheet.dart';
import '../widgets/chat_reply_bar.dart';
import '../widgets/date_separator.dart';
import '../widgets/matched_pair_avatar.dart';
import 'media_preview_page.dart';
import '../widgets/message_status_widget.dart';
import 'media_viewer_page.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final MatchConversationModel match;

  const ChatDetailPage({super.key, required this.match});

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _charCount = 0;
  int _messageLimit = 30;
  bool _isLoadingOlder = false;
  bool _hasMore = true;
  List<FirestoreMessage>? _currentMessages;
  FirestoreMessage? _replyingTo;
  final Set<String> _selectedMessageIds = {};
  String? _hoveredMessageId;

  DateTime? _lastMarkedDeliveredAt;
  String? _lastMarkedReadMessageId;
  late final ActiveConversationNotifier _activeConversationNotifier;

  @override
  void initState() {
    super.initState();
    _activeConversationNotifier = ref.read(activeConversationProvider.notifier);
    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    // Ensure conversation exists in backend, set active chat for push suppression, and check notification permission
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeConversationNotifier.setActive(widget.match.matchId);
      ref.read(fcmServiceProvider).checkAndPromptPermission(context);
      _initChat();
    });
  }

  void _onTextChanged() {
    final len = _textController.text.length;
    if (len != _charCount) {
      setState(() => _charCount = len);
    }
  }

  Future<void> _initChat() async {
    final repo = ref.read(chatRepositoryProvider);

    try {
      await repo.getMatchChat(widget.match.matchId);
      final myUid = ref.read(currentFirebaseUidProvider);
      repo.clearReceiptPermissionError(widget.match.matchId, myUid);
    } catch (_) {
      // Backend may be offline or match already active
    }

    if (!mounted) return;

    _syncReadAndDeliveredState();
  }

  void _syncReadAndDeliveredState({
    FirestoreConversation? conversation,
    List<FirestoreMessage>? messages,
  }) {
    if (!mounted) return;
    final myUid = ref.read(currentFirebaseUidProvider);
    if (myUid.isEmpty) return;

    final conv =
        conversation ??
        ref.read(singleConversationProvider(widget.match.matchId)).value;
    if (conv == null ||
        conv.status != 'ACTIVE' ||
        !conv.participantUids.contains(myUid)) {
      return;
    }

    final repo = ref.read(chatRepositoryProvider);

    // 1. Advance delivery watermark if needed
    final lastMsgAt = conv.lastMessageAt;
    final myDelivered = conv.deliveredAtFor(myUid);
    if (lastMsgAt != null &&
        conv.lastMessageSenderUid != null &&
        conv.lastMessageSenderUid != myUid &&
        (myDelivered == null || lastMsgAt.isAfter(myDelivered)) &&
        _lastMarkedDeliveredAt != lastMsgAt) {
      repo
          .markDelivered(widget.match.matchId, myUid, lastMessageAt: lastMsgAt)
          .then((allowed) {
            if (allowed && mounted) _lastMarkedDeliveredAt = lastMsgAt;
          });
    }

    // 2. Mark conversation as read & seen when user is viewing it
    final msgs =
        messages ??
        _currentMessages ??
        ref
            .read(
              messagesStreamProvider((
                matchId: widget.match.matchId,
                limit: _messageLimit,
              )),
            )
            .value;

    final hasUnread = conv.unreadFor(myUid) > 0;
    final latestMsgId = (msgs != null && msgs.isNotEmpty)
        ? msgs.first.id
        : (hasUnread
              ? 'unread_${lastMsgAt?.millisecondsSinceEpoch ?? 0}'
              : null);

    if (latestMsgId == null) return;
    if (!hasUnread && _lastMarkedReadMessageId == latestMsgId) return;

    final readReceipts = ref.read(readReceiptsSettingProvider);
    repo
        .markSeenAndRead(
          widget.match.matchId,
          myUid,
          latestMessageId: latestMsgId,
          includeSeenReceipt: readReceipts,
          force: hasUnread,
        )
        .then((allowed) {
          if (allowed && mounted) {
            _lastMarkedReadMessageId = latestMsgId;
          }
        });
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingOlder) return;
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    // When scrolling near the top (since list is reverse: true, maxScrollExtent is top)
    // Only paginate if content exceeds viewport meaningfully (> 60px)
    if (maxScroll > 60 &&
        _scrollController.position.pixels >= maxScroll - 150) {
      setState(() {
        _isLoadingOlder = true;
        _messageLimit += 30;
      });

      // Safety timeout in case stream doesn't emit or network drops
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _isLoadingOlder) {
          setState(() => _isLoadingOlder = false);
        }
      });
    }
  }

  @override
  void dispose() {
    Future.microtask(() => _activeConversationNotifier.setActive(null));
    _scrollController.removeListener(_onScroll);
    _inputFocusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToMessage(
    String targetMessageId,
    List<FirestoreMessage> messages,
  ) {
    final targetIndex = messages.indexWhere((m) => m.id == targetMessageId);
    if (targetIndex != -1) {
      final targetOffset = (targetIndex * 85.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _showMediaPickerSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Photo & Video Gallery'),
                subtitle: const Text('Select up to 10 images or videos'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final mediaService = ref.read(chatMediaServiceProvider);
                    final files = await mediaService.pickMediaFromGallery();
                    if (files.isNotEmpty && mounted) {
                      final sent = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MediaPreviewPage(
                            initialFiles: files,
                            conversationId: widget.match.matchId,
                            replyTo: _replyingTo != null
                                ? ReplyToData(
                                    messageId: _replyingTo!.id,
                                    senderUid: _replyingTo!.senderUid,
                                    type: _replyingTo!.type,
                                    preview: _replyingTo!.isMedia
                                        ? (_replyingTo!.media.isNotEmpty &&
                                                  _replyingTo!
                                                      .media
                                                      .first
                                                      .isVideo
                                              ? 'Video'
                                              : 'Photo')
                                        : _replyingTo!.text.characters
                                              .take(100)
                                              .toString(),
                                  )
                                : null,
                          ),
                        ),
                      );
                      if (sent == true && mounted) {
                        setState(() => _replyingTo = null);
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final mediaService = ref.read(chatMediaServiceProvider);
                    final file = await mediaService.takePhoto();
                    if (file != null && mounted) {
                      final sent = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MediaPreviewPage(
                            initialFiles: [file],
                            conversationId: widget.match.matchId,
                            replyTo: _replyingTo != null
                                ? ReplyToData(
                                    messageId: _replyingTo!.id,
                                    senderUid: _replyingTo!.senderUid,
                                    type: _replyingTo!.type,
                                    preview: _replyingTo!.isMedia
                                        ? (_replyingTo!.media.isNotEmpty &&
                                                  _replyingTo!
                                                      .media
                                                      .first
                                                      .isVideo
                                              ? 'Video'
                                              : 'Photo')
                                        : _replyingTo!.text.characters
                                              .take(100)
                                              .toString(),
                                  )
                                : null,
                          ),
                        ),
                      );
                      if (sent == true && mounted) {
                        setState(() => _replyingTo = null);
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.videocam_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Record Video (max 60s)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final mediaService = ref.read(chatMediaServiceProvider);
                    final file = await mediaService.recordVideo();
                    if (file != null && mounted) {
                      final sent = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MediaPreviewPage(
                            initialFiles: [file],
                            conversationId: widget.match.matchId,
                            replyTo: _replyingTo != null
                                ? ReplyToData(
                                    messageId: _replyingTo!.id,
                                    senderUid: _replyingTo!.senderUid,
                                    type: _replyingTo!.type,
                                    preview: _replyingTo!.isMedia
                                        ? (_replyingTo!.media.isNotEmpty &&
                                                  _replyingTo!
                                                      .media
                                                      .first
                                                      .isVideo
                                              ? 'Video'
                                              : 'Photo')
                                        : _replyingTo!.text.characters
                                              .take(100)
                                              .toString(),
                                  )
                                : null,
                          ),
                        ),
                      );
                      if (sent == true && mounted) {
                        setState(() => _replyingTo = null);
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final myUid = ref.read(currentFirebaseUidProvider);
    if (myUid.isEmpty) return;

    final convAsync = ref.read(
      singleConversationProvider(widget.match.matchId),
    );
    final conv = convAsync.value;
    final otherUid =
        conv?.otherUid(myUid) ?? widget.match.otherFirebaseUid ?? '';

    final replyTo = _replyingTo != null
        ? ReplyToData(
            messageId: _replyingTo!.id,
            senderUid: _replyingTo!.senderUid,
            type: _replyingTo!.type,
            preview: _replyingTo!.isMedia
                ? (_replyingTo!.media.isNotEmpty &&
                          _replyingTo!.media.first.isVideo
                      ? 'Video'
                      : 'Photo')
                : _replyingTo!.text.characters.take(100).toString(),
          )
        : null;

    // Clear input immediately so user can type the next message right away
    setState(() {
      _replyingTo = null;
    });
    _textController.clear();

    // Fire-and-forget: send in background, don't block the UI
    final repo = ref.read(chatRepositoryProvider);
    repo
        .sendMessage(
          widget.match.matchId,
          text,
          myUid,
          otherUid,
          replyTo: replyTo,
        )
        .catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send message: ${e.toString()}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        });
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
              final repo = ref.read(chatRepositoryProvider);
              final convsNotifier = ref.read(
                chatConversationsProvider.notifier,
              );
              Navigator.pop(ctx);
              try {
                await repo.unmatch(widget.match.matchId);
                convsNotifier.loadConversations();
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
              final repo = ref.read(chatRepositoryProvider);
              final convsNotifier = ref.read(
                chatConversationsProvider.notifier,
              );
              Navigator.pop(ctx);
              try {
                await repo.blockUser(widget.match.otherOwner.id);
                convsNotifier.loadConversations();
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
                  final repo = ref.read(chatRepositoryProvider);
                  Navigator.pop(ctx);
                  try {
                    await repo.reportChat(
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
    final readReceiptsEnabled = ref.watch(readReceiptsSettingProvider);
    final messagesAsync = ref.watch(
      messagesStreamProvider((matchId: match.matchId, limit: _messageLimit)),
    );

    // Cache initial messages if available
    if (messagesAsync.hasValue && _currentMessages == null) {
      _currentMessages = messagesAsync.value;
      if (_currentMessages != null &&
          _currentMessages!.length < _messageLimit) {
        _hasMore = false;
      }
    }

    final isEnded = convAsync.value?.status == 'ENDED';
    final endedReason = convAsync.value?.endedReason;

    // Mark as read and update message pagination state when new messages are observed
    ref.listen(
      messagesStreamProvider((matchId: match.matchId, limit: _messageLimit)),
      (prev, next) {
        final msgs = next.value;
        if (msgs != null) {
          if (mounted) {
            setState(() {
              if (_currentMessages != null &&
                  msgs.length <= _currentMessages!.length &&
                  _messageLimit > 30) {
                _hasMore = false;
              } else if (msgs.length < _messageLimit) {
                _hasMore = false;
              }
              _currentMessages = msgs;
              _isLoadingOlder = false;
            });
          }

          _syncReadAndDeliveredState(messages: msgs);
        } else if (next.hasError && _isLoadingOlder) {
          if (mounted) {
            setState(() => _isLoadingOlder = false);
          }
        }
      },
    );

    // Mark delivery and read/seen watermarks when conversation stream updates
    ref.listen(singleConversationProvider(match.matchId), (_, next) {
      final conv = next.value;
      if (conv != null) {
        _syncReadAndDeliveredState(conversation: conv);
      }
    });

    final effectiveMessages =
        (messagesAsync.hasValue ? messagesAsync.value : null) ??
        _currentMessages;

    return PopScope(
      canPop: _selectedMessageIds.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedMessageIds.isNotEmpty) {
          setState(() => _selectedMessageIds.clear());
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_selectedMessageIds.isNotEmpty) {
              setState(() => _selectedMessageIds.clear());
            }
          },
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: const Color(0xFFF7F5F0),
          appBar: _selectedMessageIds.isNotEmpty
              ? _buildSelectionAppBar(context, effectiveMessages ?? [])
              : _buildAppBar(context, match),
          body: SafeArea(
            child: Column(
              children: [
                // 1. Ended Banner if conversation was ended
                if (isEnded) _buildEndedBanner(endedReason),

                // 2. Real-time Messages Stream
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (effectiveMessages == null) {
                        if (messagesAsync.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        }
                        if (messagesAsync.hasError) {
                          return Center(
                            child: Text(
                              'Unable to load messages: ${messagesAsync.error}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }
                      }

                      final messages = effectiveMessages ?? [];
                      if (messages.isEmpty) {
                        return _buildEmptyChatView(match);
                      }

                      // Messages arrive newest first (index 0 is newest)
                      final showLoadingOlder = _isLoadingOlder && _hasMore;
                      final totalCount =
                          messages.length + (showLoadingOlder ? 1 : 0);

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        itemCount: totalCount,
                        itemBuilder: (ctx, index) {
                          if (showLoadingOlder && index == totalCount - 1) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            );
                          }
                          final msgIndex = index;
                          final msg = messages[msgIndex];
                          final isMine = msg.senderUid == myUid;
                          final showDateSeparator =
                              msgIndex == messages.length - 1 ||
                              isDifferentDay(
                                msg.createdAt,
                                messages[msgIndex + 1].createdAt,
                              );

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDateSeparator)
                                DateSeparatorWidget(date: msg.createdAt),
                              _buildMessageBubble(
                                msg,
                                isMine,
                                isEnded,
                                messages,
                                myUid,
                                convAsync.value,
                                readReceiptsEnabled,
                              ),
                            ],
                          );
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

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    List<FirestoreMessage> allMessages,
  ) {
    final count = _selectedMessageIds.length;
    final selectedMsgs = allMessages
        .where((m) => _selectedMessageIds.contains(m.id))
        .toList();
    final canCopy =
        selectedMsgs.isNotEmpty &&
        selectedMsgs.every(
          (m) => m.isText && !m.deletedForEveryone && m.text.isNotEmpty,
        );
    final canReply =
        selectedMsgs.length == 1 && !selectedMsgs.first.deletedForEveryone;

    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () {
          setState(() => _selectedMessageIds.clear());
        },
      ),
      title: Text(
        '$count selected',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        if (canReply)
          IconButton(
            icon: const Icon(Icons.reply_rounded, color: Colors.white),
            tooltip: 'Reply',
            onPressed: () {
              final msg = selectedMsgs.first;
              setState(() {
                _replyingTo = msg;
                _selectedMessageIds.clear();
              });
            },
          ),
        if (canCopy)
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white),
            tooltip: 'Copy',
            onPressed: () {
              final combined = selectedMsgs.map((m) => m.text).join('\n\n');
              Clipboard.setData(ClipboardData(text: combined));
              setState(() => _selectedMessageIds.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${selectedMsgs.length} message(s) copied'),
                ),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          tooltip: 'Delete',
          onPressed: () => _showBatchDeleteSheet(selectedMsgs),
        ),
      ],
    );
  }

  Future<void> _showBatchDeleteSheet(
    List<FirestoreMessage> selectedMsgs,
  ) async {
    final myUid = ref.read(currentFirebaseUidProvider);
    final convAsync = ref.read(
      singleConversationProvider(widget.match.matchId),
    );
    final isEnded = convAsync.value?.status == 'ENDED';

    final eligibleForEveryone =
        !isEnded &&
        selectedMsgs.isNotEmpty &&
        selectedMsgs.every(
          (m) => _canDeleteForEveryone(m, m.senderUid == myUid),
        );

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Delete ${selectedMsgs.length} message${selectedMsgs.length > 1 ? 's' : ''}?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Delete for me',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('Remove from your chat view only'),
                onTap: () => Navigator.pop(ctx, 'for_me'),
              ),
              if (eligibleForEveryone)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Delete for everyone',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Remove for everyone in the conversation',
                  ),
                  onTap: () => Navigator.pop(ctx, 'for_everyone'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (action == null || !mounted) return;

    final messageIds = selectedMsgs.map((m) => m.id).toList();
    setState(() => _selectedMessageIds.clear());

    try {
      final repo = ref.read(chatRepositoryProvider);
      if (action == 'for_me') {
        await repo.batchDeleteForMe(widget.match.matchId, messageIds, myUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${messageIds.length} message(s) deleted for you'),
            ),
          );
        }
      } else if (action == 'for_everyone') {
        final result = await repo.batchDeleteForEveryone(
          widget.match.matchId,
          messageIds,
        );
        final deletedList = (result['data']?['deleted'] as List?) ?? [];
        final rejectedList = (result['data']?['rejected'] as List?) ?? [];
        if (mounted) {
          if (rejectedList.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${deletedList.length} deleted, ${rejectedList.length} could not be deleted',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${deletedList.length} message(s) deleted for everyone',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete messages: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
            } else if (val == 'privacy') {
              showChatPrivacySettingsSheet(context);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'privacy',
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Chat Privacy'),
                ],
              ),
            ),
            const PopupMenuDivider(),
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
                  Icon(
                    Icons.link_off_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
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

  bool _canDeleteForEveryone(FirestoreMessage msg, bool isMine) {
    if (!isMine || msg.deletedForEveryone) return false;
    final ageMinutes = DateTime.now().difference(msg.createdAt).inMinutes;
    return ageMinutes <= ChatConstants.deleteForEveryoneWindowMinutes;
  }

  void _toggleSelection(String msgId) {
    setState(() {
      if (_selectedMessageIds.contains(msgId)) {
        _selectedMessageIds.remove(msgId);
      } else {
        if (_selectedMessageIds.length >= 50) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 50 messages can be selected'),
            ),
          );
        } else {
          _selectedMessageIds.add(msgId);
        }
      }
    });
  }

  Future<void> _handleMessageAction(
    ChatMessageAction action,
    FirestoreMessage msg,
    String myUid,
  ) async {
    switch (action) {
      case ChatMessageAction.reply:
        setState(() => _replyingTo = msg);
        break;

      case ChatMessageAction.copy:
        if (msg.text.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: msg.text));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message copied to clipboard')),
            );
          }
        }
        break;

      case ChatMessageAction.selectMessages:
        setState(() => _selectedMessageIds.add(msg.id));
        break;

      case ChatMessageAction.deleteForMe:
        final confirmed = await showDeleteConfirmationDialog(
          context,
          isForEveryone: false,
        );
        if (confirmed && mounted) {
          try {
            await ref
                .read(chatRepositoryProvider)
                .deleteForMe(widget.match.matchId, msg.id, myUid);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
        break;

      case ChatMessageAction.deleteForEveryone:
        final confirmed = await showDeleteConfirmationDialog(
          context,
          isForEveryone: true,
        );
        if (confirmed && mounted) {
          try {
            await ref
                .read(chatRepositoryProvider)
                .deleteForEveryone(widget.match.matchId, msg.id);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
        break;

      case ChatMessageAction.report:
        _showReportDialog(context, messageId: msg.id);
        break;
    }
  }

  Widget _buildMessageBubble(
    FirestoreMessage msg,
    bool isMine,
    bool isEnded,
    List<FirestoreMessage> allMessages,
    String myUid,
    FirestoreConversation? conversation,
    bool readReceiptsEnabled,
  ) {
    // If deleted for me, hide completely
    if (msg.isDeletedFor(myUid)) {
      return const SizedBox.shrink();
    }

    final timeStr = DateFormat('h:mm a').format(msg.createdAt);

    // If deleted for everyone, show muted tombstone
    if (msg.deletedForEveryone) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                isMine
                    ? 'You deleted this message'
                    : 'This message was deleted',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isSelected = _selectedMessageIds.contains(msg.id);
    final isSelectionMode = _selectedMessageIds.isNotEmpty;
    final isHovered = _hoveredMessageId == msg.id;

    // Swipe to reply wrapper
    return Dismissible(
      key: Key('msg_${msg.id}'),
      direction: (isEnded || isSelectionMode)
          ? DismissDirection.none
          : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        setState(() => _replyingTo = msg);
        HapticFeedback.lightImpact();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(
          Icons.reply_rounded,
          color: AppColors.primary,
          size: 24,
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredMessageId = msg.id),
        onExit: (_) => setState(() {
          if (_hoveredMessageId == msg.id) _hoveredMessageId = null;
        }),
        child: GestureDetector(
          onTap: () {
            if (isSelectionMode) {
              _toggleSelection(msg.id);
            }
          },
          onSecondaryTapDown: (details) async {
            if (isSelectionMode) return;
            final action = await showDesktopMessageMenu(
              context,
              details.globalPosition,
              isMine: isMine,
              isTextMessage: msg.isText,
              canDeleteForEveryone: _canDeleteForEveryone(msg, isMine),
              isEnded: isEnded,
            );
            if (action != null && mounted) {
              _handleMessageAction(action, msg, myUid);
            }
          },
          onLongPress: () async {
            if (isSelectionMode) {
              _toggleSelection(msg.id);
            } else {
              // Long press selects message and enters selection mode on mobile
              HapticFeedback.mediumImpact();
              setState(() => _selectedMessageIds.add(msg.id));
            }
          },
          child: Container(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              mainAxisAlignment: isMine
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (isSelectionMode && !isMine) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.76,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: msg.isMedia ? 4 : 14,
                        vertical: msg.isMedia ? 4 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isMine
                                  ? const Color(0xFFD4EAE2)
                                  : const Color(0xFFE8ECEF))
                            : (isMine ? const Color(0xFFE7F3EF) : Colors.white),
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
                          color: isSelected
                              ? AppColors.primary
                              : (isMine
                                    ? AppColors.primary.withValues(alpha: 0.25)
                                    : AppColors.border),
                          width: isSelected ? 1.5 : 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isMine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Quoted Reply Block (if replying to another message)
                          if (msg.replyTo != null)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                msg.isMedia ? 6 : 0,
                                msg.isMedia ? 6 : 0,
                                msg.isMedia ? 6 : 0,
                                2,
                              ),
                              child: QuotedReplyBlock(
                                senderName: msg.replyTo!.senderUid == myUid
                                    ? 'You'
                                    : widget.match.otherOwner.name,
                                preview: msg.replyTo!.preview,
                                isDeleted:
                                    msg.replyTo!.preview == 'Message deleted',
                                onTap: () => _scrollToMessage(
                                  msg.replyTo!.messageId,
                                  allMessages,
                                ),
                              ),
                            ),

                          // 2. Media Content or Expired Bubble
                          if (msg.isMedia) ...[
                            if (msg.mediaExpired)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: MediaExpiredBubble(),
                              )
                            else
                              ChatMediaGrid(
                                items: msg.media,
                                conversationId: widget.match.matchId,
                                onTap: (index) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MediaViewerPage(
                                        items: msg.media,
                                        conversationId: widget.match.matchId,
                                        initialIndex: index,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],

                          // 3. Text Message or Media Caption
                          if (msg.text.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                msg.isMedia ? 10 : 0,
                                msg.isMedia ? 6 : 0,
                                msg.isMedia ? 10 : 0,
                                0,
                              ),
                              child: Text(
                                msg.text,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: AppColors.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ),

                          const SizedBox(height: 4),

                          // 4. Timestamp & Pending indicator
                          Padding(
                            padding: EdgeInsets.only(
                              right: msg.isMedia ? 8 : 0,
                              bottom: msg.isMedia ? 4 : 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isMine
                                        ? AppColors.primary.withValues(
                                            alpha: 0.8,
                                          )
                                        : AppColors.textMuted,
                                  ),
                                ),
                                if (isMine) ...[
                                  const SizedBox(width: 4),
                                  MessageStatusWidget(
                                    status: computeMessageStatus(
                                      message: msg,
                                      conversation: conversation,
                                      myUid: myUid,
                                      otherUid:
                                          conversation?.otherUid(myUid) ?? '',
                                      readReceiptsEnabled: readReceiptsEnabled,
                                    ),
                                    size: 14,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 5. Desktop hover chevron button (WhatsApp Web style)
                    if (isHovered && !isSelectionMode)
                      Positioned(
                        top: 2,
                        right: isMine ? 4 : null,
                        left: !isMine ? 4 : null,
                        child: GestureDetector(
                          onTapDown: (details) async {
                            final action = await showDesktopMessageMenu(
                              context,
                              details.globalPosition,
                              isMine: isMine,
                              isTextMessage: msg.isText,
                              canDeleteForEveryone: _canDeleteForEveryone(
                                msg,
                                isMine,
                              ),
                              isEnded: isEnded,
                            );
                            if (action != null && mounted) {
                              _handleMessageAction(action, msg, myUid);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color:
                                  (isMine
                                          ? const Color(0xFFE7F3EF)
                                          : Colors.white)
                                      .withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (isSelectionMode && isMine) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ],
            ),
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
    final canSend = _charCount > 0 && _charCount <= 1000;
    final myUid = ref.read(currentFirebaseUidProvider);

    return Container(
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
          // Reply bar above input
          if (_replyingTo != null)
            ChatReplyBar(
              senderName: _replyingTo!.senderUid == myUid
                  ? 'You'
                  : widget.match.otherOwner.name,
              preview: _replyingTo!.isMedia
                  ? (_replyingTo!.media.isNotEmpty &&
                            _replyingTo!.media.first.isVideo
                        ? 'Video'
                        : 'Photo')
                  : _replyingTo!.text,
              isMediaMessage: _replyingTo!.isMedia,
              onCancel: () => setState(() => _replyingTo = null),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Media attachment button (+)
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                    onPressed: _showMediaPickerSheet,
                    tooltip: 'Attach photos',
                  ),
                ),

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
                      focusNode: _inputFocusNode,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 5,
                      minLines: 1,
                      maxLength: 1000,
                      buildCounter: (
                        _, {
                        required currentLength,
                        maxLength,
                        required isFocused,
                      }) => null,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
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
                      child: Icon(
                        Icons.send_rounded,
                        color: canSend ? Colors.white : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Character limit feedback as the input approaches its limit.
          if (_charCount > 800)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 16, bottom: 4),
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
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
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
                    icon: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
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
