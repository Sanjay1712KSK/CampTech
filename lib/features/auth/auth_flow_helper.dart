import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/auth_storage_service.dart';
import 'package:guidewire_gig_ins/services/device_identity_service.dart';
import 'package:guidewire_gig_ins/services/device_auth_service.dart';
import 'package:guidewire_gig_ins/services/location_service.dart';

class AuthFlowHelper {
  static const DeviceAuthService _deviceAuth = DeviceAuthService();

  static Future<void> finalizeAuthenticatedSession(
    BuildContext context,
    WidgetRef ref,
    LoginResult result,
  ) async {
    if (!result.isAuthenticated || result.user == null) {
      throw Exception(result.message ?? 'Authentication did not complete');
    }

    await AuthStorageService.saveSession(
      accessToken: result.accessToken,
      user: result.user!,
    );
    ref.read(userProvider.notifier).setAuthenticatedUser(
          result.user!,
          accessToken: result.accessToken,
        );

    await _promptForBiometricIfNeeded(context);
    await _promptForLocationAccessIfNeeded(context, ref);
  }

  static Future<void> _promptForBiometricIfNeeded(BuildContext context) async {
    final biometricEnabled = await AuthStorageService.isBiometricEnabled();
    final promptSeen = await AuthStorageService.hasSeenBiometricPrompt();
    if (biometricEnabled || promptSeen || !context.mounted) {
      return;
    }

    await AuthStorageService.setBiometricPromptSeen(true);

    final canUseBiometrics = await _deviceAuth.canUseBiometrics();
    if (!canUseBiometrics) {
      return;
    }

    final shouldEnable = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable biometric unlock?'),
            content: const Text(
              'Use fingerprint or face unlock the next time you open the app for added account security.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enable'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldEnable) {
      return;
    }

    try {
      final didAuthenticate = await _deviceAuth.authenticate(
        reason: 'Enable biometric unlock for GigShield',
      );
      if (didAuthenticate) {
        await AuthStorageService.setBiometricEnabled(true);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric setup was not completed.')),
        );
      }
    }
  }

  static Future<void> _promptForLocationAccessIfNeeded(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final promptSeen = await AuthStorageService.hasSeenLocationPrompt();
    if (promptSeen || !context.mounted) {
      return;
    }

    final allow = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Allow location during work hours?'),
            content: const Text(
              'To calculate your risk and protect your income, we need location access during work hours.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Deny'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Allow'),
              ),
            ],
          ),
        ) ??
        false;

    await AuthStorageService.setLocationPromptSeen(true);

    final user = ref.read(userProvider);
    final deviceId = await DeviceIdentityService.getOrCreateDeviceId();
    final currentLocation = ref.read(locationProvider);

    if (!allow) {
      ref.read(locationProvider.notifier).setLimitedFallback(
            message:
                'Location access was denied. Auto-claim protection stays limited until you enable it.',
          );
      if (user != null) {
        try {
          await ApiService.updateLocation(
            userId: user.userId,
            lat: currentLocation.lat,
            lon: currentLocation.lon,
            timestamp: DateTime.now(),
            city: currentLocation.city,
            deviceId: deviceId,
            locationEnabled: false,
          );
        } catch (_) {}
      }
      return;
    }

    final result = await LocationService.requestCurrentLocation();
    if (result.granted && result.lat != null && result.lon != null) {
      final city = result.city ?? 'Current location';
      ref.read(locationProvider.notifier).updateLocation(
            lat: result.lat!,
            lon: result.lon!,
            city: city,
            permissionGranted: true,
            isLive: true,
            error: null,
          );
      if (user != null) {
        try {
          await ApiService.updateLocation(
            userId: user.userId,
            lat: result.lat!,
            lon: result.lon!,
            timestamp: DateTime.now(),
            city: city,
            deviceId: deviceId,
            locationEnabled: true,
          );
        } catch (_) {}
      }
      return;
    }

    ref.read(locationProvider.notifier).setLimitedFallback(
          message: result.error ?? 'Location access is unavailable right now.',
        );
    if (user != null) {
      try {
        await ApiService.updateLocation(
          userId: user.userId,
          lat: currentLocation.lat,
          lon: currentLocation.lon,
          timestamp: DateTime.now(),
          city: currentLocation.city,
          deviceId: deviceId,
          locationEnabled: false,
        );
      } catch (_) {}
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.error ??
                'We could not access your live location, so protection will stay limited for now.',
          ),
        ),
      );
    }
  }
}
