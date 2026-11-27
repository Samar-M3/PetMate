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
import 'storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return ApiClient(firebaseAuth: firebaseAuth, storageService: storageService);
});

class ApiClient {
  final FirebaseAuthService firebaseAuth;
  final StorageService? storageService;
  final http.Client client;

  static final Map<String, int> _activeInFlight = {};
  static final Map<String, int> _duplicateCounts = {};
  static final Map<String, List<int>> _endpointDurations = {};

  static final Map<String, Future<dynamic>> _inFlightGetRequests = {};
  static final Map<String, Future<dynamic>> _inFlightPostRequests = {};

  ApiClient({
    required this.firebaseAuth,
    this.storageService,
    http.Client? client,
  }) : client = client ?? http.Client();

  static void printTimingReport() {
    debugPrint('=== ApiClient Endpoint Timing & Duplicate Report ===');

    for (final entry in _endpointDurations.entries) {
      final list = entry.value;
      if (list.isEmpty) continue;

      final avg = list.reduce((a, b) => a + b) / list.length;
      final max = list.reduce((a, b) => a > b ? a : b);
      final dupes = _duplicateCounts[entry.key] ?? 0;

      debugPrint(
        '${entry.key}: count=${list.length}, '
        'avg=${avg.toStringAsFixed(1)}ms, max=${max}ms, dupes=$dupes',
      );
    }

    debugPrint('====================================================');
  }

  Future<dynamic> _measuredRequest(
    String method,
    Uri uri,
    Future<dynamic> Function() fn,
  ) async {
    if (!kDebugMode) return fn();

    final key = '$method ${uri.path}';
    final active = _activeInFlight[key] ?? 0;

    _activeInFlight[key] = active + 1;

    if (active > 0) {
      _duplicateCounts[key] = (_duplicateCounts[key] ?? 0) + 1;

      debugPrint(
        '[ApiClient] DUPLICATE IN-FLIGHT: $key '
        '(active: ${_activeInFlight[key]}, '
        'duplicate count: ${_duplicateCounts[key]})',
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final result = await fn();
      stopwatch.stop();

      final ms = stopwatch.elapsedMilliseconds;

      _endpointDurations.putIfAbsent(key, () => []).add(ms);

      final slowFlag = ms > 500 ? ' [SLOW >500ms]' : '';

      debugPrint('[ApiClient] $key completed in ${ms}ms$slowFlag');

      return result;
    } catch (error) {
      stopwatch.stop();

      debugPrint(
        '[ApiClient] $key failed after '
        '${stopwatch.elapsedMilliseconds}ms: $error',
      );

      rethrow;
    } finally {
      final current = _activeInFlight[key] ?? 1;

      if (current <= 1) {
        _activeInFlight.remove(key);
      } else {
        _activeInFlight[key] = current - 1;
      }
    }
  }

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool forceRefresh = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    var token = await firebaseAuth.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      token = storageService?.getAuthToken();
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// Joins AppConfig.baseUrl and the request path without duplicating
  /// overlapping path segments.
  ///
  /// Example:
  /// baseUrl = https://example.com/api
  /// path    = /api/v1/devices
  /// result  = https://example.com/api/v1/devices
  ///
  /// Also supports:
  /// baseUrl = https://example.com
  /// path    = /api/v1/devices
  /// result  = https://example.com/api/v1/devices
  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final baseUri = Uri.parse(AppConfig.baseUrl);
    final requestUri = Uri.parse(path.startsWith('/') ? path : '/$path');

    if (requestUri.hasScheme) {
      throw ArgumentError(
        'ApiClient paths must be relative paths, not full URLs.',
      );
    }

    final baseSegments = baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    final requestSegments = requestUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    // Find the largest overlap between the end of the base path and
    // the beginning of the requested path.
    var overlap = 0;
    final maxOverlap = baseSegments.length < requestSegments.length
        ? baseSegments.length
        : requestSegments.length;

    for (var count = maxOverlap; count > 0; count--) {
      final baseSuffix = baseSegments.sublist(baseSegments.length - count);
      final requestPrefix = requestSegments.sublist(0, count);

      if (listEquals(baseSuffix, requestPrefix)) {
        overlap = count;
        break;
      }
    }

    final combinedSegments = <String>[
      ...baseSegments,
      ...requestSegments.skip(overlap),
    ];

    final combinedPath = '/${combinedSegments.join('/')}';

    // Preserve query parameters embedded in paths, such as
    // /messages/123?scope=everyone.
    final mergedQueryParameters = <String, String>{
      ...requestUri.queryParameters,
    };

    if (queryParameters != null) {
      for (final entry in queryParameters.entries) {
        mergedQueryParameters[entry.key] = entry.value.toString();
      }
    }

    return baseUri.replace(
      path: combinedPath,
      queryParameters: mergedQueryParameters.isEmpty
          ? null
          : mergedQueryParameters,
      fragment: requestUri.fragment.isNotEmpty ? requestUri.fragment : null,
    );
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);

