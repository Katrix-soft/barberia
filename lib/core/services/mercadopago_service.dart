import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

/// Resultado de crear una orden QR en Mercado Pago.
class MpQrResult {
  /// String de datos para renderizar el QR con qr_flutter (puede ser null).
  final String? qrData;
  /// URL de imagen PNG del QR (fallback cuando qrData es null).
  final String? qrImage;
  /// true = usar Image.network(qrImage), false = usar QrImageView(qrData).
  final bool usarImagen;

  const MpQrResult({
    required this.qrData,
    required this.qrImage,
    required this.usarImagen,
  });

  /// Tiene al menos uno de los dos valores disponibles.
  bool get tieneQr => qrData != null || qrImage != null;
}

class MercadoPagoService {
  static String get _backendBase {
    if (kIsWeb) {
      if (kDebugMode) {
        return 'http://localhost:8090/mp';
      }
      return '/mp';
    }
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8090/mp';
      }
      return 'http://localhost:8090/mp';
    }
    return 'https://barber.katrix.com.ar/mp';
  }

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  /// Crea un cliente HTTP que en debug ignora errores de certificado SSL.
  /// En release usa el cliente estándar con validación completa.
  http.Client _buildClient() {
    if (kDebugMode && !kIsWeb) {
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      return IOClient(httpClient);
    }
    return http.Client();
  }

  /// Crea la orden en MP.
  /// El backend hace PASO 1 (PUT) + PASO 2 (GET al POS) para extraer qr_data.
  /// Retorna [MpQrResult] con qr_data y/o qr_image, o null si falla.
  Future<MpQrResult?> crearOrderConQr(
    String externalReference,
    double monto,
    String descripcion, {
    List<Map<String, dynamic>>? items,
  }) async {
    final url = Uri.parse('$_backendBase/order');

    final List<Map<String, dynamic>> orderItems =
        items != null && items.isNotEmpty
            ? items.asMap().entries.map((e) {
                final idx = e.key;
                final item = e.value;
                final precio = (item['precio'] as num).toDouble();
                final cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;
                return {
                  'sku_number':   (idx + 1).toString().padLeft(3, '0'),
                  'category':     'services',
                  'title':        item['titulo'] ?? descripcion,
                  'description':  item['titulo'] ?? descripcion,
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
                  'title':        descripcion,
                  'description':  descripcion,
                  'unit_price':   monto,
                  'quantity':     1,
                  'unit_measure': 'unit',
                  'total_amount': monto,
                }
              ];

    final body = json.encode({
      'external_reference': externalReference,
      'title':              'Turno BM Barber',
      'description':        descripcion,
      'total_amount':       monto,
      'items':              orderItems,
    });

    final client = _buildClient();
    try {
      final response = await client
          .put(url, headers: _headers, body: body)
          .timeout(const Duration(seconds: 20));

      debugPrint('[MP] crearOrderConQr → ${response.statusCode}: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final qrData  = data['qr_data'] as String?;
        final qrImage = data['qr_image'] as String?;
        final usarImagen = data['usar_imagen'] as bool? ?? (qrData == null);
        return MpQrResult(
          qrData:     qrData,
          qrImage:    qrImage,
          usarImagen: usarImagen,
        );
      }
      debugPrint('[MP] Error crearOrderConQr: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[MP] Excepción crearOrderConQr: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Alias booleano para compatibilidad con código anterior.
  Future<bool> crearOrder(
    String externalReference,
    double monto,
    String descripcion,
  ) async =>
      (await crearOrderConQr(externalReference, monto, descripcion))?.tieneQr ?? false;

  Future<bool> cancelarOrder() async {
    final client = _buildClient();
    try {
      final response = await client
          .delete(Uri.parse('$_backendBase/order'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[MP] Excepción cancelarOrder: $e');
      return false;
    } finally {
      client.close();
    }
  }

  Future<String> obtenerEstadoOrden(String externalReference) async {
    final client = _buildClient();
    try {
      final response = await client
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
            final approved = payments?.any((p) => p['status'] == 'approved') ?? false;
            final rejected = payments?.any((p) => p['status'] == 'rejected') ?? false;
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
    } finally {
      client.close();
    }
  }
}
