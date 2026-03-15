import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityUtils {
  /// Hashes a password using SHA-256
  static String hashPassword(String password) {
    if (password.isEmpty) return '';
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if a plain text password matches a hash
  static bool verifyPassword(String password, String storedHash) {
    // For legacy support, also check plain text if length is not 64 (SHA-256 hex length)
    if (storedHash.length != 64) {
      return password == storedHash;
    }
    return hashPassword(password) == storedHash;
  }
}
