import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../home/data/models/connection_request_model.dart';
import '../../../home/presentation/providers/requests_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/connections_provider.dart';

class MessageRequestPage extends ConsumerStatefulWidget {
  final String requestId;
  final ConnectionRequestModel? initialRequest;

  const MessageRequestPage({
    super.key,
    required this.requestId,
    this.initialRequest,
  });

  @override
  ConsumerState<MessageRequestPage> createState() => _MessageRequestPageState();
}

class _MessageRequestPageState extends ConsumerState<MessageRequestPage> {
  bool _isSubmitting = false;

  ConnectionRequestModel? _resolveRequest(RequestsState requestsState) {
    if (widget.initialRequest != null) return widget.initialRequest;
    for (final r in requestsState.requests) {
      if (r.id == widget.requestId) return r;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialRequest == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(requestsProvider.notifier).loadRequests(refresh: true);
      });
    }
  }

  Future<void> _handleAccept(ConnectionRequestModel req) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    await ref.read(requestsProvider.notifier).accept(
      req.id,
      onAccepted: (result) {
        ref.read(chatConversationsProvider.notifier).loadConversations();
        ref.invalidate(allConnectionsProvider);
        if (!mounted) return;
        final matchId = result['matchId'] as String?;
        if (matchId != null && matchId.isNotEmpty) {
          context.pushReplacement('/chat/$matchId');
        } else {
          Navigator.of(context).pop(true);
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  Future<void> _handleDecline(ConnectionRequestModel req) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    await ref.read(requestsProvider.notifier).reject(
      req.id,
      onRejected: () {
        ref.invalidate(allConnectionsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request declined'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
        Navigator.of(context).pop(false);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestsState = ref.watch(requestsProvider);
    final req = _resolveRequest(requestsState);

    if (req == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
          title: const Text('Message Request'),
        ),
        body: Center(
          child: requestsState.isLoading
              ? const CircularProgressIndicator(color: Color(0xFF0F5C57))
              : const Text(
                  'This request is no longer available.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
        ),
      );
    }

    final hasPetImage = req.senderPetImageUrl != null &&
        req.senderPetImageUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => context.push('/pet/${req.senderPetId}'),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.creamDark,
                backgroundImage:
                    hasPetImage ? NetworkImage(req.senderPetImageUrl!) : null,
                child: !hasPetImage
                    ? const Icon(
                        Icons.pets,
                        color: Color(0xFF0F5C57),
                        size: 18,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.senderPetName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'by ${req.senderUsername}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.push('/pet/${req.senderPetId}'),
            child: const Text(
              'View Pet',
              style: TextStyle(
                color: Color(0xFF0F5C57),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Sender pet card summary
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: AppColors.creamDark,
                        backgroundImage: hasPetImage
                            ? NetworkImage(req.senderPetImageUrl!)
                            : null,
                        child: !hasPetImage
                            ? const Icon(
                                Icons.pets,
                                color: Color(0xFF0F5C57),
                                size: 36,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        req.senderPetName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (req.senderPetBreed.isNotEmpty) req.senderPetBreed,
                          'Owner: ${req.senderUsername}',
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8A65).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Liked ${req.receiverPetName} ❤️',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD9643A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Introductory message chat bubble OR system prompt
                if (req.hasInitialMessage)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                          bottomLeft: Radius.circular(4),
                        ),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.initialMessage!,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Introductory message',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.waving_hand_rounded,
                          color: Color(0xFFFF8A65),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${req.senderUsername} wants to connect ${req.senderPetName} with ${req.receiverPetName}. Accept to start chatting!',
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Accept / Decline bar
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Accepting lets both of you exchange messages and plan playdates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => _handleDecline(req),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _handleAccept(req),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5C57),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Accept & Start Chatting',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
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
    );
  }
}
