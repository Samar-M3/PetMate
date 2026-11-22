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

  /// Upload an image file via multipart/form-data.
  /// Field name: "image".
  Future<String?> uploadImage(
    File? file, {
    String folder = 'uploads',
    Uint8List? bytes,
    String? filename,
  }) async {
    final response = await apiClient.postMultipart(
      '/uploads',
      file: file,
      bytes: bytes,
      filename: filename,
      fieldName: 'image',
      fields: {'folder': folder},
    );

    if (response is Map<String, dynamic>) {
      return (response['imageUrl'] ?? response['url']) as String?;
    }
    return null;
  }

  /// Upload user avatar using dedicated /users/me/avatar endpoint.
  Future<String?> uploadUserAvatar(
    File? file, {
    Uint8List? bytes,
    String? filename,
  }) async {
    final response = await apiClient.postMultipart(
      '/users/me/avatar',
      file: file,
      bytes: bytes,
      filename: filename,
      fieldName: 'image',
    );

    if (response is Map<String, dynamic>) {
      return (response['imageUrl'] ?? response['url']) as String?;
    }
    return null;
  }

  /// Upload pet photo using dedicated /pets/:id/image endpoint.
  Future<String?> uploadPetImage(
    String petId,
    File? file, {
    Uint8List? bytes,
    String? filename,
  }) async {
    final response = await apiClient.postMultipart(
      '/pets/$petId/image',
      file: file,
      bytes: bytes,
      filename: filename,
      fieldName: 'image',
    );

    if (response is Map<String, dynamic>) {
      return (response['imageUrl'] ?? response['url']) as String?;
    }
    return null;
  }

  /// Delete pet photo from Cloudinary and DB.
  Future<void> deletePetImage(String petId) async {
    await apiClient.delete('/pets/$petId/image');
  }
}
