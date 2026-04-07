import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MercadoPagoService {
  String get _accessToken => dotenv.env['MP_ACCESS_TOKEN'] ?? '';
  String get _userId => dotenv.env['MP_USER_ID'] ?? '';
  String get _externalPosId => dotenv.env['MP_EXTERNAL_POS_ID'] ?? '';
  
  // Exponer el QR estático desde variables
  String get qrImageUrl => dotenv.env['MP_QR_IMAGE'] ?? '';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  /// Crea una nueva orden en el código QR dinámico/estático (Instore API)
  Future<bool> crearOrder(String externalReference, double monto, String descripcion) async {
    final url = Uri.parse(
        'https://api.mercadopago.com/instore/orders/qr/seller/collectors/$_userId/pos/$_externalPosId/qrs');

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
          "total_amount": monto
        }
      ]
    });

    try {
      final response = await http.put(url, headers: _headers, body: body);
      // MP devuelve 204 No Content cuando se crea exitosamente la orden en el POS
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        print('[MP Service] Error al crear order: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('[MP Service] Excepción al crear order: $e');
      return false;
    }
  }

  /// Cancela la orden actual en la caja
  Future<bool> cancelarOrder() async {
    final url = Uri.parse(
        'https://api.mercadopago.com/instore/orders/qr/seller/collectors/$_userId/pos/$_externalPosId/qrs');

    try {
      final response = await http.delete(url, headers: _headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        print('[MP Service] Error al cancelar order: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('[MP Service] Excepción al cancelar order: $e');
      return false;
    }
  }

  /// Revisa el estado de un merchant_order usando la external_reference
  Future<String> obtenerEstadoOrden(String externalReference) async {
    final url = Uri.parse(
        'https://api.mercadopago.com/merchant_orders?external_reference=$externalReference');

    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List?;
        if (elements != null && elements.isNotEmpty) {
          // Tomar el elemento más reciente con status "closed"
          final sortedElements = elements.toList()
            ..sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
            
          final order = sortedElements.first;
          final status = order['status']; 
          
          if (status == 'closed') {
            final payments = order['payments'] as List?;
            final isApproved = payments != null && payments.any((p) => p['status'] == 'approved');
            if (isApproved) {
              return 'closed_approved';
            }
          }
          return status; // ej: "opened", "closed" (but not approved)
        }
      }
      return 'pending'; // no se encontró merchant_order aún
    } catch (e) {
      print('[MP Service] Excepción al consultar order: $e');
      return 'error';
    }
  }
}
