import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'biometric_result.dart';

// Conditional imports: en tiempo de compilación elige la implementación correcta
import 'platform/biometric_stub.dart'
    if (dart.library.js_interop) 'platform/biometric_web.dart'
    if (dart.library.io) 'platform/biometric_mobile.dart';

/// 🔐 Katrix Biometrics Service
///
/// Punto de entrada unificado para autenticación biométrica.
/// Detecta automáticamente la plataforma y usa la implementación apropiada.
///
/// ```dart
/// // Verificar disponibilidad
/// if (await KatrixBiometrics.isAvailable) {
///   final result = await KatrixBiometrics.authenticate();
///   switch (result) {
///     case BiometricSuccess():   handleSuccess();
///     case BiometricFailed(reason: final r): showError(r);
///     case BiometricUnavailable(): showFallback();
///     case BiometricEnrolled():  // solo en web
///   }
/// }
/// ```
class KatrixBiometrics {
  KatrixBiometrics._();

  static const _prefKeyEnabled = 'katrix_bio_enabled';
  static const _prefKeyCredId = 'katrix_bio_cred_id';
  static const _prefKeyUserId = 'katrix_bio_user_id';

  // ── Capacidades ────────────────────────────────────────────────────────────

  /// `true` si el dispositivo/browser soporta biometría.
  static Future<bool> get isAvailable => BiometricPlatform.isAvailable;

  /// Lista de tipos disponibles: `['fingerprint', 'face', 'passkey', ...]`
  static Future<List<String>> get availableTypes =>
      BiometricPlatform.availableTypes;

  /// `true` si el usuario tiene biometría habilitada en prefs.
  static Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyEnabled) ?? false;
  }

  /// Credential ID guardado (solo relevante para Web/WebAuthn).
  static Future<String?> get savedCredentialId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyCredId);
  }

  // ── Autenticación ──────────────────────────────────────────────────────────

  /// Autentica al usuario con biometría.
  ///
  /// En **mobile**: usa local_auth (huella/Face ID del sistema).
  /// En **web**: usa WebAuthn con credencial guardada.
  static Future<BiometricResult> authenticate({
    String reason = 'Verificá tu identidad para acceder',
  }) async {
    final available = await isAvailable;
    if (!available) {
      return const BiometricUnavailable(
        reason: 'Biometría no disponible en este dispositivo',
      );
    }

    if (kIsWeb) {
      final credId = await savedCredentialId;
      if (credId == null) {
        return const BiometricUnavailable(
          reason: 'No hay credencial biométrica guardada. Registrá primero.',
        );
      }
      return BiometricPlatform.verifyWebCredential(credId: credId);
    }

    return BiometricPlatform.authenticate(localizedReason: reason);
  }

  // ── Enrollamiento ──────────────────────────────────────────────────────────

  /// Registra biometría para el usuario.
  ///
  /// En **mobile**: habilita el flag en prefs (la huella ya está en el sistema).
  /// En **web**: crea una nueva credencial WebAuthn y guarda el credId.
  ///
  /// Returns [BiometricEnrolled] en web, [BiometricSuccess] en mobile.
  static Future<BiometricResult> enroll({required String userId}) async {
    final available = await isAvailable;
    if (!available) {
      return const BiometricUnavailable(
        reason: 'Biometría no disponible en este dispositivo',
      );
    }

    if (kIsWeb) {
      final result = await BiometricPlatform.enroll(userId: userId);
      if (result is BiometricEnrolled) {
        await _saveCredentials(
          userId: userId,
          credId: result.credentialId,
        );
      }
      return result;
    }

    // Mobile: solo necesitamos guardar el flag
    await _saveCredentials(userId: userId, credId: null);
    return const BiometricSuccess();
  }

  // ── Gestión de estado ──────────────────────────────────────────────────────

  /// Guarda las credenciales en SharedPreferences.
  static Future<void> _saveCredentials({
    required String userId,
    required String? credId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, true);
    await prefs.setString(_prefKeyUserId, userId);
    if (credId != null) {
      await prefs.setString(_prefKeyCredId, credId);
    }
  }

  /// Elimina todas las credenciales biométricas guardadas.
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyEnabled);
    await prefs.remove(_prefKeyCredId);
    await prefs.remove(_prefKeyUserId);
  }

  /// El userId que tiene biometría vinculada.
  static Future<String?> get linkedUserId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUserId);
  }
}
