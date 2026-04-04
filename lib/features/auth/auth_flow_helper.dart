import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/auth_storage_service.dart';
import 'package:guidewire_gig_ins/services/device_auth_service.dart';

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
}
