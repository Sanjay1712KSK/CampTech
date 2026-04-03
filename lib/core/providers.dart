import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'dart:async';

// User State
class UserState {
  final int userId;
  final String userName;
  final String email;
  final String phone;
  final bool isVerified;
  final bool isAccountConfirmed;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final String accessToken;
  
  UserState({
    required this.userId,
    required this.userName,
    required this.email,
    required this.phone,
    required this.isVerified,
    required this.isAccountConfirmed,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.accessToken,
  });
  
  UserState copyWith({
    int? userId,
    String? userName,
    String? email,
    String? phone,
    bool? isVerified,
    bool? isAccountConfirmed,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    String? accessToken,
  }) {
    return UserState(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isVerified: isVerified ?? this.isVerified,
      isAccountConfirmed: isAccountConfirmed ?? this.isAccountConfirmed,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}

class UserNotifier extends Notifier<UserState?> {
  @override
  UserState? build() => null;

  void setAuthenticatedUser(AuthUser user, {required String accessToken}) {
    setUser(
      user.id,
      user.name.isNotEmpty ? user.name : user.username,
      user.isVerified,
      email: user.email,
      phone: user.phone,
      isAccountConfirmed: user.isAccountConfirmed,
      isEmailVerified: user.isEmailVerified,
      isPhoneVerified: user.isPhoneVerified,
      accessToken: accessToken,
    );
  }

  void setUser(
    int id,
    String name,
    bool verified, {
    String email = '',
    String phone = '',
    bool isAccountConfirmed = false,
    bool isEmailVerified = false,
    bool isPhoneVerified = false,
    String accessToken = '',
  }) {
    state = UserState(
      userId: id,
      userName: name,
      email: email,
      phone: phone,
      isVerified: verified,
      isAccountConfirmed: isAccountConfirmed,
      isEmailVerified: isEmailVerified,
      isPhoneVerified: isPhoneVerified,
      accessToken: accessToken,
    );
  }

  void updateVerification(bool verified) {
    if (state != null) {
      state = state!.copyWith(isVerified: verified);
    }
  }

  void logout() {
    state = null;
  }
}

final userProvider = NotifierProvider<UserNotifier, UserState?>(UserNotifier.new);

// Location State
class LocationState {
  final double lat;
  final double lon;
  final String city;
  final bool permissionGranted;
  final bool isLive;
  final String? error;

  LocationState({
    required this.lat,
    required this.lon,
    required this.city,
    required this.permissionGranted,
    required this.isLive,
    this.error,
  });

  LocationState copyWith({
    double? lat,
    double? lon,
    String? city,
    bool? permissionGranted,
    bool? isLive,
    String? error,
  }) {
    return LocationState(
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      city: city ?? this.city,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      isLive: isLive ?? this.isLive,
      error: error,
    );
  }
}

class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() => LocationState(
        lat: 13.0827,
        lon: 80.2707,
        city: 'Chennai',
        permissionGranted: false,
        isLive: false,
      );

  void updateLocation({
    required double lat,
    required double lon,
    required String city,
    required bool permissionGranted,
    required bool isLive,
    String? error,
  }) {
    state = state.copyWith(
      lat: lat,
      lon: lon,
      city: city,
      permissionGranted: permissionGranted,
      isLive: isLive,
      error: error,
    );
  }

  void setLimitedFallback({String? message}) {
    state = state.copyWith(
      permissionGranted: false,
      isLive: false,
      error: message,
    );
  }
}

final locationProvider = NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);

// API Providers (Caches)

// Environment Data Provider
final environmentProvider = FutureProvider<EnvironmentModel>((ref) async {
  final loc = ref.watch(locationProvider);
  return await ApiService.getEnvironment(loc.lat, loc.lon);
});

// Risk Provider  (Requires user_id, lat, lon)
final riskProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(userProvider);
  final loc = ref.watch(locationProvider);
  if (user == null) throw Exception("User not logged in");
  return await ApiService.getRiskData(user.userId, loc.lat, loc.lon);
});

// Gig Income Providers
final baselineIncomeProvider = FutureProvider<BaselineIncomeModel>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) throw Exception("User not logged in");
  return await ApiService.getBaselineIncome(user.userId);
});

final todayIncomeProvider = FutureProvider<TodayIncomeModel>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) throw Exception("User not logged in");
  return await ApiService.getTodayIncome(user.userId);
});

final incomeHistoryProvider = FutureProvider<IncomeHistoryModel>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) throw Exception("User not logged in");
  return await ApiService.getIncomeHistory(user.userId);
});

final premiumProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) throw Exception("User not logged in");
  return await ApiService.getPremium(user.userId);
});

class ClaimNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  FutureOr<Map<String, dynamic>?> build() => null;

  Future<Map<String, dynamic>> submitClaim({
    required int userId,
    required double lat,
    required double lon,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ApiService.processClaim(userId, lat, lon),
    );
    state = result;
    return result.requireValue;
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final claimProvider =
    AsyncNotifierProvider<ClaimNotifier, Map<String, dynamic>?>(ClaimNotifier.new);
