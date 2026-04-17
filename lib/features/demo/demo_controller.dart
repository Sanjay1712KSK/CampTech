import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/features/admin/screens/admin_dashboard_screen.dart';
import 'package:guidewire_gig_ins/features/main/main_shell.dart';
import 'package:guidewire_gig_ins/main.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/auth_storage_service.dart';
import 'package:guidewire_gig_ins/services/device_identity_service.dart';

class DemoAutomationState {
  final bool isRunning;
  final String? overlayMessage;
  final String? workerSection;
  final String? adminSection;

  const DemoAutomationState({
    required this.isRunning,
    this.overlayMessage,
    this.workerSection,
    this.adminSection,
  });

  const DemoAutomationState.idle() : this(isRunning: false);

  DemoAutomationState copyWith({
    bool? isRunning,
    String? overlayMessage,
    String? workerSection,
    String? adminSection,
    bool clearOverlay = false,
    bool clearWorkerSection = false,
    bool clearAdminSection = false,
  }) {
    return DemoAutomationState(
      isRunning: isRunning ?? this.isRunning,
      overlayMessage: clearOverlay ? null : (overlayMessage ?? this.overlayMessage),
      workerSection: clearWorkerSection ? null : (workerSection ?? this.workerSection),
      adminSection: clearAdminSection ? null : (adminSection ?? this.adminSection),
    );
  }
}

class DemoController extends Notifier<DemoAutomationState> {
  @override
  DemoAutomationState build() => const DemoAutomationState.idle();

  Future<void> startDemo() async {
    if (state.isRunning) return;

    state = const DemoAutomationState(
      isRunning: true,
      overlayMessage: 'Preparing automated demo...',
    );

    try {
      await AuthStorageService.clearSession();
      await ApiService.setEnvironmentOverride(
        overrideMode: false,
        scenario: 'reset',
      );

      await _automatedWorkerLogin();

      rootNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainShell(key: mainShellGlobalKey)),
        (_) => false,
      );
      await _waitFor(() => mainShellGlobalKey.currentState != null);
      await Future<void>.delayed(const Duration(seconds: 2));

      await _focusWorkerSection(
        'environment',
        message: 'Detecting disruption...',
      );
      await Future<void>.delayed(const Duration(seconds: 2));

      state = state.copyWith(
        overlayMessage: 'Simulating heavy rainfall...',
        workerSection: 'environment',
      );
      await mainShellGlobalKey.currentState?.runHomeRainScenario();
      await Future<void>.delayed(const Duration(seconds: 3));

      await _focusWorkerSection(
        'risk',
        message: 'Calculating risk...',
      );
      await Future<void>.delayed(const Duration(seconds: 3));

      await _focusWorkerSection(
        'claim',
        message: 'Auto claim triggered',
      );
      await Future<void>.delayed(const Duration(seconds: 3));

      await _focusWorkerSection(
        'fraud',
        message: 'Validating claim...',
      );
      await Future<void>.delayed(const Duration(seconds: 3));

      await _focusWorkerSection(
        'payout',
        message: 'Processing payout...',
      );
      await Future<void>.delayed(const Duration(seconds: 3));

      state = state.copyWith(
        overlayMessage: 'Opening insurer control panel...',
        clearAdminSection: true,
      );

      final admin = await ApiService.adminLogin(
        email: 'admin@gigshield.com',
        password: 'admin123',
      );

      rootNavigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(
            key: adminDashboardGlobalKey,
            initialToken: admin.token,
          ),
        ),
      );
      await _waitFor(() => adminDashboardGlobalKey.currentState != null);
      await Future<void>.delayed(const Duration(seconds: 2));

      await _focusAdminSection(
        'overview',
        message: 'Reviewing system health...',
      );
      await Future<void>.delayed(const Duration(seconds: 2));

      await _focusAdminSection(
        'fraud',
        message: 'Reviewing fraud intelligence...',
      );
      await Future<void>.delayed(const Duration(seconds: 2));

      await _focusAdminSection(
        'predictions',
        message: 'Showing predictions and insights...',
      );
      await Future<void>.delayed(const Duration(seconds: 3));
    } catch (error) {
      state = state.copyWith(
        overlayMessage: error.toString().replaceFirst('Exception: ', ''),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
    } finally {
      state = const DemoAutomationState.idle();
    }
  }

  Future<void> _automatedWorkerLogin() async {
    state = state.copyWith(overlayMessage: 'Signing in demo worker...');
    final deviceId = await DeviceIdentityService.getOrCreateDeviceId();
    final loginResult = await ApiService.login(
      identifier: 'premium_success',
      password: 'Demo@1234',
      deviceId: deviceId,
    );

    LoginResult finalResult = loginResult;
    if (loginResult.requiresTwoFactor) {
      final challengeToken = loginResult.twoFactorToken;
      if (challengeToken == null || challengeToken.isEmpty) {
        throw Exception('Demo login challenge token is missing.');
      }
      final sendResult = await ApiService.sendFirstLoginOtp(
        challengeToken: challengeToken,
        channel: 'phone',
      );
      final phoneOtp = sendResult.deliveries
          .firstWhere(
            (item) => item.channel.toLowerCase() == 'phone',
            orElse: () => throw Exception('Demo phone OTP was not returned.'),
          )
          .mockOtp;
      if (phoneOtp == null || phoneOtp.isEmpty) {
        throw Exception('Demo phone OTP is unavailable.');
      }
      finalResult = await ApiService.verifyFirstLoginOtp(
        challengeToken: challengeToken,
        channel: 'phone',
        otp: phoneOtp,
      );
    }

    final user = finalResult.user;
    if (user == null || finalResult.accessToken.isEmpty) {
      throw Exception('Demo worker login did not return an authenticated session.');
    }

    await AuthStorageService.saveSession(
      accessToken: finalResult.accessToken,
      user: user,
    );
    await AuthStorageService.setLocationPromptSeen(true);
    await AuthStorageService.setBiometricPromptSeen(true);

    ref.read(userProvider.notifier).setAuthenticatedUser(
          user,
          accessToken: finalResult.accessToken,
        );
    ref.read(locationProvider.notifier).updateLocation(
          lat: 13.0827,
          lon: 80.2707,
          city: 'Chennai',
          permissionGranted: true,
          isLive: false,
        );
    await ApiService.updateLocation(
      userId: user.id,
      lat: 13.0827,
      lon: 80.2707,
      timestamp: DateTime.now(),
      locationEnabled: true,
      city: 'Chennai',
      deviceId: deviceId,
    );
  }

  Future<void> _focusWorkerSection(
    String section, {
    required String message,
  }) async {
    state = state.copyWith(
      overlayMessage: message,
      workerSection: section,
      clearAdminSection: true,
    );
    await mainShellGlobalKey.currentState?.setCurrentIndex(0);
    await mainShellGlobalKey.currentState?.scrollHomeToSection(section);
  }

  Future<void> _focusAdminSection(
    String section, {
    required String message,
  }) async {
    state = state.copyWith(
      overlayMessage: message,
      adminSection: section,
      clearWorkerSection: true,
    );
    await adminDashboardGlobalKey.currentState?.scrollToSection(section);
  }

  Future<void> _waitFor(bool Function() predicate) async {
    for (var i = 0; i < 50; i++) {
      if (predicate()) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw Exception('Demo automation timed out while waiting for the next screen.');
  }
}

final demoControllerProvider =
    NotifierProvider<DemoController, DemoAutomationState>(DemoController.new);
