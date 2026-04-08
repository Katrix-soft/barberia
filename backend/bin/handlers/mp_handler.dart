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

  String get _externalStoreId {
    final store = env['MP_EXTERNAL_STORE_ID'];
    if (store == null || store.isEmpty) {
      throw StateError('[MpHandler] ERROR CRÍTICO: MP_EXTERNAL_STORE_ID no configurado.');
    }
    return store;
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  // PUT /mp/order — Crea o actualiza la orden en el QR del POS
  Future<Response> crearOrder(Request request) async {
    final timestamp = DateTime.now().toIso8601String();
    try {
      final body = await request.readAsString();
      final url = Uri.parse(
        '$_mpBase/instore/qr/seller/collectors/$_userId/stores/$_externalStoreId/pos/$_externalPosId/orders',
      );

      print('[$timestamp][MpHandler] PUT orden → $url');

      final response = await http
          .put(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      print('[$timestamp][MpHandler] Respuesta MP: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Response.ok(
          json.encode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response(
        response.statusCode,
        body: json.encode({'success': false, 'error': response.body}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('[$timestamp][MpHandler] ❌ Excepción crearOrder: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // DELETE /mp/order — Cancela la orden activa en el POS
  Future<Response> cancelarOrder(Request request) async {
    final timestamp = DateTime.now().toIso8601String();
    try {
      final url = Uri.parse(
        '$_mpBase/instore/qr/seller/collectors/$_userId/stores/$_externalStoreId/pos/$_externalPosId/orders',
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
}
