import 'dart:convert';
import 'dart:io';

import 'package:guidewire_gig_ins/config.dart';
import 'package:http/http.dart' as http;

class AvailabilityResult {
  final bool available;
  final String? suggestion;
  final String message;

  const AvailabilityResult({
    required this.available,
    required this.message,
    this.suggestion,
  });

  factory AvailabilityResult.fromJson(Map<String, dynamic> json) {
    return AvailabilityResult(
      available: json['available'] as bool? ?? false,
      suggestion: json['suggestion'] as String?,
      message: json['message'] as String? ?? '',
    );
  }
}

class DeliveryPreview {
  final String channel;
  final String destination;
  final String mockOtp;

  const DeliveryPreview({
    required this.channel,
    required this.destination,
    required this.mockOtp,
  });

  factory DeliveryPreview.fromJson(Map<String, dynamic> json) {
    return DeliveryPreview(
      channel: json['channel'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      mockOtp: json['mock_otp'] as String? ?? '',
    );
  }
}

class PendingRegistration {
  final int userId;
  final String email;
  final String phone;
  final String username;
  final String nextStep;
  final String onboardingStatus;

  const PendingRegistration({
    required this.userId,
    required this.email,
    required this.phone,
    required this.username,
    required this.nextStep,
    required this.onboardingStatus,
  });

  factory PendingRegistration.fromJson(Map<String, dynamic> json) {
    return PendingRegistration(
      userId: json['user_id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      username: json['username'] as String? ?? '',
      nextStep: json['next_step'] as String? ?? '',
      onboardingStatus: json['onboarding_status'] as String? ?? '',
    );
  }
}

class SendOtpResult {
  final String message;
  final String purpose;
  final int expiresInSeconds;
  final int retryLimit;
  final List<DeliveryPreview> deliveries;

  const SendOtpResult({
    required this.message,
    required this.purpose,
    required this.expiresInSeconds,
    required this.retryLimit,
    required this.deliveries,
  });

  factory SendOtpResult.fromJson(Map<String, dynamic> json) {
    final rawDeliveries = json['deliveries'] as List? ?? const [];
    return SendOtpResult(
      message: json['message'] as String? ?? '',
      purpose: json['purpose'] as String? ?? 'signup',
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 300,
      retryLimit: json['retry_limit'] as int? ?? 5,
      deliveries: rawDeliveries
          .whereType<Map<String, dynamic>>()
          .map(DeliveryPreview.fromJson)
          .toList(),
    );
  }
}

class VerifyOtpResult {
  final bool emailVerified;
  final bool phoneVerified;
  final String confirmationToken;
  final String confirmationLink;

  const VerifyOtpResult({
    required this.emailVerified,
    required this.phoneVerified,
    required this.confirmationToken,
    required this.confirmationLink,
  });

  factory VerifyOtpResult.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResult(
      emailVerified: json['email_verified'] as bool? ?? false,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      confirmationToken: json['confirmation_token'] as String? ?? '',
      confirmationLink: json['confirmation_link'] as String? ?? '',
    );
  }
}

class AuthUser {
  final int id;
  final String email;
  final String phone;
  final String username;
  final String name;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isAccountConfirmed;
  final bool isDigilockerVerified;

  const AuthUser({
    required this.id,
    required this.email,
    required this.phone,
    required this.username,
    required this.name,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.isAccountConfirmed,
    required this.isDigilockerVerified,
  });

  bool get isVerified => isDigilockerVerified;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
      isAccountConfirmed: json['is_account_confirmed'] as bool? ?? false,
      isDigilockerVerified: json['is_digilocker_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'username': username,
      'name': name,
      'is_email_verified': isEmailVerified,
      'is_phone_verified': isPhoneVerified,
      'is_account_confirmed': isAccountConfirmed,
      'is_digilocker_verified': isDigilockerVerified,
    };
  }
}

class LoginResult {
  final String accessToken;
  final int expiresIn;
  final AuthUser user;