    final key = '${firebaseAuth.currentUser?.uid ?? ''}|$uri';

    final existingFuture = _inFlightGetRequests[key];

    if (existingFuture != null) {
      if (kDebugMode) {
        debugPrint('[ApiClient] MERGED duplicate in-flight GET: $uri');
      }

      return existingFuture;
    }

    final future = _measuredRequest('GET', uri, () {
      return _sendWithRetry((forceRefresh) async {
        final headers = await _buildHeaders(forceRefresh: forceRefresh);

        if (kDebugMode) {
          debugPrint('[ApiClient] GET $uri');
        }

        return client
            .get(uri, headers: headers)
            .timeout(AppConfig.connectTimeout);
      });
    });

    _inFlightGetRequests[key] = future;

    try {
      return await future;
    } finally {
      if (identical(_inFlightGetRequests[key], future)) {
        _inFlightGetRequests.remove(key);
      }
    }
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    final uri = _buildUri(path);

    // Only deduplicate the media URL lookup POST.
    // Other POST requests may create resources or trigger actions.
    final isIdempotentPost = path.contains('/media/urls');

    final dedupKey = isIdempotentPost
        ? '${firebaseAuth.currentUser?.uid ?? ''}|$uri|'
              '${body != null ? jsonEncode(body) : ''}'
        : null;

    if (dedupKey != null) {
      final existingFuture = _inFlightPostRequests[dedupKey];

      if (existingFuture != null) {
        if (kDebugMode) {
          debugPrint('[ApiClient] MERGED duplicate in-flight POST: $uri');
        }

        return existingFuture;
      }
    }

    final future = _measuredRequest('POST', uri, () {
      return _sendWithRetry((forceRefresh) async {
        final headers = await _buildHeaders(forceRefresh: forceRefresh);

        if (kDebugMode) {
          debugPrint('[ApiClient] POST $uri');
        }

        return client
            .post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(AppConfig.connectTimeout);
      });
    });

    if (dedupKey == null) {
      return future;
    }

    _inFlightPostRequests[dedupKey] = future;

    try {
      return await future;
    } finally {
      if (identical(_inFlightPostRequests[dedupKey], future)) {
        _inFlightPostRequests.remove(dedupKey);
      }
    }
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    final uri = _buildUri(path);

