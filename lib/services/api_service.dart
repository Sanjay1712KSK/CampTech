import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:guidewire_gig_ins/config.dart';

class ApiService {
  static const String signupPath = '/auth/signup';
  static const String loginPath = '/auth/login';
  static const String verifyPath = '/auth/verify-identity';

  static Future<bool> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}$signupPath');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      return false;
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}$loginPath');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }

      return false;
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> verifyIdentity() async {
    final uri = Uri.parse('${Config.baseUrl}$verifyPath');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      }

      return false;
    } catch (e) {
      rethrow;
    }
  }
}
