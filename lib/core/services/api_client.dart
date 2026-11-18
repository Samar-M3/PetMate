import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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

  ApiClient({
    required this.firebaseAuth,
    http.Client? client,
  }) : client = client ?? http.Client();

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

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _sendWithRetry((forceRefresh) async {
      final headers = await _buildHeaders(forceRefresh: forceRefresh);
      final uri = _buildUri(path, queryParameters);
      debugPrint('[ApiClient] 🚀 GET $uri');
      return await client
          .get(uri, headers: headers)
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    return _sendWithRetry((forceRefresh) async {
      final headers = await _buildHeaders(forceRefresh: forceRefresh);
      final uri = _buildUri(path);
      debugPrint('[ApiClient] 🚀 POST $uri');
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
      debugPrint('[ApiClient] 🚀 PUT $uri');
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
      debugPrint('[ApiClient] 🚀 PATCH $uri');
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
      debugPrint('[ApiClient] 🚀 DELETE $uri');
      return await client
          .delete(uri, headers: headers)
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> _sendWithRetry(Future<http.Response> Function(bool forceRefresh) requestFn) async {
    try {
      final response = await requestFn(false);
      debugPrint('[ApiClient] 📥 Received response ${response.statusCode} (${response.body.length} bytes)');
      // If token expired, try refreshing once
      if (response.statusCode == 401 && firebaseAuth.currentUser != null) {
        debugPrint('[ApiClient] 🔄 401 Unauthorized received, attempting token force-refresh and retry...');
        final retryResponse = await requestFn(true);
        debugPrint('[ApiClient] 📥 Retry response: ${retryResponse.statusCode}');
        return _handleResponse(retryResponse);
      }
      return _handleResponse(response);
    } on SocketException catch (e) {
      debugPrint('[ApiClient] ❌ SocketException: ${e.message} (OS Error: ${e.osError})');
      throw NetworkException('Unable to reach server. Please check backend is running and URL is reachable.');
    } on TimeoutException catch (e) {
      debugPrint('[ApiClient] ⏱️ TimeoutException after ${AppConfig.connectTimeout.inSeconds}s: ${e.message}');
      throw NetworkException('Request timed out. Please check your server connectivity.');
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('[ApiClient] ❌ Unexpected error in request: $e');
      throw ApiException(message: 'An unexpected error occurred: ${e.toString()}');
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

    debugPrint('[ApiClient] ⚠️ API Error [${response.statusCode}]: $message');

    if (response.statusCode == 401) {
      throw AuthException(message);
    }

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      errors: errors,
    );
  }
}
