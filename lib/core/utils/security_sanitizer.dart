class SecuritySanitizer {
  /// Basic sanitization to prevent XSS-like injections in text fields.
  static String sanitize(String input) {
    if (input.isEmpty) return input;
    
    // Remove potentially dangerous HTML/Script characters
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;')
        .trim();
  }

  /// Specialized sanitization for numeric IDs or codes
  static String sanitizeNumeric(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Sanitizes usernames/emails (lowercasing and trimming)
  static String sanitizeIdentifier(String input) {
    return input.trim().toLowerCase();
  }
}
