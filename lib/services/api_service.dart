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
  static const String _environmentPath = '/environment';
  static const String _gigGenerateDataPath = '/gig/generate-data';
  static const String _gigBaselinePath = '/gig/baseline-income';
  static const String _gigTodayPath = '/gig/today-income';
  static const String _gigHistoryPath = '/gig/income-history';

  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> get _headers =>
      {'Content-Type': 'application/json'};

  // ── 📊 Gig Income Data ────────────────────────────────────────────────────

  static Future<bool> generateGigData(String platform, String identifier) async {
    try {
      final response = await http
          .post(Uri.parse('${Config.baseUrl}$_gigGenerateDataPath'),
              headers: _headers,
              body: jsonEncode({'platform': platform, 'identifier': identifier}))
          .timeout(_timeout);
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Network or server error: $e');
    }
  }

  static Future<BaselineIncomeModel> getBaselineIncome() async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}$_gigBaselinePath')).timeout(_timeout);
      if (response.statusCode == 200) return BaselineIncomeModel.fromJson(jsonDecode(response.body));
      throw Exception('Failed to load baseline income');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<TodayIncomeModel> getTodayIncome() async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}$_gigTodayPath')).timeout(_timeout);
      if (response.statusCode == 200) return TodayIncomeModel.fromJson(jsonDecode(response.body));
      throw Exception('Failed to load today income');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<IncomeHistoryModel> getIncomeHistory() async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}$_gigHistoryPath')).timeout(_timeout);
      if (response.statusCode == 200) return IncomeHistoryModel.fromJson(jsonDecode(response.body));
      throw Exception('Failed to load income history');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ── 🌍 Environment Data ───────────────────────────────────────────────────

  static Future<EnvironmentModel> getEnvironment(double lat, double lon) async {
    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}$_environmentPath?lat=$lat&lon=$lon'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return EnvironmentModel.fromJson(data);
      } else {
        throw Exception('Failed to load environment data');
      }
    } catch (e) {
      throw Exception('Network or server error: $e');
    }
  }

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

// ── 🌍 Environment Models ──────────────────────────────────────────────────

class EnvironmentModel {
  final WeatherData weather;
  final AqiData aqi;
  final TrafficData traffic;
  final ContextData context;

  EnvironmentModel({required this.weather, required this.aqi, required this.traffic, required this.context});

  factory EnvironmentModel.fromJson(Map<String, dynamic> json) {
    return EnvironmentModel(
      weather: WeatherData.fromJson(json['weather']),
      aqi: AqiData.fromJson(json['aqi']),
      traffic: TrafficData.fromJson(json['traffic']),
      context: ContextData.fromJson(json['context']),
    );
  }
}

class WeatherData {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double rainfall;

  WeatherData({required this.temperature, required this.humidity, required this.windSpeed, required this.rainfall});

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      rainfall: (json['rainfall'] as num).toDouble(),
    );
  }
}

class AqiData {
  final int aqi;
  final double pm25;
  final double pm10;

  AqiData({required this.aqi, required this.pm25, required this.pm10});

  factory AqiData.fromJson(Map<String, dynamic> json) {
    return AqiData(
      aqi: json['aqi'] as int,
      pm25: (json['pm2_5'] as num).toDouble(),
      pm10: (json['pm10'] as num).toDouble(),
    );
  }
}

class TrafficData {
  final double trafficScore;
  final String trafficLevel;

  TrafficData({required this.trafficScore, required this.trafficLevel});

  factory TrafficData.fromJson(Map<String, dynamic> json) {
    return TrafficData(
      trafficScore: (json['traffic_score'] as num).toDouble(),
      trafficLevel: json['traffic_level'] as String,
    );
  }
}

class ContextData {
  final int hour;
  final String dayType;

  ContextData({required this.hour, required this.dayType});

  factory ContextData.fromJson(Map<String, dynamic> json) {
    return ContextData(
      hour: json['hour'] as int,
      dayType: json['day_type'] as String,
    );
  }
}

// ── 📊 Gig Income Models ───────────────────────────────────────────────────

class BaselineIncomeModel {
  final double expectedEarnings;
  final int expectedOrders;
  final String date;

  BaselineIncomeModel({required this.expectedEarnings, required this.expectedOrders, required this.date});

  factory BaselineIncomeModel.fromJson(Map<String, dynamic> json) {
    return BaselineIncomeModel(
      expectedEarnings: (json['expected_earnings'] as num?)?.toDouble() ?? 0.0,
      expectedOrders: json['expected_orders'] as int? ?? 0,
      date: json['date'] as String? ?? '',
    );
  }
}

class TodayIncomeModel {
  final double actualEarnings;
  final int actualOrders;
  final double activeHours;
  final double lossAmount;

  TodayIncomeModel({required this.actualEarnings, required this.actualOrders, required this.activeHours, required this.lossAmount});

  factory TodayIncomeModel.fromJson(Map<String, dynamic> json) {
    return TodayIncomeModel(
      actualEarnings: (json['actual_earnings'] as num?)?.toDouble() ?? 0.0,
      actualOrders: json['actual_orders'] as int? ?? 0,
      activeHours: (json['active_hours'] as num?)?.toDouble() ?? 0.0,
      lossAmount: (json['loss_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class IncomeHistoryModel {
  final List<DailyRecord> records;
  final DailyRecord? bestDay;
  final DailyRecord? worstDay;

  IncomeHistoryModel({required this.records, this.bestDay, this.worstDay});

  factory IncomeHistoryModel.fromJson(Map<String, dynamic> json) {
    var rawRecords = json['records'] as List? ?? [];
    List<DailyRecord> parsed = rawRecords.map((e) => DailyRecord.fromJson(e)).toList();
    return IncomeHistoryModel(
      records: parsed,
      bestDay: json['best_day'] != null ? DailyRecord.fromJson(json['best_day']) : null,
      worstDay: json['worst_day'] != null ? DailyRecord.fromJson(json['worst_day']) : null,
    );
  }
}

class DailyRecord {
  final String date;
  final double earnings;
  final int orders;
  final WeatherData? weather;
  final AqiData? aqi;
  final TrafficData? traffic;

  DailyRecord({
    required this.date,
    required this.earnings,
    required this.orders,
    this.weather,
    this.aqi,
    this.traffic,
  });

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      date: json['date'] as String? ?? '',
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0.0,
      orders: json['orders'] as int? ?? 0,
      weather: json['weather'] != null ? WeatherData.fromJson(json['weather']) : null,
      aqi: json['aqi'] != null ? AqiData.fromJson(json['aqi']) : null,
      traffic: json['traffic'] != null ? TrafficData.fromJson(json['traffic']) : null,
    );
  }
}
