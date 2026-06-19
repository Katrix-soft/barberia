// Stub para desktop (Linux/macOS/Windows) y plataformas sin soporte.
// En el futuro se puede implementar Windows Hello o PIN.
import '../biometric_result.dart';

class BiometricPlatform {
  static Future<bool> get isAvailable async => false;

  static Future<List<String>> get availableTypes async => [];

  static Future<BiometricResult> authenticate({
    required String localizedReason,
  }) async {
    return const BiometricUnavailable(
      reason: 'Biometría no disponible en esta plataforma',
    );
  }

  static Future<BiometricResult> enroll({required String userId}) async {
    return const BiometricUnavailable(
      reason: 'Biometría no disponible en esta plataforma',
    );
  }

  static Future<BiometricResult> verifyWebCredential({
    required String? credId,
  }) async {
    return const BiometricUnavailable(
      reason: 'Biometría no disponible en esta plataforma',
    );
  }
}
