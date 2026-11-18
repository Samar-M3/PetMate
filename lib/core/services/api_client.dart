import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'firebase_auth_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthServiceProvider);
  return ApiClient(firebaseAuth: firebaseAuth);
});

class ApiClient {
  final FirebaseAuthService firebaseAuth;
  final http.Client client;

  ApiClient({required this.firebaseAuth, http.Client? client})
    : client = client ?? http.Client();

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool forceRefresh = false,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await firebaseAuth.getIdToken(forceRefresh);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '${AppConfig.baseUrl}$normalizedPath';
    final uri = Uri.parse(fullUrl);

    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(
        queryParameters: queryParameters.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );
    }
    return uri;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _sendWithRetry((forceRefresh) async {
      final headers = await _buildHeaders(forceRefresh: forceRefresh);
      final uri = _buildUri(path, queryParameters);
      if (kDebugMode) {
        debugPrint('[ApiClient] 🚀 GET $uri');
      }
      return await client
          .get(uri, headers: headers)
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    return _sendWithRetry((forceRefresh) async {
      final headers = await _buildHeaders(forceRefresh: forceRefresh);
      final uri = _buildUri(path);
      if (kDebugMode) {
        debugPrint('[ApiClient] 🚀 POST $uri');
      }
      return await client
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    return _sendWithRetry((forceRefresh) async {
      final headers = await _buildHeaders(forceRefresh: forceRefresh);
      final uri = _buildUri(path);
      if (kDebugMode) {
        debugPrint('[ApiClient] 🚀 PUT $uri');
      }
      return await client
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    return _sendWithRetry((forceRefresh) async {
      final headers = await _buildHeaders(forceRefresh: forceRefresh);
      final uri = _buildUri(path);
      if (kDebugMode) {
        debugPrint('[ApiClient] 🚀 PATCH $uri');
      }
      return await client
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> delete(String path) async {
    return _sendWithRetry((forceRefresh) async {
      final headers = await _buildHeaders(forceRefresh: forceRefresh);
      final uri = _buildUri(path);
      if (kDebugMode) {
        debugPrint('[ApiClient] 🚀 DELETE $uri');
      }
      return await client
          .delete(uri, headers: headers)
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> postMultipart(
    String path, {
    File? file,
    Uint8List? bytes,
    String? filename,
    String fieldName = 'image',
    Map<String, String>? fields,
  }) async {
    return _sendWithRetry((forceRefresh) async {
      final token = await firebaseAuth.getIdToken(forceRefresh);
      final uri = _buildUri(path);
      if (kDebugMode) {
        debugPrint('[ApiClient] 🚀 POST MULTIPART $uri (field: $fieldName)');
      }

      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Read bytes safely without relying on http.MultipartFile.fromPath which throws
      // "Unsupported operation: MultipartFile is only supported where dart:io is available."
      List<int> fileBytes = [];
      if (bytes != null) {
        fileBytes = bytes;
      } else if (file != null) {
        fileBytes = await file.readAsBytes();
      }

      final resolvedFilename =
          filename ??
          (file != null && file.path.isNotEmpty
              ? file.path.split(RegExp(r'[\\/]')).last
              : 'upload.jpg');

      final contentType = _resolveImageContentType(resolvedFilename, fileBytes);

      final multipartFile = http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: resolvedFilename.isNotEmpty ? resolvedFilename : 'upload.jpg',
        contentType: contentType,
      );
      request.files.add(multipartFile);

      final streamedResponse = await client
          .send(request)
          .timeout(AppConfig.connectTimeout);
      return await http.Response.fromStream(streamedResponse);
    });
  }

  MediaType _resolveImageContentType(String filename, List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return MediaType('image', 'jpeg');
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return MediaType('image', 'png');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return MediaType('image', 'webp');
    }
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  Future<dynamic> _sendWithRetry(
    Future<http.Response> Function(bool forceRefresh) requestFn,
  ) async {
    try {
      final response = await requestFn(false);
      if (kDebugMode) {
        debugPrint(
          '[ApiClient] 📥 Received response ${response.statusCode} (${response.body.length} bytes)',
        );
      }
      // If token expired, try refreshing once
      if (response.statusCode == 401 && firebaseAuth.currentUser != null) {
        if (kDebugMode) {
          debugPrint(
            '[ApiClient] 🔄 401 Unauthorized received, attempting token force-refresh and retry...',
          );
        }
        final retryResponse = await requestFn(true);
        if (kDebugMode) {
          debugPrint(
            '[ApiClient] 📥 Retry response: ${retryResponse.statusCode}',
          );
        }
        return _handleResponse(retryResponse);
      }
      return _handleResponse(response);
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ApiClient] ❌ SocketException: ${e.message} (OS Error: ${e.osError})',
        );
      }
      throw NetworkException(
        'Unable to reach server. Please check backend is running and URL is reachable.',
      );
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ApiClient] ⏱️ TimeoutException after ${AppConfig.connectTimeout.inSeconds}s: ${e.message}',
        );
      }
      throw NetworkException(
        'Request timed out. Please check your server connectivity.',
      );
    } on AppException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiClient] ❌ Unexpected error in request: $e');
      }
      throw ApiException(
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    if (isSuccess) {
      if (decoded is Map<String, dynamic>) {
        return decoded['data'] ?? decoded;
      }
      return decoded;
    }

    String message = 'Request failed with status ${response.statusCode}';
    List<String> errors = [];

    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] is String) {
        message = decoded['message'];
      }
      if (decoded['errors'] is List) {
        errors = (decoded['errors'] as List).map((e) => e.toString()).toList();
      }
    }

    if (kDebugMode) {
      debugPrint('[ApiClient] ⚠️ API Error [${response.statusCode}]: $message');
    }

    if (response.statusCode == 401) {
      throw AuthException(message);
    }

    if (response.statusCode == 403) {
      throw ForbiddenException(message);
    }

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      errors: errors,
    );
  }
}
