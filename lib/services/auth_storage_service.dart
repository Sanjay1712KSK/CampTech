import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredCredentials {
  final String email;
  final String password;

  const StoredCredentials({
    required this.email,
    required this.password,
  });
}

class AuthStorageService {
  static const _biometricPrefKey = 'biometric_enabled';
  static const _emailKey = 'secure_email';
  static const _passwordKey = 'secure_password';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  static Future<StoredCredentials?> getCredentials() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null || email.isEmpty || password.isEmpty) {
      return null;
    }
    return StoredCredentials(email: email, password: password);
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
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
