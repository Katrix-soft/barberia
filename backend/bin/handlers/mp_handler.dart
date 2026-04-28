import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart';

class MpHandler {
  final DotEnv env;
  static const _mpBase = 'https://api.mercadopago.com';

  MpHandler(this.env);

  String get _accessToken {
    final token = env['MP_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      throw StateError('[MpHandler] ERROR CRÍTICO: MP_ACCESS_TOKEN no configurado.');
    }
    return token;
  }

  String get _userId {
    final id = env['MP_USER_ID'];
    if (id == null || id.isEmpty) {
      throw StateError('[MpHandler] ERROR CRÍTICO: MP_USER_ID no configurado.');
    }
    return id;
  }

  String get _externalPosId {
    final pos = env['MP_EXTERNAL_POS_ID'];
    if (pos == null || pos.isEmpty) {
      throw StateError('[MpHandler] ERROR CRÍTICO: MP_EXTERNAL_POS_ID no configurado.');
    }
    return pos;
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  Map<String, String> get _getHeaders => {
        'Authorization': 'Bearer $_accessToken',
      };

  // PUT /mp/order — Crea la orden en el POS y luego hace GET para obtener qr_data
  //
  // Lógica equivalente al mp_qr_route.js:
  //   PASO 1: PUT a /instore/orders/qr/seller/collectors/{userId}/pos/{posId}/qrs
  //   PASO 2: GET a /pos/{posId} para extraer qr_data del QR dinámico
  //
  // Respuesta: { qr_data, qr_image, referencia, usar_imagen }
  Future<Response> crearOrder(Request request) async {
    final timestamp = DateTime.now().toIso8601String();
    try {
      final bodyStr = await request.readAsString();
      final bodyMap = json.decode(bodyStr) as Map<String, dynamic>;

      final monto = (bodyMap['total_amount'] as num?)?.toDouble();
      final referencia = bodyMap['external_reference'] as String?;
      final itemsRaw = bodyMap['items'] as List<dynamic>?;

      if (monto == null || referencia == null || referencia.isEmpty) {
        return Response(
          400,
          body: json.encode({'error': 'Faltan campos: total_amount, external_reference'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Armar los items en formato de MP
      final List<Map<String, dynamic>> mpItems = (itemsRaw != null && itemsRaw.isNotEmpty)
          ? itemsRaw.asMap().entries.map((e) {
              final idx = e.key;
              final item = e.value as Map<String, dynamic>;
              final precio = (item['unit_price'] as num).toDouble();
              final cantidad = (item['quantity'] as num).toInt();
              return {
                'sku_number':   (idx + 1).toString().padLeft(3, '0'),
                'category':     item['category'] ?? 'services',
                'title':        item['title'] ?? 'Servicio barbería',
                'description':  item['description'] ?? 'Servicio barbería',
                'unit_price':   precio,
                'quantity':     cantidad,
                'unit_measure': 'unit',
                'total_amount': precio * cantidad,
              };
            }).toList()
          : [
              {
                'sku_number':   '001',
                'category':     'services',
                'title':        'Servicio barbería',
                'description':  'Servicio barbería',
                'unit_price':   monto,
                'quantity':     1,
                'unit_measure': 'unit',
                'total_amount': monto,
              }
            ];

      final orden = {
        'external_reference': referencia,
        'title':              bodyMap['title'] ?? 'Pago barbería',
        'description':        bodyMap['description'] ?? 'Pago barbería',
        'notification_url':   'https://api.katrix.com.ar/api/mp/webhook',
        'total_amount':       monto,
        'items':              mpItems,
        'cash_out':           {'amount': 0},
      };

      // ── PASO 1: PUT para crear/actualizar la orden en el POS ─────────────────
      final putUrl = Uri.parse(
        '$_mpBase/instore/orders/qr/seller/collectors/$_userId/pos/$_externalPosId/qrs',
      );

      print('[$timestamp][MpHandler] PUT orden → $putUrl');

      final putResponse = await http
          .put(putUrl, headers: _headers, body: json.encode(orden))
          .timeout(const Duration(seconds: 15));

      // MP devuelve 200 con body vacío {} — eso es normal
      print('[$timestamp][MpHandler] PUT status: ${putResponse.statusCode} | body: ${putResponse.body}');

      if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
        dynamic errData = {};
        try { errData = json.decode(putResponse.body); } catch (_) {}
        return Response(
          putResponse.statusCode,
          body: json.encode({
            'error':   (errData is Map ? errData['message'] : null) ?? 'Error MP PUT',
            'detalle': errData,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // qr_data viene directo en la respuesta del PUT — no necesitamos GET al POS
      Map<String, dynamic> putData = {};
      try { putData = json.decode(putResponse.body) as Map<String, dynamic>; } catch (_) {}
      final qrData = putData['qr_data'] as String?;

      return Response.ok(
        json.encode({
          'qr_data':     qrData,
          'qr_image':    null,
          'referencia':  referencia,
          'usar_imagen': false,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[$timestamp][MpHandler] ❌ Excepción crearOrder: $e');
      return Response.internalServerError(
        body: json.encode({'error': 'Error interno', 'detalle': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // DELETE /mp/order — Cancela la orden activa en el POS
  Future<Response> cancelarOrder(Request request) async {
    final timestamp = DateTime.now().toIso8601String();
    try {
      final url = Uri.parse(
        '$_mpBase/instore/orders/qr/seller/collectors/$_userId/pos/$_externalPosId/qrs',
      );

      print('[$timestamp][MpHandler] DELETE orden → $url');

      final response = await http
          .delete(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      print('[$timestamp][MpHandler] Respuesta MP: ${response.statusCode}');

      return Response(
        response.statusCode >= 200 && response.statusCode < 300 ? 200 : response.statusCode,
        body: json.encode({'success': response.statusCode >= 200 && response.statusCode < 300}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[$timestamp][MpHandler] ❌ Excepción cancelarOrder: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // GET /mp/order/status?ref=<externalReference> — Consulta estado de la orden
  Future<Response> obtenerEstado(Request request) async {
    final timestamp = DateTime.now().toIso8601String();
    try {
      final ref = request.url.queryParameters['ref'];
      if (ref == null || ref.isEmpty) {
        return Response(
          400,
          body: json.encode({'error': 'Falta el parámetro ref'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final url = Uri.parse('$_mpBase/merchant_orders?external_reference=$ref');
      print('[$timestamp][MpHandler] GET estado → $url');

      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Response.ok(
          response.body,
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response(
        response.statusCode,
        body: json.encode({'error': response.body}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[$timestamp][MpHandler] ❌ Excepción obtenerEstado: $e');
      return Response.internalServerError(
        body: json.encode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Proxy para la imagen estática del QR (fallback, evita CORS en web)
  Future<Response> qrImage(Request request) async {
    try {
      final imageUrl = env['MP_QR_IMAGE'];
      if (imageUrl == null || imageUrl.isEmpty) {
        return Response(
          404,
          body: json.encode({'error': 'MP_QR_IMAGE no configurado'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 10));
      return Response(
        response.statusCode,
        body: response.bodyBytes,
        headers: {
          'Content-Type': 'image/png',
          'Cache-Control': 'public, max-age=86400',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
