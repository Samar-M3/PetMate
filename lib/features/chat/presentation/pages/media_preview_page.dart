import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/chat_constants.dart';
import '../../data/services/chat_media_service.dart';
import '../../domain/entities/chat_entities.dart';

/// Screen for reviewing picked media, removing items, adding captions, and sending.
class MediaPreviewPage extends ConsumerStatefulWidget {
  final List<LocalMediaFile> initialFiles;
  final String conversationId;
  final ReplyToData? replyTo;

  const MediaPreviewPage({
    super.key,
    required this.initialFiles,
    required this.conversationId,
    this.replyTo,
  });

  @override
  ConsumerState<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends ConsumerState<MediaPreviewPage> {
  late List<LocalMediaFile> _files;
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;
  MediaUploadProgress? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.initialFiles);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _removeItem(int index) {
    setState(() {
      _files.removeAt(index);
    });
    if (_files.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addMoreMedia() async {
    if (_files.length >= ChatConstants.maxMediaPerMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum ${ChatConstants.maxMediaPerMessage} items allowed per message.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final mediaService = ref.read(chatMediaServiceProvider);
      final newFiles = await mediaService.pickMediaFromGallery();
      if (newFiles.isNotEmpty) {
        setState(() {
          final availableSlots =
              ChatConstants.maxMediaPerMessage - _files.length;
          _files.addAll(newFiles.take(availableSlots));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _send() async {
    if (_files.isEmpty || _isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final mediaService = ref.read(chatMediaServiceProvider);
      await mediaService.sendMediaMessage(
        conversationId: widget.conversationId,
        mediaFiles: _files,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
        replyTo: widget.replyTo,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_files.length} / ${ChatConstants.maxMediaPerMessage} selected',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_files.length < ChatConstants.maxMediaPerMessage && !_isUploading)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Add more',
              onPressed: _addMoreMedia,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Upload progress indicator if uploading
            if (_isUploading) ...[
              LinearProgressIndicator(
                value: _uploadProgress?.overallProgress ?? 0.0,
                backgroundColor: Colors.white24,
                color: AppColors.primary,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _uploadProgress?.status == MediaUploadStatus.finalizing
                      ? 'Finalizing message...'
                      : 'Uploading item ${(_uploadProgress?.currentItemIndex ?? 0) + 1} of ${_files.length}...',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],

            // Main Preview Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: _files.length,
                itemBuilder: (ctx, index) {
                  final item = _files[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.isVideo
                            ? Container(
                                color: Colors.grey[900],
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.videocam_rounded,
                                        color: Colors.white70,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 6),
                                      if (item.durationSeconds != null)
                                        Text(
                                          '${item.durationSeconds!.round()}s',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : Image.memory(
                                item.bytes,
                                fit: BoxFit.cover,
                              ),
                      ),

                      // Video badge
                      if (item.isVideo)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'VIDEO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Remove button
                      if (!_isUploading)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => _removeItem(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // Bottom bar with caption and Send button
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              color: Colors.grey[950],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      enabled: !_isUploading,
                      style: const TextStyle(color: Colors.white),
                      maxLength: 1000,
                      buildCounter: (_, {required currentLength, maxLength, required isFocused}) => null,
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white12,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: _isUploading
                        ? Colors.white24
                        : AppColors.terracotta,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isUploading ? null : _send,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _isUploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
