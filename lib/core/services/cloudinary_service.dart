import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CloudinaryService(apiClient: apiClient);
});

class CloudinaryService {
  final ApiClient apiClient;

  CloudinaryService({required this.apiClient});

  Future<String?> uploadImage(File file, {String folder = 'petmate_uploads'}) async {
    final bytes = await file.readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    final response = await apiClient.post(
      '/uploads',
      body: {
        'image': base64Image,
        'folder': folder,
      },
    );

    if (response is Map<String, dynamic> && response['url'] != null) {
      return response['url'] as String;
    }
    return null;
  }
}
