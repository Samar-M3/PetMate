import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/chat_constants.dart';
import '../../domain/entities/chat_entities.dart';
import '../repositories/chat_repository.dart';

/// Status of an upload operation.
enum MediaUploadStatus {
  idle,
  preparing,
  uploading,
  finalizing,
  completed,
  failed,
}

/// Progress model for tracking ongoing media uploads.
class MediaUploadProgress {
  final MediaUploadStatus status;
  final int totalItems;
  final int currentItemIndex;
  final double itemProgress; // 0.0 to 1.0
  final String? errorMessage;

  const MediaUploadProgress({
    this.status = MediaUploadStatus.idle,
    this.totalItems = 0,
    this.currentItemIndex = 0,
    this.itemProgress = 0.0,
    this.errorMessage,
  });

  double get overallProgress {
    if (totalItems == 0) return 0.0;
    return (currentItemIndex + itemProgress) / totalItems;
  }
}

/// Local media item ready for preview and upload.
/// Uses `XFile` and in-memory `Uint8List` for 100% cross-platform compatibility (Web & Mobile).
class LocalMediaFile {
  final XFile xFile;
  final Uint8List bytes;
  final String name;
  final bool isVideo;
  final int sizeBytes;
  final String extension;
  final double? durationSeconds;
  final int? width;
  final int? height;

  const LocalMediaFile({
    required this.xFile,
    required this.bytes,
    required this.name,
    required this.isVideo,
    required this.sizeBytes,
    required this.extension,
    this.durationSeconds,
    this.width,
    this.height,
  });

  String get mimeType {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case '3gp':
        return 'video/3gpp';
      case 'mkv':
        return 'video/x-matroska';
      case 'm4v':
        return 'video/x-m4v';
      default:
        return isVideo ? 'video/mp4' : 'image/jpeg';
    }
  }
}

class ChatMediaService {
  final ChatRepository _chatRepository;
  final ImagePicker _picker;

  ChatMediaService(this._chatRepository, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  /// Picks multiple images from the device gallery (not file explorer).
  /// Uses pickMultiImage which opens the native gallery picker directly.
  Future<List<LocalMediaFile>> pickMediaFromGallery() async {
    final pickedList = await _picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );

    if (pickedList.isEmpty) return [];

    final result = <LocalMediaFile>[];
    for (final xfile in pickedList) {
      final localFile = await _validateAndConvert(xfile);
      if (localFile != null) {
        result.add(localFile);
      }
    }
    return result;
  }

