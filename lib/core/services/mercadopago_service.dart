import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MercadoPagoService {
  /// Cambiá _devHost por tu IP local cuando probás en Android/iOS físico.
  /// En prod apunta a tu dominio real.
  static const _devHost = 'localhost:8090'; // ← TU IP LOCAL
  static const _prodHost = 'tudominio.com';     // ← TU DOMINIO EN PROD
  static const _isDev = true;                   // ← toggle dev/prod

  static String get _backendBase {
    if (kIsWeb) {
      // En dev apuntamos directo al backend (CORS ya está habilitado)
      if (_isDev) return 'http://192.168.1.9:8090/mp';
      // En prod usamos ruta relativa (mismo servidor)
      return '/mp';
    }
    final host = _isDev ? _devHost : _prodHost;
    final scheme = _isDev ? 'http' : 'https';
    return '$scheme://$host/mp';
  }

  // El QR es estático — lo mostrás desde el panel de MP
  // Si necesitás que sea dinámico, pedíselo al backend aparte
  String get qrImageUrl => dotenv.env['MP_QR_IMAGE'] ?? '';

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<bool> crearOrder(
    String externalReference,
    double monto,
    String descripcion,
  ) async {
    final url = Uri.parse('$_backendBase/order');
    final body = json.encode({
      "external_reference": externalReference,
      "title": "Turno BM Barber",
      "description": descripcion,
      "total_amount": monto,
      "items": [
        {
          "sku_number": externalReference,
          "category": "services",
          "title": descripcion,
          "description": "Servicio de barbería",
          "unit_price": monto,
          "quantity": 1,
          "unit_measure": "unit",
          "total_amount": monto,
        }
      ],
    });

    try {
      final response = await http
          .put(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) return true;
      debugPrint('[MP] Error crearOrder: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[MP] Excepción crearOrder: $e');
      return false;
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
            if (approved) return 'closed_approved';
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
