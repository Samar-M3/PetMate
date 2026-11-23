import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_provider.dart';

/// Displays media items in a grid layout within a chat bubble.
/// 1 item = full width, 2 = side by side, 3+ = grid with "+N" overlay.
class ChatMediaGrid extends ConsumerWidget {
  final List<MediaItem> items;
  final String conversationId;
  final void Function(int index)? onTap;
  final double maxWidth;

  const ChatMediaGrid({
    super.key,
    required this.items,
    required this.conversationId,
    this.onTap,
    this.maxWidth = 260,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final displayCount = items.length > 4 ? 4 : items.length;
    final extraCount = items.length - 4;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: maxWidth,
        child: _buildGrid(ref, displayCount, extraCount),
      ),
    );
  }

  Widget _buildGrid(WidgetRef ref, int displayCount, int extraCount) {
    if (items.length == 1) {
      return _buildMediaTile(ref, 0, aspectRatio: 4 / 3);
    }

    if (items.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildMediaTile(ref, 0, height: 160)),
          const SizedBox(width: 2),
          Expanded(child: _buildMediaTile(ref, 1, height: 160)),
        ],
      );
    }

    // 3 or more: 2x2 grid style
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _buildMediaTile(ref, 0, height: 120)),
            const SizedBox(width: 2),
            Expanded(child: _buildMediaTile(ref, 1, height: 120)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(child: _buildMediaTile(ref, 2, height: 120)),
            if (displayCount >= 4) ...[
              const SizedBox(width: 2),
              Expanded(
                child: Stack(
                  children: [
                    _buildMediaTile(ref, 3, height: 120),
                    if (extraCount > 0)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => onTap?.call(3),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                            child: Center(
                              child: Text(
                                '+$extraCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMediaTile(
    WidgetRef ref,
    int index, {
    double? height,
    double? aspectRatio,
  }) {
    if (index >= items.length) return const SizedBox.shrink();

    final item = items[index];
    final child = _MediaTileContent(
      item: item,
      conversationId: conversationId,
      height: height,
      aspectRatio: aspectRatio,
    );

    return GestureDetector(
      onTap: () => onTap?.call(index),
      child: child,
    );
  }
}

class _MediaTileContent extends ConsumerStatefulWidget {
  final MediaItem item;
  final String conversationId;
  final double? height;
  final double? aspectRatio;

  const _MediaTileContent({
    required this.item,
    required this.conversationId,
    this.height,
    this.aspectRatio,
  });

  @override
  ConsumerState<_MediaTileContent> createState() => _MediaTileContentState();
}

class _MediaTileContentState extends ConsumerState<_MediaTileContent> {
  String? _thumbnailUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final publicId = widget.item.isVideo
        ? widget.item.thumbnailPublicId ?? widget.item.publicId
        : widget.item.publicId;

    if (publicId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final cache = ref.read(mediaUrlCacheProvider.notifier);
      final url = await cache.getUrl(
        widget.conversationId,
        publicId,
        kind: widget.item.kind,
        isThumbnail: true,
      );
      if (mounted) {
        setState(() {
          _thumbnailUrl = url;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_loading) {
      content = Container(
        color: AppColors.inputFill,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_thumbnailUrl != null) {
      content = CachedNetworkImage(
        imageUrl: _thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.inputFill,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.inputFill,
          child: const Icon(
            Icons.broken_image_rounded,
            color: AppColors.textMuted,
          ),
        ),
      );
    } else {
      content = Container(
        color: AppColors.inputFill,
        child: const Icon(
          Icons.image_not_supported_rounded,
          color: AppColors.textMuted,
        ),
      );
    }

    // Video overlay
    if (widget.item.isVideo) {
      content = Stack(
        fit: StackFit.passthrough,
        children: [
          content,
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          if (widget.item.durationSeconds != null)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(widget.item.durationSeconds!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (widget.aspectRatio != null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio!,
        child: content,
      );
    }

    return SizedBox(
      height: widget.height ?? 160,
      child: content,
    );
  }

  String _formatDuration(double seconds) {
    final totalSecs = seconds.round();
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

/// A widget for showing a media expired state in a bubble.
class MediaExpiredBubble extends StatelessWidget {
  const MediaExpiredBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_off_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          const Text(
            'Media expired',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
