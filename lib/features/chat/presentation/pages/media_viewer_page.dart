import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_provider.dart';

/// Full-screen media viewer with swipe between items,
/// pinch-to-zoom for images, and video player.
class MediaViewerPage extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final String conversationId;
  final int initialIndex;

  const MediaViewerPage({
    super.key,
    required this.items,
    required this.conversationId,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends ConsumerState<MediaViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, String> _resolvedUrls = {};
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadUrls();
  }

  Future<void> _loadUrls() async {
    final cache = ref.read(mediaUrlCacheProvider.notifier);
    final publicIds = widget.items.map((i) => i.publicId).toList();
    final items = widget.items
        .map((i) => {
              'publicId': i.publicId,
              'kind': i.kind,
              'thumbnail': false,
            })
        .toList();
    final urls = await cache.getUrls(
      widget.conversationId,
      publicIds,
      items: items,
    );

    if (mounted) {
      setState(() {
        for (int i = 0; i < widget.items.length; i++) {
          final url = urls[widget.items[i].publicId];
          if (url != null) _resolvedUrls[i] = url;
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.items.length}',
          style: const TextStyle(fontSize: 15),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) {
          // Pause any playing video when swiping away
          _pauseCurrentVideo();
          setState(() => _currentIndex = i);
        },
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final url = _resolvedUrls[index];

          if (url == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (item.isVideo) {
            return _VideoViewerWidget(
              url: url,
              onControllerCreated: (c) => _videoControllers[index] = c,
            );
          }

          // Image with pinch-to-zoom
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _pauseCurrentVideo() {
    final ctrl = _videoControllers[_currentIndex];
    if (ctrl != null && ctrl.value.isPlaying) {
      ctrl.pause();
    }
  }
}

/// A video player widget that only loads when tapped.
class _VideoViewerWidget extends StatefulWidget {
  final String url;
  final void Function(VideoPlayerController)? onControllerCreated;

  const _VideoViewerWidget({
    required this.url,
    this.onControllerCreated,
  });

  @override
  State<_VideoViewerWidget> createState() => _VideoViewerWidgetState();
}

class _VideoViewerWidgetState extends State<_VideoViewerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    if (_isLoading || _isInitialized) return;
    setState(() => _isLoading = true);

    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = controller;
      widget.onControllerCreated?.call(controller);

      await controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        controller.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 48),
            SizedBox(height: 8),
            Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return GestureDetector(
        onTap: _initPlayer,
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
                    semanticLabel: 'Play video',
                  ),
                ),
        ),
      );
    }

    final ctrl = _controller!;
    return GestureDetector(
      onTap: () {
        setState(() {
          ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: VideoPlayer(ctrl),
            ),
          ),
          // Play/Pause overlay
          if (!ctrl.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          // Controls bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _VideoProgressBar(controller: ctrl),
          ),
        ],
      ),
    );
  }
}

class _VideoProgressBar extends StatelessWidget {
  final VideoPlayerController controller;
  const _VideoProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withValues(alpha: 0.5),
      child: Row(
        children: [
          // Mute button
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, child) => IconButton(
              icon: Icon(
                value.volume > 0
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                controller.setVolume(value.volume > 0 ? 0 : 1);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          // Progress
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.primary,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white10,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          // Duration
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final pos = value.position;
              final dur = value.duration;
              return Text(
                '${_fmt(pos)} / ${_fmt(dur)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
