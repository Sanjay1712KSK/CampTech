import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:guidewire_gig_ins/config.dart';

/// Response model for signup / login
class AuthResult {
  final int userId;
  final bool isVerified;

  const AuthResult({required this.userId, required this.isVerified});
}

/// Response model for DigiLocker request
class DigiLockerRequestResult {
  final String requestId;
  final String status;

  const DigiLockerRequestResult({required this.requestId, required this.status});
}

/// Response model for DigiLocker consent
class DigiLockerConsentResult {
  final bool verified;
  final String? reason;

  const DigiLockerConsentResult({required this.verified, this.reason});
}

class ApiService {
  static const String _signupPath = '/auth/signup';
  static const String _loginPath = '/auth/login';
  static const String _digilockerRequestPath = '/digilocker/request';
  static const String _digilockerConsentPath = '/digilocker/consent';

  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> get _headers =>
      {'Content-Type': 'application/json'};

  // ─── SIGNUP ─────────────────────────────────────────────────────────────────
  /// Returns [AuthResult] with the userId on success, throws on failure.
  static Future<AuthResult> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}$_signupPath');
    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'email': email,
              'phone': phone,
              'password': password,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Backend returns user object with "id" or "user_id"
        final id = (body['id'] ?? body['user_id']) as int;
        final isVerified = (body['is_verified'] as bool?) ?? false;
        return AuthResult(userId: id, isVerified: isVerified);
      }

      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Signup failed (${response.statusCode})');
    } on SocketException {
      throw Exception('Server not reachable');
    }
  }

  // ─── LOGIN ───────────────────────────────────────────────────────────────────
  /// Returns [AuthResult] with the userId on success, throws on failure.
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}$_loginPath');
    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final id = (body['id'] ?? body['user_id']) as int;
        final isVerified = (body['is_verified'] as bool?) ?? false;
        return AuthResult(userId: id, isVerified: isVerified);
      }

      if (response.statusCode == 401 || response.statusCode == 400) {
        throw Exception('Invalid credentials');
      }

      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Login failed (${response.statusCode})');
    } on SocketException {
      throw Exception('Server not reachable');
    }
  }

  // ─── DIGILOCKER REQUEST ──────────────────────────────────────────────────────
  /// Step 1: Initiate DigiLocker — returns a [requestId].
  static Future<DigiLockerRequestResult> createDigiLockerRequest({
    required int userId,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}$_digilockerRequestPath');
    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return DigiLockerRequestResult(
          requestId: body['request_id'] as String,
          status: body['status'] as String? ?? 'PENDING',
        );
      }

      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'DigiLocker request failed (${response.statusCode})');
    } on SocketException {
      throw Exception('Server not reachable');
    }
  }

  // ─── DIGILOCKER CONSENT ──────────────────────────────────────────────────────
  /// Step 2: Submit document details for verification.
  static Future<DigiLockerConsentResult> submitDigiLockerConsent({
    required String requestId,
    required String documentType,   // 'aadhaar' or 'license'
    required String documentNumber,
    required String name,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}$_digilockerConsentPath');
    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'request_id': requestId,
              'document_type': documentType,
              'document_number': documentNumber,
              'name': name,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = body['status'] as String? ?? '';
        final reason = body['reason'] as String?;
        return DigiLockerConsentResult(
          verified: status.toUpperCase() == 'VERIFIED',
          reason: reason,
        );
      }

      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Verification failed (${response.statusCode})');
    } on SocketException {
      throw Exception('Server not reachable');
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────
  static String? _tryDecodeError(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      return (map['detail'] ?? map['message'] ?? map['error'])?.toString();
    } catch (_) {
      return null;
    }
  }
}
