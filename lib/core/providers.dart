import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';

// User State
class UserState {
  final int userId;
  final String userName;
  final bool isVerified;
  
  UserState({required this.userId, required this.userName, required this.isVerified});
  
  UserState copyWith({int? userId, String? userName, bool? isVerified}) {
    return UserState(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

class UserNotifier extends Notifier<UserState?> {
  @override
  UserState? build() => null;

  void setUser(int id, String name, bool verified) {
    state = UserState(userId: id, userName: name, isVerified: verified);
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
  LocationState({required this.lat, required this.lon});
}

class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() => LocationState(lat: 13.0827, lon: 80.2707);
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
