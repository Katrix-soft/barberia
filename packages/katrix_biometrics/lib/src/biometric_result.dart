/// Resultado tipado de una operación biométrica.
/// Usar con switch exhaustivo para manejar todos los casos.
sealed class BiometricResult {
  const BiometricResult();
}

/// ✅ Autenticación exitosa.
final class BiometricSuccess extends BiometricResult {
  const BiometricSuccess();
}

/// ❌ Autenticación fallida (usuario canceló, huella no coincide, etc.)
final class BiometricFailed extends BiometricResult {
  final String reason;
  final String? errorCode;
  const BiometricFailed({required this.reason, this.errorCode});
}

/// 🚫 Biometría no disponible en este dispositivo/plataforma.
final class BiometricUnavailable extends BiometricResult {
  final String reason;
  const BiometricUnavailable({required this.reason});
}

/// 🔗 Enrollamiento completado (solo Web/WebAuthn).
final class BiometricEnrolled extends BiometricResult {
  /// Credential ID de WebAuthn para guardar en preferencias.
  final String credentialId;
  const BiometricEnrolled({required this.credentialId});
}
