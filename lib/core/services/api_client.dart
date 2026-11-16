import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiClient(storage: storage);
});

class ApiClient {
  final StorageService storage;
  final http.Client client;

  ApiClient({
    required this.storage,
    http.Client? client,
  }) : client = client ?? http.Client();

  Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = storage.getAuthToken();
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
    return _sendRequest(() async {
      final uri = _buildUri(path, queryParameters);
      return await client
          .get(uri, headers: _buildHeaders())
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    return _sendRequest(() async {
      final uri = _buildUri(path);
      return await client
          .post(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    return _sendRequest(() async {
      final uri = _buildUri(path);
      return await client
          .patch(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> delete(String path) async {
    return _sendRequest(() async {
      final uri = _buildUri(path);
      return await client
          .delete(uri, headers: _buildHeaders())
          .timeout(AppConfig.connectTimeout);
    });
  }

  Future<dynamic> _sendRequest(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn();
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException('Request timed out. Please try again.');
    } on AppException {
      rethrow;
    } catch (e) {
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

    // Handle Error response
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
