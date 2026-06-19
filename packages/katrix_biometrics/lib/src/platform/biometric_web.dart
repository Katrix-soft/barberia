import 'dart:js_interop';
import '../biometric_result.dart';

// ─── JS interop declarations (WebAuthn + PassKeys) ──────────────────────────
@JS('checkWebBiometrics')
external JSPromise<JSBoolean> _jsCheckWebBiometrics();

@JS('linkWebBiometrics')
external JSPromise<JSString?> _jsLinkWebBiometrics(JSString userId);

@JS('authenticateWebBiometrics')
external JSPromise<JSBoolean> _jsAuthenticateWebBiometrics(JSString? credId);
// ────────────────────────────────────────────────────────────────────────────

class BiometricPlatform {
  static Future<bool> get isAvailable async {
    try {
      final result = await _jsCheckWebBiometrics().toDart;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }

  /// Web siempre reporta solo "passkey" como tipo disponible.
  static Future<List<String>> get availableTypes async {
    final avail = await isAvailable;
    return avail ? ['passkey'] : [];
  }

  /// Autentica usando una credencial WebAuthn ya registrada.
  static Future<BiometricResult> authenticate({
    required String localizedReason,
  }) async {
    // En web el flujo normal de authenticate usa credId de prefs
    // Llamamos a verifyWebCredential sin credId como fallback
    return verifyWebCredential(credId: null);
  }

  /// Registra una nueva credencial WebAuthn (PassKey) para el userId dado.
  static Future<BiometricResult> enroll({required String userId}) async {
    try {
      final credId = await _jsLinkWebBiometrics(userId.toJS).toDart;
      if (credId != null && credId.toDart.isNotEmpty) {
        return BiometricEnrolled(credentialId: credId.toDart);
      }
      return const BiometricFailed(
        reason: 'No se pudo crear la credencial biométrica',
      );
    } catch (e) {
      return BiometricFailed(reason: e.toString());
    }
  }

  /// Verifica usando credId guardado (puede ser null si no hay credencial).
  static Future<BiometricResult> verifyWebCredential({
    required String? credId,
  }) async {
    try {
      final result =
          await _jsAuthenticateWebBiometrics(credId?.toJS).toDart;
      if (result.toDart) {
        return const BiometricSuccess();
      }
      return const BiometricFailed(
        reason: 'Verificación biométrica web fallida',
      );
    } catch (e) {
      return BiometricFailed(reason: e.toString());
    }
  }
}
