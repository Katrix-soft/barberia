import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Handler principal para el endpoint POST /webhook/mercadopago
class WebhookHandler {
  final String dbPath;

  WebhookHandler({required this.dbPath}) {
    // Inicializar sqflite para desktop/server
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  /// Devuelve el token de Mercado Pago desde la variable de entorno.
  String get _accessToken {
    final token = Platform.environment['MP_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      throw StateError('[Webhook] ERROR CRÍTICO: MP_ACCESS_TOKEN no está configurado.');
    }
    return token;
  }

  Future<Response> handle(Request request) async {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp][Webhook] ─────────────────────────────────────');
    print('[$timestamp][Webhook] Notificación recibida de Mercado Pago');

    try {
      // ✅ PASO 1: Leer el cuerpo ANTES de responder. 
      // Si devolvemos el Response antes de leerlo, Shelf puede cerrar el stream.
      final String body = await request.readAsString();
      
      // Procesamos de forma asíncrona sin bloquear la respuesta de red.
      _processWebhookAsync(body, timestamp);

      return Response.ok('OK\n', headers: {'Content-Type': 'text/plain'});
    } catch (e) {
      print('[$timestamp][Webhook] ❌ Error inicial al leer el body: $e');
      return Response.internalServerError(body: 'Error reading body\n');
    }
  }

  /// Procesa la notificación después de leer el body.
  Future<void> _processWebhookAsync(String body, String timestamp) async {
    try {
      if (body.isEmpty) {
        print('[$timestamp][Webhook] ⚠️  Body vacío, ignorando.');
        return;
      }

      print('[$timestamp][Webhook] Body recibido: $body');

      Map<String, dynamic> data;
      try {
        data = json.decode(body) as Map<String, dynamic>;
      } catch (e) {
        print('[$timestamp][Webhook] ⚠️  Body inválido (no es JSON): $e');
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
      print('[$timestamp][Webhook] ❌ Error inesperado: $e');
      print('[$timestamp][Webhook] Stack: $stack');
    }
  }


  /// Consulta el merchant_order a MP y actualiza el turno si está cerrado.
  Future<void> _handleMerchantOrder(String? orderId, String timestamp) async {
    if (orderId == null || orderId.isEmpty) {
      print('[$timestamp][Webhook] ⚠️  merchant_order sin ID, ignorando.');
      return;
    }

    // ✅ PASO 3: Consultar el estado de la orden a Mercado Pago
    final url = 'https://api.mercadopago.com/merchant_orders/$orderId';
    print('[$timestamp][Webhook] Consultando orden: GET $url');

    late http.Response response;
    try {
      response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('[$timestamp][Webhook] ❌ Error al consultar MP: $e');
      return;
    }

    if (response.statusCode != 200) {
      print('[$timestamp][Webhook] ❌ MP respondió ${response.statusCode}: ${response.body}');
      return;
    }

    late Map<String, dynamic> order;
    try {
      order = json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('[$timestamp][Webhook] ❌ Respuesta de MP no es JSON válido: $e');
      return;
    }

    final status = order['status'] as String?;
    final externalReference = order['external_reference']?.toString();

    print('[$timestamp][Webhook] Orden #$orderId | status: "$status" | external_reference: "$externalReference"');

    // ✅ PASO 4: Evaluar el estado
    if (status == 'closed') {
      print('[$timestamp][Webhook] ✅ Pago completado. Buscando destino de referencia: $externalReference');
      
      if (externalReference != null && externalReference.startsWith('VEN-')) {
         await _markSaleAsPaid(externalReference, timestamp);
      } else {
         await _markAppointmentAsPaid(externalReference, timestamp);
      }
    } else if (status == 'opened') {
      print('[$timestamp][Webhook] ⏳ Pago aún no completado (status: opened). Ignorando.');
    } else {
      print('[$timestamp][Webhook] ℹ️  Status desconocido: "$status". Ignorando.');
    }
  }

  /// Actualiza el campo `status` del turno en la base de datos SQLite.
  Future<void> _markAppointmentAsPaid(String? externalReference, String timestamp) async {
    if (externalReference == null || externalReference.isEmpty) {
      print('[$timestamp][Webhook] ⚠️  external_reference vacío, no se puede actualizar turno.');
      return;
    }

    final appointmentId = int.tryParse(externalReference);
    if (appointmentId == null) {
      print('[$timestamp][Webhook] ⚠️  external_reference "$externalReference" no es un ID de turno válido.');
      return;
    }

    try {
      final db = await databaseFactory.openDatabase(dbPath);

      // Verificar que el turno existe
      final existing = await db.query(
        'appointments',
        where: 'id = ?',
        whereArgs: [appointmentId],
      );

      if (existing.isEmpty) {
        print('[$timestamp][Webhook] ⚠️  Turno #$appointmentId no encontrado en la base de datos.');
        await db.close();
        return;
      }

      final currentStatus = existing.first['status'] as String?;
      print('[$timestamp][Webhook] Turno #$appointmentId encontrado. Status actual: "$currentStatus"');

      if (currentStatus == 'paid') {
        print('[$timestamp][Webhook] ℹ️  Turno #$appointmentId ya estaba marcado como pagado.');
        await db.close();
        return;
      }

      // Actualizar a 'paid'
      final rowsAffected = await db.update(
        'appointments',
        {
          'status': 'paid',
          'payment_method': 'qr',
          'paid_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [appointmentId],
      );

      await db.close();

      if (rowsAffected > 0) {
        print('[$timestamp][Webhook] ✅ Turno #$appointmentId marcado como PAGADO correctamente.');
      } else {
        print('[$timestamp][Webhook] ❌ No se actualizó el turno #$appointmentId (0 rows affected).');
      }
    } catch (e, stack) {
    }
  }

  /// Actualiza el campo `is_paid` de la venta en la base de datos SQLite.
  Future<void> _markSaleAsPaid(String? externalReference, String timestamp) async {
    if (externalReference == null || externalReference.isEmpty) {
      print('[$timestamp][Webhook] ⚠️  external_reference vacío, no se puede actualizar venta.');
      return;
    }

    try {
      final db = await databaseFactory.openDatabase(dbPath);

      // Verificar que la venta existe
      final existing = await db.query(
        'sales',
        where: 'external_reference = ?',
        whereArgs: [externalReference],
      );

      if (existing.isEmpty) {
        print('[$timestamp][Webhook] ⚠️  Venta con ref "$externalReference" no encontrada.');
        await db.close();
        return;
      }

      print('[$timestamp][Webhook] Venta "$externalReference" encontrada.');

      // Actualizar a is_paid = 1
      final rowsAffected = await db.update(
        'sales',
        {
          'is_paid': 1,
          'payment_method': 'qr',
        },
        where: 'external_reference = ?',
        whereArgs: [externalReference],
      );

      await db.close();

      if (rowsAffected > 0) {
        print('[$timestamp][Webhook] ✅ Venta "$externalReference" marcada como PAGADA (QR) correctamente.');
      } else {
        print('[$timestamp][Webhook] ❌ No se actualizó la venta "$externalReference" (0 rows affected).');
      }
    } catch (e, stack) {
      print('[$timestamp][Webhook] ❌ Error al acceder a la base de datos (Sales): $e');
      print('[$timestamp][Webhook] Stack: $stack');
    }
  }
}
