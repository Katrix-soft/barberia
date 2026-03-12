import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class EmailService {
  static const String _resendApiKey = 're_M97AXhDT_DxWtj2jv39g6Ru9yybSZydKC';
  static const String _fromEmail = 'onboarding@resend.dev'; // Resend allows this for testing
  static String lastError = '';

  static Future<bool> _sendResendEmail({
    required String toEmail,
    required String subject,
    required String htmlContent,
  }) async {
    const String url = 'https://api.resend.com/emails';

    try {
      debugPrint('[Resend] Sending email to $toEmail...');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_resendApiKey',
        },
        body: jsonEncode({
          'from': 'BM BARBER <$_fromEmail>',
          'to': [toEmail],
          'subject': subject,
          'html': htmlContent,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[Resend] Email sent successfully: ${response.body}');
        lastError = '';
        return true;
      } else {
        lastError = response.body;
        debugPrint('[Resend] Failed to send email: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint('[Resend] Error sending email: $e');
      return false;
    }
  }

  static Future<bool> sendPasswordRecovery({
    required String toName,
    required String toEmail,
    required String username,
    required String password,
  }) async {
    final String html = '''
      <div style="font-family: sans-serif; padding: 20px; color: #333;">
        <h2 style="color: #C5A028;">Bienvenido a BM BARBER</h2>
        <p>Hola <strong>$toName</strong>,</p>
        <p>Se ha creado tu cuenta con éxito. Aquí tienes tus credenciales de acceso:</p>
        <div style="background: #f4f4f4; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <p style="margin: 5px 0;"><strong>Usuario:</strong> $username</p>
          <p style="margin: 5px 0;"><strong>Contraseña:</strong> $password</p>
        </div>
        <p>Por seguridad, te recomendamos cambiar tu contraseña al ingresar por primera vez.</p>
        <br>
        <p>Saludos,<br>El equipo de BM BARBER</p>
      </div>
    ''';

    return await _sendResendEmail(
      toEmail: toEmail,
      subject: 'Tus accesos - BM BARBER',
      htmlContent: html,
    );
  }

  static Future<bool> sendOTP({
    required String toEmail,
    required String toName,
    required String otpCode,
  }) async {
    final String html = '''
      <div style="font-family: sans-serif; padding: 20px; color: #333;">
        <h2 style="color: #C5A028;">Recuperación de Contraseña</h2>
        <p>Hola <strong>$toName</strong>,</p>
        <p>Has solicitado restablecer tu contraseña. Tu código de verificación es:</p>
        <div style="background: #f4f4f4; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
          <h1 style="color: #C5A028; letter-spacing: 5px; margin: 0;">$otpCode</h1>
        </div>
        <p>Ingresa este código en la aplicación para continuar.</p>
        <p style="font-size: 12px; color: #999;">Si no solicitaste este cambio, puedes ignorar este correo.</p>
      </div>
    ''';

    return await _sendResendEmail(
      toEmail: toEmail,
      subject: 'Código de recuperación - BM BARBER',
      htmlContent: html,
    );
  }
}