  /// Takes a photo using the device camera.
  Future<LocalMediaFile?> takePhoto() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (xfile == null) return null;
    return _validateAndConvert(xfile);
  }

  /// Records a video using the device camera, enforcing maximum duration.
  Future<LocalMediaFile?> recordVideo() async {
    final xfile = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: ChatConstants.maxVideoSeconds),
    );
    if (xfile == null) return null;
    return _validateAndConvert(xfile);
  }

  /// Validates a single `XFile` and converts it to a `LocalMediaFile`.
  /// Uses purely cross-platform calls to support Web, Android, iOS and Desktop.
  Future<LocalMediaFile?> _validateAndConvert(XFile xfile) async {
    final name = xfile.name.isNotEmpty
        ? xfile.name
        : xfile.path.split(RegExp(r'[\\/]')).last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final isVideo = ChatConstants.supportedVideoExtensions.contains(ext);
    final isImage = ChatConstants.supportedImageExtensions.contains(ext);

    if (!isVideo && !isImage) {
      throw Exception('Unsupported file format: .$ext');
    }

    final bytes = await xfile.readAsBytes();
    final sizeBytes = bytes.length;

    if (isImage) {
      final maxBytes = ChatConstants.maxImageMb * 1024 * 1024;
      if (sizeBytes > maxBytes) {
        throw Exception(
          'Image "$name" exceeds the ${ChatConstants.maxImageMb} MB limit.',
        );
      }
      return LocalMediaFile(
        xFile: xfile,
        bytes: bytes,
        name: name,
        isVideo: false,
        sizeBytes: sizeBytes,
        extension: ext,
      );
    } else {
      final maxBytes = ChatConstants.maxVideoMb * 1024 * 1024;
      if (sizeBytes > maxBytes) {
        throw Exception(
          'Video exceeds the ${ChatConstants.maxVideoMb} MB limit. Please select a shorter or smaller video.',
        );
      }

      // Check duration using VideoPlayerController
      double durationSeconds = 0;
      try {
        final ctrl = VideoPlayerController.networkUrl(Uri.parse(xfile.path));
        await ctrl.initialize();
        durationSeconds = ctrl.value.duration.inMilliseconds / 1000.0;
        await ctrl.dispose();
      } catch (_) {
        // Fallback: accept if duration read fails (e.g. platform codec limits)
      }

      if (durationSeconds > ChatConstants.maxVideoSeconds) {
        throw Exception(
          'Video duration (${durationSeconds.round()}s) exceeds the maximum allowed ${ChatConstants.maxVideoSeconds} seconds.',
        );
      }

      return LocalMediaFile(
        xFile: xfile,
        bytes: bytes,
        name: name,
        isVideo: true,
        sizeBytes: sizeBytes,
        extension: ext,
        durationSeconds: durationSeconds,
      );
    }
  }

  /// Uploads media files directly to Cloudinary using signed parameters,
  /// then creates the media message in Firestore via the backend.
  Future<void> sendMediaMessage({
    required String conversationId,
    required List<LocalMediaFile> mediaFiles,
    String? caption,
    ReplyToData? replyTo,
    void Function(MediaUploadProgress progress)? onProgress,
  }) async {
    if (mediaFiles.isEmpty) return;
    if (mediaFiles.length > ChatConstants.maxMediaPerMessage) {
      throw Exception(
        'Maximum ${ChatConstants.maxMediaPerMessage} items allowed per message.',
      );
    }

    onProgress?.call(
      MediaUploadProgress(
        status: MediaUploadStatus.preparing,
        totalItems: mediaFiles.length,
      ),
    );

    final uploadedItems = <Map<String, dynamic>>[];
    final clientMessageId =
        'msg_${DateTime.now().millisecondsSinceEpoch}_${mediaFiles.hashCode}';

    for (int i = 0; i < mediaFiles.length; i++) {
      final item = mediaFiles[i];

      onProgress?.call(
        MediaUploadProgress(
          status: MediaUploadStatus.uploading,
          totalItems: mediaFiles.length,
          currentItemIndex: i,
          itemProgress: 0.1,
        ),
      );

      // 1. Request signature from backend
      final sigData = await _chatRepository.requestMediaSignature(
        conversationId,
        kind: item.isVideo ? 'video' : 'image',
        mimeType: item.mimeType,
        sizeBytes: item.sizeBytes,
      );

      final cloudName = sigData['cloudName'] as String;
      final apiKey = sigData['apiKey'] as String;
      final timestamp = sigData['timestamp'].toString();
      final signature = sigData['signature'] as String;
      final folder = sigData['folder'] as String;
      final publicId = sigData['publicId'] as String;
      final resourceType = sigData['resourceType'] as String;
      final eager = sigData['eager'] as String? ?? '';
      final allowedFormats =
          (sigData['allowedFormats'] as List<dynamic>?)?.join(',') ?? '';

      onProgress?.call(
        MediaUploadProgress(
          status: MediaUploadStatus.uploading,
          totalItems: mediaFiles.length,
          currentItemIndex: i,
          itemProgress: 0.3,
        ),
      );

      // 2. Direct upload to Cloudinary using fromBytes (cross-platform safe)
      final uploadUri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
      );

      final request = http.MultipartRequest('POST', uploadUri);
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;
      request.fields['folder'] = folder;
      request.fields['public_id'] = publicId;
      request.fields['type'] = 'authenticated';
      if (eager.isNotEmpty) request.fields['eager'] = eager;
      if (allowedFormats.isNotEmpty) {
        request.fields['allowed_formats'] = allowedFormats;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          item.bytes,
          filename: item.name,
          contentType: MediaType.parse(item.mimeType),
        ),
      );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw Exception(
          'Media upload failed: ${streamedResponse.statusCode} - $responseBody',
        );
      }

      final resJson = jsonDecode(responseBody) as Map<String, dynamic>;
      String fullPublicId = resJson['public_id'] as String? ?? publicId;
      if (!fullPublicId.startsWith(folder)) {
        fullPublicId = '$folder/$fullPublicId';
      }
      final format = resJson['format'] as String? ?? item.extension;
      final width = (resJson['width'] as num?)?.toInt() ?? 0;
      final height = (resJson['height'] as num?)?.toInt() ?? 0;
      final bytes = (resJson['bytes'] as num?)?.toInt() ?? item.sizeBytes;
      final duration =
          (resJson['duration'] as num?)?.toDouble() ?? item.durationSeconds;

      uploadedItems.add({
        'kind': item.isVideo ? 'video' : 'image',
        'publicId': fullPublicId,
        'format': format,
        'width': width,
        'height': height,
        'bytes': bytes,
        if (item.isVideo && duration != null) 'durationSeconds': duration,
        if (item.isVideo) 'thumbnailPublicId': fullPublicId,
      });

      onProgress?.call(
        MediaUploadProgress(
          status: MediaUploadStatus.uploading,
          totalItems: mediaFiles.length,
          currentItemIndex: i,
          itemProgress: 1.0,
        ),
      );
    }

    // 3. Finalize: Call backend to create media message
    onProgress?.call(
      MediaUploadProgress(
        status: MediaUploadStatus.finalizing,
        totalItems: mediaFiles.length,
        currentItemIndex: mediaFiles.length,
        itemProgress: 1.0,
      ),
    );

    await _chatRepository.createMediaMessage(
      conversationId,
      clientMessageId: clientMessageId,
      items: uploadedItems,
      caption: caption,
      replyTo: replyTo,
    );

    onProgress?.call(
      MediaUploadProgress(
        status: MediaUploadStatus.completed,
        totalItems: mediaFiles.length,
        currentItemIndex: mediaFiles.length,
        itemProgress: 1.0,
      ),
    );
  }
}

final chatMediaServiceProvider = Provider<ChatMediaService>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatMediaService(repo);
});
