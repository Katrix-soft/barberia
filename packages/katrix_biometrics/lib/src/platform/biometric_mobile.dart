import 'package:local_auth/local_auth.dart';
import '../biometric_result.dart';

class BiometricPlatform {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> get isAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> get availableTypes async {
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.map((t) {
        return switch (t) {
          BiometricType.fingerprint => 'fingerprint',
          BiometricType.face => 'face',
          BiometricType.iris => 'iris',
          _ => 'strong',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<BiometricResult> authenticate({
    required String localizedReason,
  }) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
      if (authenticated) {
        return const BiometricSuccess();
      }
      return const BiometricFailed(reason: 'Autenticación fallida o cancelada');
    } on Exception catch (e) {
      final msg = e.toString();
      // Detectar cancelación vs error real
      if (msg.contains('UserCancel') || msg.contains('cancel')) {
        return const BiometricFailed(reason: 'Cancelado por el usuario');
      }
      if (msg.contains('NotAvailable') || msg.contains('NotEnrolled')) {
        return BiometricUnavailable(reason: msg);
      }
      return BiometricFailed(reason: msg);
    }
  }

  /// Enrollamiento no aplicable en mobile (ya está en el sistema).
  static Future<BiometricResult> enroll({required String userId}) async {
    return const BiometricUnavailable(
      reason: 'El enrollamiento se hace en Ajustes del sistema en mobile',
    );
  }

  /// Verificación web no aplica en mobile.
  static Future<BiometricResult> verifyWebCredential({
    required String credId,
  }) async {
    return authenticate(
      localizedReason: 'Verificá tu identidad con huella o Face ID',
    );
  }
}
