import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (kIsWeb) {
      // En web, usar API
      try {
        final response = await http.post(
          Uri.parse('https://tu-backend.com/api/send-email'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'to': to,
            'subject': subject,
            'body': body,
          }),
        );
        return response.statusCode == 200;
      } catch (e) {
        return false;
      }
    } else {
      // En mobile/desktop podrías usar mailer si querés
      // O también llamar al backend
      return false;
    }
  }
}
