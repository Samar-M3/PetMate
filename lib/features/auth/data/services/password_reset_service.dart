import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';

/// Service for password reset API calls.
/// These endpoints are unauthenticated — no Firebase token required.
class PasswordResetService {
  final http.Client _client;

  PasswordResetService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl => AppConfig.baseUrl;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  /// Step 1: Request an OTP for password reset.
  /// Returns a user-facing message from the backend.
  Future<PasswordResetResult> requestOTP(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/forgot-password'),
            headers: _headers,
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return PasswordResetResult(
          success: true,
          message: body['message'] as String? ?? 'Verification code sent',
        );
      }

      return PasswordResetResult(
        success: false,
        message: body['message'] as String? ?? 'Failed to send verification code',
      );
    } catch (e) {
      return PasswordResetResult(
        success: false,
        message: _parseError(e),
      );
    }
  }

  /// Step 2: Verify the 6-digit OTP.
  /// Returns the reset token on success.
  Future<OTPVerifyResult> verifyOTP(String email, String otp) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/verify-reset-otp'),
            headers: _headers,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'otp': otp.trim(),
            }),
          )
          .timeout(AppConfig.connectTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = body['data'] as Map<String, dynamic>?;
        final resetToken = data?['resetToken'] as String?;
        if (resetToken == null || resetToken.isEmpty) {
          return OTPVerifyResult(
            success: false,
            message: 'Invalid server response',
          );
        }
        return OTPVerifyResult(
          success: true,
          message: body['message'] as String? ?? 'Verification successful',
          resetToken: resetToken,
        );
      }

      return OTPVerifyResult(
        success: false,
        message: body['message'] as String? ?? 'Invalid verification code',
      );
    } catch (e) {
      return OTPVerifyResult(
        success: false,
        message: _parseError(e),
      );
    }
  }

  /// Step 3: Reset the password using the reset token.
  Future<PasswordResetResult> resetPassword(
    String email,
    String resetToken,
    String newPassword,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/reset-password'),
            headers: _headers,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'resetToken': resetToken,
              'newPassword': newPassword,
            }),
          )
          .timeout(AppConfig.connectTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return PasswordResetResult(
          success: true,
          message: body['message'] as String? ?? 'Password reset successful',
        );
      }

      return PasswordResetResult(
        success: false,
        message: body['message'] as String? ?? 'Failed to reset password',
      );
    } catch (e) {
      return PasswordResetResult(
        success: false,
        message: _parseError(e),
      );
    }
  }

  String _parseError(Object e) {
    if (e.toString().contains('SocketException') ||
        e.toString().contains('Connection refused')) {
      return 'Unable to connect to server. Please check your internet connection.';
    }
    if (e.toString().contains('TimeoutException')) {
      return 'Request timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class PasswordResetResult {
  final bool success;
  final String message;

  PasswordResetResult({required this.success, required this.message});
}

class OTPVerifyResult {
  final bool success;
  final String message;
  final String? resetToken;

  OTPVerifyResult({
    required this.success,
    required this.message,
    this.resetToken,
  });
}
