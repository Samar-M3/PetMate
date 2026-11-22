import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CloudinaryService(apiClient: apiClient);
});

class CloudinaryService {
  final ApiClient apiClient;

  CloudinaryService({required this.apiClient});

  Future<String?> uploadImage(
    File? file, {
    Uint8List? bytes,
    String? filename,
    String folder = 'petmate_uploads',
  }) async {
    Uint8List? rawBytes = bytes;
    if (rawBytes == null && file != null) {
      rawBytes = await file.readAsBytes();
    }
    if (rawBytes == null) {
      return null;
    }
    final base64Image = 'data:image/jpeg;base64,${base64Encode(rawBytes)}';

    final response = await apiClient.post(
      '/uploads',
      body: {
        'image': base64Image,
        'folder': folder,
      },
    );

    if (response is Map<String, dynamic>) {
      if (response['url'] != null) {
        return response['url'] as String;
      }
      if (response['secure_url'] != null) {
        return response['secure_url'] as String;
      }
      if (response['data'] is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>;
        return data['url'] as String? ?? data['secure_url'] as String?;
      }
    }
    return null;
  }

  Future<String?> uploadUserAvatar(
    File? file, {
    Uint8List? bytes,
    String? filename,
  }) async {
    return uploadImage(file, bytes: bytes, filename: filename, folder: 'avatars');
  }
}
