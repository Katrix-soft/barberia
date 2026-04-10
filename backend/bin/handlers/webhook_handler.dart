import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class WebhookHandler {
  final String dbPath;

  WebhookHandler({required this.dbPath}) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  String get _accessToken {
    final token = Platform.environment['MP_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      throw StateError('[Webhook] ERROR CRÍTICO: MP_ACCESS_TOKEN no configurado.');
    }
    return token;
  }

  String get _webhookSecret {
    final secret = Platform.environment['MP_WEBHOOK_SECRET'];
    if (secret == null || secret.isEmpty) {
      throw StateError('[Webhook] ERROR CRÍTICO: MP_WEBHOOK_SECRET no configurado.');
    }
    return secret;
  }

  /// Valida la firma HMAC-SHA256 que manda MP en el header x-signature
  bool _validateSignature(Request request, String body) {
    try {
      final xSignature = request.headers['x-signature'] ?? '';
      final xRequestId = request.headers['x-request-id'] ?? '';

      if (xSignature.isEmpty) {
        print('[Webhook] ⚠️  Sin header x-signature — rechazado');
        return false;
      }

      // Parsear ts y v1 del header x-signature
      String ts = '';
      String v1 = '';
      for (final part in xSignature.split(',')) {
        final kv = part.trim().split('=');
        if (kv.length == 2) {
          if (kv[0] == 'ts') ts = kv[1];
          if (kv[0] == 'v1') v1 = kv[1];
        }
      }

      if (ts.isEmpty || v1.isEmpty) {
        print('[Webhook] ⚠️  Firma malformada — rechazado');
        return false;
      }

      // Construir el string a firmar según la doc de MP
      // id:{x-request-id};request-date:{ts};
      final manifest = 'id:$xRequestId;request-date:$ts;';

      final key = utf8.encode(_webhookSecret);
      final message = utf8.encode(manifest);
      final hmac = Hmac(sha256, key);
      final digest = hmac.convert(message).toString();

      if (digest != v1) {
        print('[Webhook] ❌ Firma inválida. Expected: $digest | Got: $v1');
        return false;
      }

      print('[Webhook] ✅ Firma válida');
      return true;
    } catch (e) {
      print('[Webhook] ❌ Error validando firma: $e');
      return false;
    }
  }

  Future<Response> handle(Request request) async {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp][Webhook] ─────────────────────────────────────');
    print('[$timestamp][Webhook] Notificación recibida de Mercado Pago');

    try {
      final String body = await request.readAsString();

      // Validar firma antes de procesar
      if (!_validateSignature(request, body)) {
        print('[$timestamp][Webhook] ❌ Request rechazado por firma inválida');
        return Response(401, body: 'Unauthorized\n');
      }

      _processWebhookAsync(body, timestamp);
      return Response.ok('OK\n', headers: {'Content-Type': 'text/plain'});
    } catch (e) {
      print('[$timestamp][Webhook] ❌ Error inicial: $e');
      return Response.internalServerError(body: 'Error\n');
    }
  }

  Future<void> _processWebhookAsync(String body, String timestamp) async {
    try {
      if (body.isEmpty) return;

      print('[$timestamp][Webhook] Body: $body');

      Map<String, dynamic> data;
      try {
        data = json.decode(body) as Map<String, dynamic>;
      } catch (e) {
        print('[$timestamp][Webhook] ⚠️  Body inválido: $e');
        return;
      }

      final String? topic = data['topic'] as String? ?? data['type'] as String?;
      final String? resourceId = data['id']?.toString();

      print('[$timestamp][Webhook] Tópico: $topic | ID: $resourceId');

      if (topic == 'merchant_order') {
        await _handleMerchantOrder(resourceId, timestamp);
      } else {
        print('[$timestamp][Webhook] Tópico "$topic" ignorado.');
      }
    } catch (e, stack) {
      print('[$timestamp][Webhook] ❌ Error inesperado: $e\n$stack');
    }
  }

  Future<void> _handleMerchantOrder(String? orderId, String timestamp) async {
    if (orderId == null || orderId.isEmpty) return;

    final url = 'https://api.mercadopago.com/merchant_orders/$orderId';
    print('[$timestamp][Webhook] GET $url');

    late http.Response response;
    try {
      response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_accessToken', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('[$timestamp][Webhook] ❌ Error consultando MP: $e');
      return;
    }

    if (response.statusCode != 200) {
      print('[$timestamp][Webhook] ❌ MP respondió ${response.statusCode}');
      return;
    }

    final order = json.decode(response.body) as Map<String, dynamic>;
    final status = order['status'] as String?;
    final externalReference = order['external_reference']?.toString();

    print('[$timestamp][Webhook] Orden #$orderId | status: $status | ref: $externalReference');

    if (status != 'closed') {
      print('[$timestamp][Webhook] ⏳ Status "$status" — ignorado');
      return;
    }

    final db = await databaseFactory.openDatabase(dbPath);

    try {
      // 1. Buscar en ventas del POS por external_reference
      if (externalReference != null && externalReference.startsWith('VEN-')) {
        final salesResult = await db.query(
          'sales',
          where: 'external_reference = ?',
          whereArgs: [externalReference],
        );

        if (salesResult.isNotEmpty) {
          final saleId = salesResult.first['id'];
          await db.update(
            'sales',
            {'is_paid': 1, 'payment_method': 'qr'},
            where: 'id = ?',
            whereArgs: [saleId],
          );
          print('[$timestamp][Webhook] ✅ Venta #$saleId marcada como PAGADA por QR');
          return;
        }
      }

      // 2. Fallback: buscar en appointments por ID numérico
      final appointmentId = int.tryParse(externalReference ?? '');
      if (appointmentId != null) {
        final existing = await db.query(
          'appointments',
          where: 'id = ?',
          whereArgs: [appointmentId],
        );

        if (existing.isNotEmpty && existing.first['status'] != 'paid') {
          await db.update(
            'appointments',
            {'status': 'paid', 'payment_method': 'qr', 'paid_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [appointmentId],
          );
          print('[$timestamp][Webhook] ✅ Turno #$appointmentId marcado como PAGADO');
        }
      }
    } finally {
      await db.close();
    }
  }
}
