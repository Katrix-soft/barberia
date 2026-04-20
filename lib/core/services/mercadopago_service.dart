import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MercadoPagoService {
  /// Cambiá _devHost por tu IP local cuando probás en Android/iOS físico.
  /// En prod apunta a tu dominio real.
  static const _devHost = 'localhost:8090'; // ← TU IP LOCAL
  static const _prodHost = 'barber.katrix.com.ar'; // ← TU DOMINIO EN PROD
  static const _isDev = false;                  // ← prod

  static String get _backendBase {
    if (kIsWeb) {
      // En web usamos ruta relativa — Caddy hace proxy /mp/* → barber_backend:8090
      return '/mp';
    }
    // En Android/iOS apuntamos al dominio real
    return 'https://barber.katrix.com.ar/mp';
  }

  // El QR se sirve ahora desde el backend (proxy) para evitar problemas de CORS en Web
  String get qrImageUrl => '$_backendBase/qr-image';

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<bool> crearOrder(
    String externalReference,
    double monto,
    String descripcion,
  ) async =>
      (await crearOrderConQr(externalReference, monto, descripcion)) != null;

  /// Crea la orden en MP y retorna el [qr_data] string listo para renderizar
  /// con qr_flutter. Retorna null si falla.
  Future<String?> crearOrderConQr(
    String externalReference,
    double monto,
    String descripcion, {
    List<Map<String, dynamic>>? items,
  }) async {
    final url = Uri.parse('$_backendBase/order');

    final List<Map<String, dynamic>> orderItems = items != null && items.isNotEmpty
        ? items.map((item) => {
              'sku_number': externalReference,
              'category': 'services',
              'title': item['titulo'] ?? descripcion,
              'description': 'Servicio de barbería',
              'unit_price': (item['precio'] as num).toDouble(),
              'quantity': item['cantidad'] ?? 1,
              'unit_measure': 'unit',
              'total_amount': (item['precio'] as num).toDouble() * (item['cantidad'] ?? 1),
            }).toList()
        : [
            {
              'sku_number': externalReference,
              'category': 'services',
              'title': descripcion,
              'description': 'Servicio de barbería',
              'unit_price': monto,
              'quantity': 1,
              'unit_measure': 'unit',
              'total_amount': monto,
            }
          ];

    final body = json.encode({
      'external_reference': externalReference,
      'title': 'Turno BM Barber',
      'description': descripcion,
      'total_amount': monto,
      'items': orderItems,
    });

    try {
      final response = await http
          .put(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final qrData = data['qr_data'] as String?;
        if (qrData != null && qrData.isNotEmpty) return qrData;
        // 204 o respuesta sin qr_data — la orden se creó pero no hay dato de QR
        debugPrint('[MP] crearOrderConQr: sin qr_data en respuesta ${response.statusCode}');
        return null;
      }
      debugPrint('[MP] Error crearOrderConQr: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[MP] Excepción crearOrderConQr: $e');
      return null;
    }
  }

  Future<bool> cancelarOrder() async {
    try {
      final response = await http
          .delete(Uri.parse('$_backendBase/order'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[MP] Excepción cancelarOrder: $e');
      return false;
    }
  }

  Future<String> obtenerEstadoOrden(String externalReference) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_backendBase/order/status?ref=$externalReference'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List?;
        if (elements != null && elements.isNotEmpty) {
          final sorted = elements.toList()
            ..sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
          final order = sorted.first;
          final status = order['status'] as String?;
          if (status == 'closed') {
            final payments = order['payments'] as List?;
            final approved =
                payments?.any((p) => p['status'] == 'approved') ?? false;
            final rejected =
                payments?.any((p) => p['status'] == 'rejected') ?? false;
            if (approved) return 'closed_approved';
            if (rejected) return 'closed_rejected';
          }
          return status ?? 'pending';
        }
      }
      return 'pending';
    } catch (e) {
      debugPrint('[MP] Excepción obtenerEstado: $e');
      return 'error';
    }
  }
}