    return _measuredRequest('PUT', uri, () {
      return _sendWithRetry((forceRefresh) async {
        final headers = await _buildHeaders(forceRefresh: forceRefresh);

        if (kDebugMode) {
          debugPrint('[ApiClient] PUT $uri');
        }

        return client
            .put(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(AppConfig.connectTimeout);
      });
    });
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    final uri = _buildUri(path);

    return _measuredRequest('PATCH', uri, () {
      return _sendWithRetry((forceRefresh) async {
        final headers = await _buildHeaders(forceRefresh: forceRefresh);

        if (kDebugMode) {
          debugPrint('[ApiClient] PATCH $uri');
        }

        return client
            .patch(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(AppConfig.connectTimeout);
      });
    });
  }

  Future<dynamic> delete(String path) async {
    final uri = _buildUri(path);

    return _measuredRequest('DELETE', uri, () {
      return _sendWithRetry((forceRefresh) async {
        final headers = await _buildHeaders(forceRefresh: forceRefresh);

        if (kDebugMode) {
          debugPrint('[ApiClient] DELETE $uri');
        }

        return client
            .delete(uri, headers: headers)
            .timeout(AppConfig.connectTimeout);
      });
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
      var token = await firebaseAuth.getIdToken(forceRefresh);
      if (token == null || token.isEmpty) {
        token = storageService?.getAuthToken();
      }
      final uri = _buildUri(path);

      if (kDebugMode) {
        debugPrint('[ApiClient] POST MULTIPART $uri (field: $fieldName)');
      }

      final request = http.MultipartRequest('POST', uri);

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.headers['Accept'] = 'application/json';

      if (fields != null) {
        request.fields.addAll(fields);
      }

      List<int> fileBytes = [];

      if (bytes != null) {
        fileBytes = bytes;
      } else if (file != null) {
        fileBytes = await file.readAsBytes();
      }

      if (fileBytes.isEmpty) {
        throw ArgumentError('Cannot upload an empty file.');
      }

      final resolvedFilename =
          filename ??
          (file != null && file.path.isNotEmpty
              ? file.path.split(RegExp(r'[\\/]')).last
              : 'upload.jpg');

      final contentType = _resolveImageContentType(resolvedFilename, fileBytes);

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          fileBytes,
          filename: resolvedFilename.isNotEmpty
              ? resolvedFilename
              : 'upload.jpg',
          contentType: contentType,
        ),
      );

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
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return MediaType('image', 'webp');
    }

    final lower = filename.toLowerCase();

    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }

    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }

    return MediaType('image', 'jpeg');
  }

  Future<dynamic> _sendWithRetry(
    Future<http.Response> Function(bool forceRefresh) requestFn,
  ) async {
    try {
      final response = await requestFn(false);

      if (kDebugMode) {
        debugPrint(
          '[ApiClient] Received response '
          '${response.statusCode} (${response.body.length} bytes)',
        );
      }

      if (response.statusCode == 401 && firebaseAuth.currentUser != null) {
        if (kDebugMode) {
          debugPrint(
            '[ApiClient] 401 Unauthorized. '
            'Refreshing token and retrying once.',
          );
        }

        final retryResponse = await requestFn(true);

        if (kDebugMode) {
          debugPrint('[ApiClient] Retry response: ${retryResponse.statusCode}');
        }

        return _handleResponse(retryResponse);
      }

      return _handleResponse(response);
    } on SocketException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[ApiClient] SocketException: ${error.message} '
          '(OS Error: ${error.osError})',
        );
      }

      throw NetworkException(
        'Unable to reach server. Please check backend is running '
        'and URL is reachable.',
      );
    } on TimeoutException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[ApiClient] TimeoutException after '
          '${AppConfig.connectTimeout.inSeconds}s: ${error.message}',
        );
      }

      throw NetworkException(
        'Request timed out. Please check your server connectivity.',
      );
    } on AppException {
      rethrow;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ApiClient] Unexpected request error: $error');
      }

      throw ApiException(
        message: 'An unexpected error occurred: ${error.toString()}',
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

    var message = 'Request failed with status ${response.statusCode}';

    var errors = <String>[];

    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] is String) {
        message = decoded['message'] as String;
      }

      if (decoded['errors'] is List) {
        errors = (decoded['errors'] as List)
            .map((error) => error.toString())
            .toList();
      }
    }

    if (kDebugMode) {
      debugPrint('[ApiClient] API Error [${response.statusCode}]: $message');
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
