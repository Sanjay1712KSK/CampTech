import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/services/api_service.dart';
import 'package:guidewire_gig_ins/services/auth_storage_service.dart';
import 'package:local_auth/local_auth.dart';

class AuthFlowHelper {
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

    final localAuth = LocalAuthentication();
    final canCheck = await localAuth.canCheckBiometrics;
    final isSupported = await localAuth.isDeviceSupported();
    if (!canCheck && !isSupported) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication is not available on this device.')),
        );
      }
      return;
    }

    try {
      final didAuthenticate = await localAuth.authenticate(
        localizedReason: 'Enable biometric unlock for GigShield',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
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
