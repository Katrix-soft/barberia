import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    
    final canCheckBiometrics = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    return canCheckBiometrics && isDeviceSupported;
  }

  Future<bool> authenticate() async {
    if (kIsWeb) return false;

    try {
      return await _auth.authenticate(
        localizedReason: 'Autenticá con huella o Face ID',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}
