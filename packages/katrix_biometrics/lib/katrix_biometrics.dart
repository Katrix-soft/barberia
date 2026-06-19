/// Katrix Biometrics — autenticación biométrica premium multi-plataforma.
///
/// Uso básico:
/// ```dart
/// import 'package:katrix_biometrics/katrix_biometrics.dart';
///
/// final result = await KatrixBiometrics.authenticate();
/// switch (result) {
///   case BiometricSuccess():  // ✅
///   case BiometricFailed():   // ❌
///   case BiometricUnavailable(): // 🚫
/// }
/// ```
library katrix_biometrics;

export 'src/biometric_result.dart';
export 'src/katrix_biometrics_service.dart';
