import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:guidewire_gig_ins/config.dart';

/// Response model for signup / login
class AuthResult {
  final int userId;
  final String name;
  final String email;
  final String phone;
  final bool isVerified;

  const AuthResult({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.isVerified,
  });
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

class DigiLockerStatusResult {
  final bool isVerified;
  final String status;
  final String? verifiedName;
  final String? documentType;

  const DigiLockerStatusResult({
    required this.isVerified,
    required this.status,
    this.verifiedName,
    this.documentType,
  });
}

class ApiService {
  static const String _signupPath = '/auth/signup';
  static const String _loginPath = '/auth/login';
  static const String _digilockerRequestPath = '/digilocker/request';
  static const String _digilockerConsentPath = '/digilocker/consent';
  static const String _environmentPath = '/environment';
  static const String _gigGenerateDataPath = '/gig/generate-data';
  static const String _gigConnectPath = '/gig/connect';
  static const String _gigBaselinePath = '/gig/baseline-income';
  static const String _gigTodayPath = '/gig/today-income';
  static const String _gigHistoryPath = '/gig/income-history';
  static const String _digilockerStatusPath = '/digilocker/status';
  static const String _premiumPath = '/premium';
  static const String _premiumCalculatePath = '/premium/calculate';
  static const String _paymentPayPremiumPath = '/payment/pay-premium';
  static const String _paymentLinkBankPath = '/payment/link-bank';
  static const String _claimProcessPath = '/claim/process';

  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> get _headers =>
      {'Content-Type': 'application/json'};

  // ── 📊 Gig Income Data ────────────────────────────────────────────────────

  static Future<bool> generateGigData(int userId, {int days = 30}) async {
    try {
      final response = await http
          .post(Uri.parse('${Config.baseUrl}$_gigGenerateDataPath'),
              headers: _headers,
              body: jsonEncode({'user_id': userId, 'days': days}))
          .timeout(_timeout);
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Network or server error: $e');
    }
  }

  static Future<bool> connectGigAccount({
    required int userId,
    required String platform,
    required String partnerId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}$_gigConnectPath'),
            headers: _headers,
            body: jsonEncode({
              'user_id': userId,
              'platform': platform.toLowerCase(),
              'partner_id': partnerId,
            }),
          )
          .timeout(_timeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Network or server error: $e');
    }
  }