  const LoginResult({
    required this.accessToken,
    required this.expiresIn,
    required this.user,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      accessToken: json['access_token'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 0,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class ForgotPasswordResult {
  final int userId;
  final String message;
  final int expiresInSeconds;
  final List<DeliveryPreview> deliveries;

  const ForgotPasswordResult({
    required this.userId,
    required this.message,
    required this.expiresInSeconds,
    required this.deliveries,
  });

  factory ForgotPasswordResult.fromJson(Map<String, dynamic> json) {
    final rawDeliveries = json['deliveries'] as List? ?? const [];
    return ForgotPasswordResult(
      userId: json['user_id'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 300,
      deliveries: rawDeliveries
          .whereType<Map<String, dynamic>>()
          .map(DeliveryPreview.fromJson)
          .toList(),
    );
  }
}

class ResetOtpVerifiedResult {
  final String resetToken;
  final String message;

  const ResetOtpVerifiedResult({
    required this.resetToken,
    required this.message,
  });

  factory ResetOtpVerifiedResult.fromJson(Map<String, dynamic> json) {
    return ResetOtpVerifiedResult(
      resetToken: json['reset_token'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class DigiLockerRequestResult {
  final String requestId;
  final String status;
  final String redirectUrl;
  final String oauthState;

  const DigiLockerRequestResult({
    required this.requestId,
    required this.status,
    required this.redirectUrl,
    required this.oauthState,
  });

  factory DigiLockerRequestResult.fromJson(Map<String, dynamic> json) {
    return DigiLockerRequestResult(
      requestId: json['request_id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      redirectUrl: json['redirect_url'] as String? ?? '',
      oauthState: json['oauth_state'] as String? ?? '',
    );
  }
}

class DigiLockerVerifyResult {
  final String status;
  final String verifiedName;
  final String docType;

  const DigiLockerVerifyResult({
    required this.status,
    required this.verifiedName,
    required this.docType,
  });

  bool get verified => status.toUpperCase() == 'VERIFIED';

  factory DigiLockerVerifyResult.fromJson(Map<String, dynamic> json) {
    return DigiLockerVerifyResult(
      status: json['status'] as String? ?? 'FAILED',
      verifiedName: json['verified_name'] as String? ?? '',
      docType: json['doc_type'] as String? ?? '',
    );
  }
}

class DigiLockerStatusResult {
  final bool isVerified;
  final String status;
  final String? verifiedName;
  final String? docType;

  const DigiLockerStatusResult({
    required this.isVerified,
    required this.status,
    this.verifiedName,
    this.docType,
  });

  factory DigiLockerStatusResult.fromJson(Map<String, dynamic> json) {
    return DigiLockerStatusResult(
      isVerified: json['is_verified'] as bool? ?? false,
      status: json['status'] as String? ?? 'NOT_STARTED',
      verifiedName: json['verified_name'] as String?,
      docType: json['doc_type'] as String?,
    );
  }
}

class ApiService {
  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Exception _asException(http.Response response) {
    final message = _tryDecodeError(response.body) ?? 'Request failed (${response.statusCode})';
    return Exception(message);
  }

  static Future<Map<String, dynamic>> _getJson(
    String path, {
    String? token,
  }) async {
    final response = await http
        .get(Uri.parse('${Config.baseUrl}$path'), headers: _headers(token: token))
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _asException(response);
  }

  static Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final response = await http
        .post(
          Uri.parse('${Config.baseUrl}$path'),
          headers: _headers(token: token),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _asException(response);
  }

  static Future<AvailabilityResult> checkUsernameAvailability(String username) async {
    final encoded = Uri.encodeQueryComponent(username);
    final body = await _getJson('/auth/check-username?username=$encoded');
    return AvailabilityResult.fromJson(body);
  }

  static Future<AvailabilityResult> checkEmailAvailability(String email) async {
    final encoded = Uri.encodeQueryComponent(email);
    final body = await _getJson('/auth/check-email?email=$encoded');
    return AvailabilityResult.fromJson(body);
  }

  static Future<List<String>> suggestUsernames(String seed) async {
    final encoded = Uri.encodeQueryComponent(seed);
    final body = await _getJson('/auth/suggest-usernames?username=$encoded');
    return (body['suggestions'] as List? ?? const []).map((e) => '$e').toList();
  }

  static Future<PendingRegistration> signup({
    required String email,
    required String countryCode,
    required String phoneNumber,
    required String username,
    required String password,
  }) async {
    final body = await _postJson(
      '/auth/signup',
      body: {
        'email': email,
        'country_code': countryCode,
        'phone_number': phoneNumber,
        'username': username,
        'password': password,
      },
    );
    return PendingRegistration.fromJson(body);
  }

  static Future<SendOtpResult> sendOtp({
    required int userId,
    String purpose = 'signup',
  }) async {
    final body = await _postJson(
      '/auth/send-otp',
      body: {
        'user_id': userId,
        'purpose': purpose,
      },
    );
    return SendOtpResult.fromJson(body);
  }

  static Future<VerifyOtpResult> verifyOtp({
    required int userId,
    required String emailOtp,
    required String phoneOtp,
  }) async {
    final body = await _postJson(
      '/auth/verify-otp',
      body: {
        'user_id': userId,
        'email_otp': emailOtp,
        'phone_otp': phoneOtp,
      },
    );
    return VerifyOtpResult.fromJson(body);
  }

  static Future<String> confirmAccount(String token) async {
    final encoded = Uri.encodeQueryComponent(token);
    final body = await _getJson('/auth/confirm?token=$encoded');
    return body['message'] as String? ?? 'Account confirmed';
  }

  static Future<LoginResult> login({
    required String identifier,
    required String password,
  }) async {
    final body = await _postJson(
      '/auth/login',
      body: {
        'identifier': identifier,
        'password': password,
      },
    );
    return LoginResult.fromJson(body);
  }

  static Future<AuthUser> getCurrentUser(String accessToken) async {
    final body = await _getJson('/auth/me', token: accessToken);
    return AuthUser.fromJson(body);
  }

  static Future<ForgotPasswordResult> forgotPassword(String identifier) async {
    final body = await _postJson(
      '/auth/forgot-password',
      body: {'identifier': identifier},
    );
    return ForgotPasswordResult.fromJson(body);
  }

  static Future<ResetOtpVerifiedResult> verifyResetOtp({
    required int userId,
    required String emailOtp,
    required String phoneOtp,
  }) async {
    final body = await _postJson(
      '/auth/verify-reset-otp',
      body: {
        'user_id': userId,
        'email_otp': emailOtp,
        'phone_otp': phoneOtp,
      },
    );
    return ResetOtpVerifiedResult.fromJson(body);
  }

  static Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _postJson(
      '/auth/reset-password',
      body: {
        'reset_token': resetToken,
        'new_password': newPassword,
      },
    );
  }

  static Future<DigiLockerRequestResult> createDigiLockerRequest({
    required int userId,
    required String docType,
  }) async {
    final body = await _postJson(
      '/digilocker/request',
      body: {
        'user_id': userId,
        'doc_type': docType,
      },
    );
    return DigiLockerRequestResult.fromJson(body);
  }

  static Future<DigiLockerVerifyResult> verifyDigiLocker({
    required String requestId,
    required String consentCode,
  }) async {
    final body = await _postJson(
      '/digilocker/verify',
      body: {
        'request_id': requestId,
        'consent_code': consentCode,
      },
    );
    return DigiLockerVerifyResult.fromJson(body);
  }

  static Future<DigiLockerStatusResult> getDigiLockerStatusByUserId(int userId) async {
    final body = await _getJson('/digilocker/status?user_id=$userId');
    return DigiLockerStatusResult.fromJson(body);
  }

  static Future<bool> generateGigData(int userId, {int days = 30}) async {
    await _postJson(
      '/gig/generate-data',
      body: {'user_id': userId, 'days': days},
    );
    return true;
  }

  static Future<bool> connectGigAccount({
    required int userId,
    required String platform,
    required String partnerId,
  }) async {
    await _postJson(
      '/gig/connect',
      body: {
        'user_id': userId,
        'platform': platform.toLowerCase(),
        'partner_id': partnerId,
      },
    );
    return true;
  }

  static Future<BaselineIncomeModel> getBaselineIncome(int userId) async {
    final body = await _getJson('/gig/baseline-income?user_id=$userId');
    return BaselineIncomeModel.fromJson(body);
  }

  static Future<TodayIncomeModel> getTodayIncome(int userId) async {
    final body = await _getJson('/gig/today-income?user_id=$userId');
    return TodayIncomeModel.fromJson(body);
  }

  static Future<IncomeHistoryModel> getIncomeHistory(int userId) async {
    final response = await http
        .get(Uri.parse('${Config.baseUrl}/gig/income-history?user_id=$userId'))
        .timeout(_timeout);
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
    throw _asException(response);
  }

  static Future<EnvironmentModel> getEnvironment(double lat, double lon) async {
    final body = await _getJson('/environment?lat=$lat&lon=$lon');
    return EnvironmentModel.fromJson(body);
  }

  static Future<Map<String, dynamic>> getRiskData(int userId, double lat, double lon) async {
    return _getJson('/risk?user_id=$userId&lat=$lat&lon=$lon');
  }

  static Future<Map<String, dynamic>> getPremium(int userId) async {
    try {
      return await _getJson('/premium?user_id=$userId');
    } catch (_) {
      return _getJson('/premium/calculate?user_id=$userId');
    }
  }

  static Future<void> payPremium(int userId, double amount) async {
    await _postJson(
      '/payment/pay-premium',
      body: {'user_id': userId, 'amount': amount},
    );
  }

  static Future<InsuranceSummaryModel> getInsuranceSummary(int userId) async {
    final body = await _getJson('/payment/summary?user_id=$userId');
    return InsuranceSummaryModel.fromJson(body);
  }

  static Future<void> linkBankAccount(
    int userId, {
    String accountNumber = '123456789012',
    String ifsc = 'HDFC0001234',
  }) async {
    await _postJson(
      '/payment/link-bank',
      body: {
        'user_id': userId,
        'account_number': accountNumber,
        'ifsc': ifsc,
      },
    );
  }

  static Future<Map<String, dynamic>> processClaim(int userId, double lat, double lon) async {
    return _postJson(
      '/claim/process',
      body: {'user_id': userId, 'lat': lat, 'lon': lon},
    );
  }

  static String? _tryDecodeError(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      return (map['detail'] ?? map['message'] ?? map['error'])?.toString();
    } catch (_) {
      return null;
    }
  }
}

class EnvironmentModel {
  final WeatherData weather;
  final AqiData aqi;
  final TrafficData traffic;
  final ContextData context;

  EnvironmentModel({
    required this.weather,
    required this.aqi,
    required this.traffic,
    required this.context,
  });

  factory EnvironmentModel.fromJson(Map<String, dynamic> json) {
    return EnvironmentModel(
      weather: WeatherData.fromJson(json['weather'] as Map<String, dynamic>? ?? const {}),
      aqi: AqiData.fromJson(json['aqi'] as Map<String, dynamic>? ?? const {}),
      traffic: TrafficData.fromJson(json['traffic'] as Map<String, dynamic>? ?? const {}),
      context: ContextData.fromJson(json['context'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class WeatherData {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double rainfall;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.rainfall,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0.0,
      rainfall: (json['rainfall'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AqiData {
  final int aqi;
  final double pm25;
  final double pm10;

  AqiData({
    required this.aqi,
    required this.pm25,
    required this.pm10,
  });

  factory AqiData.fromJson(Map<String, dynamic> json) {
    return AqiData(
      aqi: json['aqi'] as int? ?? 0,
      pm25: (json['pm2_5'] as num?)?.toDouble() ?? 0.0,
      pm10: (json['pm10'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TrafficData {
  final double trafficScore;
  final String trafficLevel;

  TrafficData({
    required this.trafficScore,
    required this.trafficLevel,
  });

  factory TrafficData.fromJson(Map<String, dynamic> json) {
    return TrafficData(
      trafficScore: (json['traffic_score'] as num?)?.toDouble() ?? 0.0,
      trafficLevel: json['traffic_level'] as String? ?? 'LOW',
    );
  }
}

class ContextData {
  final int hour;
  final String dayType;

  ContextData({
    required this.hour,
    required this.dayType,
  });

  factory ContextData.fromJson(Map<String, dynamic> json) {
    return ContextData(
      hour: json['hour'] as int? ?? 0,
      dayType: json['day_type'] as String? ?? 'weekday',
    );
  }
}

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

  IncomeHistoryModel({
    required this.records,
    this.bestDay,
    this.worstDay,
  });

  factory IncomeHistoryModel.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List? ?? const [];
    return IncomeHistoryModel.fromList(rawRecords);
  }

  factory IncomeHistoryModel.fromList(List<dynamic> rawRecords) {
    final parsed = rawRecords
        .whereType<Map<String, dynamic>>()
        .map(DailyRecord.fromJson)
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

class InsuranceSummaryModel {
  final int userId;
  final bool bankLinked;
  final String? accountNumberMasked;
  final String? ifsc;
  final double? balance;
  final double totalPaid;
  final double totalClaimed;
  final String policyStatus;
  final String claimMessage;
  final bool claimReady;
  final double lastPayout;
  final String? latestClaimStatus;
  final List<String> recentRemarks;
  final DateTime? policyStart;
  final DateTime? policyEnd;

  InsuranceSummaryModel({
    required this.userId,
    required this.bankLinked,
    required this.accountNumberMasked,
    required this.ifsc,
    required this.balance,
    required this.totalPaid,
    required this.totalClaimed,
    required this.policyStatus,
    required this.claimMessage,
    required this.claimReady,
    required this.lastPayout,
    required this.latestClaimStatus,
    required this.recentRemarks,
    required this.policyStart,
    required this.policyEnd,
  });

  factory InsuranceSummaryModel.fromJson(Map<String, dynamic> json) {
    return InsuranceSummaryModel(
      userId: json['user_id'] as int? ?? 0,
      bankLinked: json['bank_linked'] as bool? ?? false,
      accountNumberMasked: json['account_number_masked'] as String?,
      ifsc: json['ifsc'] as String?,
      balance: (json['balance'] as num?)?.toDouble(),
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0.0,
      totalClaimed: (json['total_claimed'] as num?)?.toDouble() ?? 0.0,
      policyStatus: json['policy_status'] as String? ?? 'NOT_PURCHASED',
      claimMessage: json['claim_message'] as String? ?? '',
      claimReady: json['claim_ready'] as bool? ?? false,
      lastPayout: (json['last_payout'] as num?)?.toDouble() ?? 0.0,
      latestClaimStatus: json['latest_claim_status'] as String?,
      recentRemarks: (json['recent_remarks'] as List? ?? const []).map((e) => '$e').toList(),
      policyStart: json['policy_start'] != null ? DateTime.tryParse('${json['policy_start']}') : null,
      policyEnd: json['policy_end'] != null ? DateTime.tryParse('${json['policy_end']}') : null,
    );
  }
}
