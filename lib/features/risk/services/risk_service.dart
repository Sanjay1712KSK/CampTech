import 'dart:async';
import 'dart:convert';

import 'package:guidewire_gig_ins/config.dart';
import 'package:guidewire_gig_ins/features/risk/models/risk_model.dart';
import 'package:http/http.dart' as http;

class RiskServiceException implements Exception {
  final String message;

  const RiskServiceException(this.message);

  @override
  String toString() => message;
}

class RiskService {
  static const Duration _timeout = Duration(seconds: 15);

  Future<RiskModel> fetchRisk({
    required int userId,
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/risk').replace(
      queryParameters: {
        'user_id': '$userId',
        'lat': '$lat',
        'lon': '$lon',
      },
    );

    http.Response response;
    try {
      response = await http.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const RiskServiceException(
        'Risk service timed out. Pull to refresh and try again.',
      );
    } catch (_) {
      throw const RiskServiceException(
        'Unable to reach the backend. Check the API base URL and make sure the backend is running.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RiskServiceException(
        _decodeError(response.body) ?? 'Risk API failed (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const RiskServiceException('Unexpected risk response from backend.');
    }
    return RiskModel.fromJson(decoded);
  }

  String? _decodeError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['detail'] ?? decoded['message'] ?? decoded['error'])?.toString();
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