  static Future<BaselineIncomeModel> getBaselineIncome(int userId) async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}$_gigBaselinePath?user_id=$userId')).timeout(_timeout);
      if (response.statusCode == 200) return BaselineIncomeModel.fromJson(jsonDecode(response.body));
      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Failed to load baseline income');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<TodayIncomeModel> getTodayIncome(int userId) async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}$_gigTodayPath?user_id=$userId')).timeout(_timeout);
      if (response.statusCode == 200) return TodayIncomeModel.fromJson(jsonDecode(response.body));
      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Failed to load today income');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<IncomeHistoryModel> getIncomeHistory(int userId) async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}$_gigHistoryPath?user_id=$userId')).timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return IncomeHistoryModel.fromList(decoded);
        }
        if (decoded is Map<String, dynamic>) {
          return IncomeHistoryModel.fromJson(decoded);
        }
        throw Exception('Unexpected income history response format');
      }
      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Failed to load income history');
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

  // ── 🛡️ Risk Data ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getRiskData(int userId, double lat, double lon) async {
    try {
      final uri = Uri.parse('${Config.baseUrl}/risk?user_id=$userId&lat=$lat&lon=$lon');
      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body.containsKey('error') && body['error'] == true) {
           throw Exception(body['message'] ?? 'Error assessing risk');
        }
        return body;
      }
      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Failed to load risk data (${response.statusCode})');
    } on SocketException {
      throw Exception('Server not reachable');
    } catch (e) {
      throw Exception('Risk Data error: $e');
    }
  }

  static Future<Map<String, dynamic>> getPremium(int userId) async {
    try {
      final primaryUri = Uri.parse('${Config.baseUrl}$_premiumPath?user_id=$userId');
      var response = await http.get(primaryUri, headers: _headers).timeout(_timeout);

      if (response.statusCode == 404) {
        final fallbackUri = Uri.parse('${Config.baseUrl}$_premiumCalculatePath?user_id=$userId');
        response = await http.get(fallbackUri, headers: _headers).timeout(_timeout);
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Failed to load premium');
    } on SocketException {
      throw Exception('Server not reachable');
    } catch (e) {
      throw Exception('Premium error: $e');
    }
  }

  static Future<void> payPremium(int userId, double amount) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}$_paymentPayPremiumPath'),
            headers: _headers,
            body: jsonEncode({'user_id': userId, 'amount': amount}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Failed to pay premium');
    } on SocketException {
      throw Exception('Server not reachable');
    } catch (e) {
      throw Exception('Premium payment error: $e');
    }
  }

  static Future<void> linkBankAccount(
    int userId, {
    String accountNumber = '123456789012',
    String ifsc = 'HDFC0001234',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}$_paymentLinkBankPath'),
            headers: _headers,
            body: jsonEncode({
              'user_id': userId,
              'account_number': accountNumber,
              'ifsc': ifsc,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Failed to link bank account');
    } on SocketException {
      throw Exception('Server not reachable');
    } catch (e) {
      throw Exception('Bank linking error: $e');
    }
  }

  static Future<Map<String, dynamic>> processClaim(int userId, double lat, double lon) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}$_claimProcessPath'),
            headers: _headers,
            body: jsonEncode({'user_id': userId, 'lat': lat, 'lon': lon}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Failed to process claim');
    } on SocketException {
      throw Exception('Server not reachable');
    } catch (e) {
      throw Exception('Claim error: $e');
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
        return AuthResult(
          userId: id,
          name: body['name'] as String? ?? name,
          email: body['email'] as String? ?? email,
          phone: body['phone'] as String? ?? phone,
          isVerified: isVerified,
        );
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
        return AuthResult(
          userId: id,
          name: body['name'] as String? ?? email.split('@').first,
          email: body['email'] as String? ?? email,
          phone: body['phone'] as String? ?? '',
          isVerified: isVerified,
        );
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

  // ─── DIGILOCKER STATUS ───────────────────────────────────────────────────────
  @Deprecated('Use getDigiLockerStatusByUserId instead.')
  static Future<String> getDigiLockerStatus(String requestId) async {
    throw UnimplementedError('Use getDigiLockerStatusByUserId instead.');
  }

  static Future<DigiLockerStatusResult> getDigiLockerStatusByUserId(int userId) async {
    final uri = Uri.parse('${Config.baseUrl}$_digilockerStatusPath?user_id=$userId');
    try {
      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body.containsKey('error') && body['error'] == true) {
           throw Exception(body['message'] ?? 'Error fetching status');
        }
        return DigiLockerStatusResult(
          isVerified: body['is_verified'] as bool? ?? false,
          status: body['status'] as String? ?? 'NONE',
          verifiedName: body['verified_name'] as String?,
          documentType: body['document_type'] as String?,
        );
      }
      final errorBody = _tryDecodeError(response.body);
      throw Exception(errorBody ?? 'Failed to get status (${response.statusCode})');
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
  final double baselineDailyIncome;

  BaselineIncomeModel({required this.baselineDailyIncome});

  factory BaselineIncomeModel.fromJson(Map<String, dynamic> json) {
    return BaselineIncomeModel(
      baselineDailyIncome: (json['baseline_daily_income'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TodayIncomeModel {
  final double earnings;
  final int ordersCompleted;
  final double hoursWorked;
  final String disruptionType;
  final String? platform;

  TodayIncomeModel({
    required this.earnings,
    required this.ordersCompleted,
    required this.hoursWorked,
    required this.disruptionType,
    this.platform,
  });

  factory TodayIncomeModel.fromJson(Map<String, dynamic> json) {
    return TodayIncomeModel(
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0.0,
      ordersCompleted: json['orders_completed'] as int? ?? 0,
      hoursWorked: (json['hours_worked'] as num?)?.toDouble() ?? 0.0,
      disruptionType: json['disruption_type'] as String? ?? 'none',
      platform: json['platform'] as String?,
    );
  }
}

class IncomeHistoryModel {
  final List<DailyRecord> records;
  final DailyRecord? bestDay;
  final DailyRecord? worstDay;

  IncomeHistoryModel({required this.records, this.bestDay, this.worstDay});

  factory IncomeHistoryModel.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List? ?? const [];
    return IncomeHistoryModel.fromList(rawRecords);
  }

  factory IncomeHistoryModel.fromList(List<dynamic> rawRecords) {
    final parsed = rawRecords
        .whereType<Map<String, dynamic>>()
        .map((e) => DailyRecord.fromJson(e))
        .toList();

    DailyRecord? bestDay;
    DailyRecord? worstDay;
    if (parsed.isNotEmpty) {
      parsed.sort((a, b) => a.date.compareTo(b.date));
      bestDay = parsed.reduce((a, b) => a.earnings >= b.earnings ? a : b);
      worstDay = parsed.reduce((a, b) => a.earnings <= b.earnings ? a : b);
    }

    return IncomeHistoryModel(
      records: parsed,
      bestDay: bestDay,
      worstDay: worstDay,
    );
  }
}

class DailyRecord {
  final String date;
  final double earnings;
  final int orders;
  final double? hoursWorked;
  final String? platform;
  final String? disruptionType;
  final WeatherData? weather;
  final AqiData? aqi;
  final TrafficData? traffic;

  DailyRecord({
    required this.date,
    required this.earnings,
    required this.orders,
    this.hoursWorked,
    this.platform,
    this.disruptionType,
    this.weather,
    this.aqi,
    this.traffic,
  });

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      date: json['date'] as String? ?? '',
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0.0,
      orders: json['orders_completed'] as int? ?? json['orders'] as int? ?? 0,
      hoursWorked: (json['hours_worked'] as num?)?.toDouble(),
      platform: json['platform'] as String?,
      disruptionType: json['disruption_type'] as String?,
      weather: (json['temperature'] != null || json['humidity'] != null || json['rainfall'] != null || json['wind_speed'] != null)
          ? WeatherData(
              temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
              humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
              windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0.0,
              rainfall: (json['rainfall'] as num?)?.toDouble() ?? 0.0,
            )
          : null,
      aqi: (json['aqi_level'] != null || json['pm2_5'] != null || json['pm10'] != null)
          ? AqiData(
              aqi: json['aqi_level'] as int? ?? 0,
              pm25: (json['pm2_5'] as num?)?.toDouble() ?? 0.0,
              pm10: (json['pm10'] as num?)?.toDouble() ?? 0.0,
            )
          : null,
      traffic: (json['traffic_score'] != null || json['traffic_level'] != null)
          ? TrafficData(
              trafficScore: (json['traffic_score'] as num?)?.toDouble() ?? 0.0,
              trafficLevel: json['traffic_level'] as String? ?? 'LOW',
            )
          : null,
    );
  }
}
