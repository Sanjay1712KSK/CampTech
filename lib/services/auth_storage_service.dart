import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredSession {
  final String accessToken;
  final AuthUser user;

  const StoredSession({
    required this.accessToken,
    required this.user,
  });
}

class AuthStorageService {
  static const _biometricPrefKey = 'biometric_enabled';
  static const _accessTokenKey = 'secure_access_token';
  static const _userKey = 'secure_user_profile';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveSession({
    required String accessToken,
    required AuthUser user,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  static Future<StoredSession?> getSession() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final userJson = await _storage.read(key: _userKey);
    if (accessToken == null || userJson == null || accessToken.isEmpty || userJson.isEmpty) {
      return null;
    }
    final user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    return StoredSession(accessToken: accessToken, user: user);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _userKey);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricPrefKey) ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      await prefs.setBool(_biometricPrefKey, true);
    } else {
      await prefs.remove(_biometricPrefKey);
    }
  }
}
