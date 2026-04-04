import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class DeviceAuthService {
  const DeviceAuthService();

  Future<bool> canUseBiometrics() async {
    if (kIsWeb) {
      return false;
    }

    final localAuth = LocalAuthentication();
    final canCheck = await localAuth.canCheckBiometrics;
    final isSupported = await localAuth.isDeviceSupported();
    return canCheck || isSupported;
  }

  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    if (kIsWeb) {
      return true;
    }

    final localAuth = LocalAuthentication();
    final isAvailable = await canUseBiometrics();
    if (!isAvailable) {
      return false;
    }

    return localAuth.authenticate(
      localizedReason: reason,
      options: AuthenticationOptions(
        biometricOnly: biometricOnly,
        stickyAuth: true,
      ),
    );
  }
}
