import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

/// Error thrown for any failed API call. [message] is safe to show to users.
class CareApiException implements Exception {
  final int? statusCode;
  final String message;

  const CareApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Thin HTTP layer shared by the events, vets and appointments providers.
class CareApi {
  CareApi._();

  static String get baseUrl => AppConfig.baseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  static Future<dynamic> get(String path) => _send('GET', path);

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);

  static Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _send('PATCH', path, body);

  static Future<Map<String, String>> _headers({bool forceRefresh = false}) async {
    String? token;
    try {
      token = await FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
    } catch (_) {
      token = null;
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool tokenRefreshed = false,
  ]) async {
    if (kReleaseMode && baseUrl.contains('localhost')) {
      throw const CareApiException(
          'App is not configured with a server address (API_BASE_URL).');
    }

    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(forceRefresh: tokenRefreshed);
    final encoded = body == null ? null : jsonEncode(body);

    final http.Response res;
    try {
      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: headers, body: encoded)
              .timeout(_timeout);
          break;
        case 'PATCH':
          res = await http.patch(uri, headers: headers, body: encoded)
              .timeout(_timeout);
          break;
        default:
          res = await http.get(uri, headers: headers).timeout(_timeout);
      }
    } on TimeoutException {
      throw const CareApiException(
          'The server took too long to respond. Please try again.');
    } on http.ClientException {
      throw const CareApiException(
          'Could not reach the server. Check your internet connection.');
    }

    dynamic decoded;
    if (res.body.isNotEmpty) {
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

    // An expired token must not make a bookmark/booking look rejected. Refresh
    // once and replay the request before reporting an error.
    if (res.statusCode == 401 && !tokenRefreshed) {
      try {
        final refreshed =
            await FirebaseAuth.instance.currentUser?.getIdToken(true);
        if (refreshed != null && refreshed.isNotEmpty) {
          return await _send(method, path, body, true);
        }
      } catch (_) {
        // Fall through to the normal 401 error below.
      }
    }

    throw CareApiException(
      _messageFor(res.statusCode, decoded),
      statusCode: res.statusCode,
    );
  }

  static String _messageFor(int status, dynamic decoded) {
    if (status == 401) return 'Your session has expired. Please sign in again.';
    if (status == 403) return 'You do not have permission to do that.';
    if (status >= 500) return 'Something went wrong on our side. Please try again.';
    if (decoded is Map) {
      final m = decoded['message'] ?? decoded['error'];
      if (m is String && m.trim().isNotEmpty) return m;
    }
    if (status == 404) return 'That item could not be found.';
    return 'Request failed ($status).';
  }

  /// Pulls a list out of `[...]`, `{data: [...]}` or `{data: {key: [...]}}`.
  static List<Map<String, dynamic>> extractList(
    dynamic decoded,
    List<String> possibleKeys,
  ) {
    List<dynamic> raw = const [];
    if (decoded is List) {
      raw = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final inner = decoded['data'] ?? decoded;
      if (inner is List) {
        raw = inner;
      } else if (inner is Map<String, dynamic>) {
        for (final key in possibleKeys) {
          if (inner[key] is List) {
            raw = inner[key] as List;
            break;
          }
        }
        if (raw.isEmpty) {
          for (final v in inner.values) {
            if (v is List) {
              raw = v;
              break;
            }
          }
        }
      }
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// Pulls a single object out of `{...}`, `{data: {...}}` or `{data: {key: {...}}}`.
  static Map<String, dynamic>? extractMap(dynamic decoded, List<String> keys) {
    if (decoded is! Map<String, dynamic>) return null;
    final inner = decoded['data'] ?? decoded;
    if (inner is! Map<String, dynamic>) return null;
    for (final key in keys) {
      if (inner[key] is Map<String, dynamic>) {
        return inner[key] as Map<String, dynamic>;
      }
    }
    return inner;
  }
}
