import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../../../../core/services/mercadopago_service.dart';

class MercadopagoQRDialog extends StatefulWidget {
  final double total;
  final String orderReference;
  /// Opcional: ítems del carrito para enriquecer la orden
  final List<Map<String, dynamic>>? items;
  /// Callback invocado luego de que el pago fue aprobado
  final VoidCallback? onPagoAprobado;

  const MercadopagoQRDialog({
    super.key,
    required this.total,
    required this.orderReference,
    this.items,
    this.onPagoAprobado,
  });

  @override
  State<MercadopagoQRDialog> createState() => _MercadopagoQRDialogState();
}

class _MercadopagoQRDialogState extends State<MercadopagoQRDialog> {
  final MercadoPagoService _mpService = MercadoPagoService();
  bool _isLoading = true;
  bool _isError = false;
  String _statusMessage = 'Generando orden...';
  MpQrResult? _qrResult;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initPayment();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initPayment() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _qrResult = null;
      _statusMessage = 'Enviando orden a caja...';
    });

    final result = await _mpService.crearOrderConQr(
      widget.orderReference,
      widget.total,
      'Pos Barber Venta #${widget.orderReference}',
      items: widget.items,
    );

    if (result != null && result.tieneQr) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _qrResult = result;
          _statusMessage = 'Esperando pago...';
        });
        _startPolling();
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _statusMessage = 'Error al generar la orden QR';
        });
      }
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final status = await _mpService.obtenerEstadoOrden(widget.orderReference);

      if (status == 'closed_approved') {
        timer.cancel();
        if (mounted) {
          setState(() { _statusMessage = '¡Pago Aprobado!'; });
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            widget.onPagoAprobado?.call();
            Navigator.of(context).pop(true);
          }
        }
      } else if (status == 'closed' || status == 'closed_rejected') {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isError = true;
            _statusMessage = 'Pago rechazado o cancelado';
          });
        }
      }
    });
  }

  void _cancelPayment() async {
    _pollingTimer?.cancel();
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cancelando...';
    });
    await _mpService.cancelarOrder();
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  Widget _buildQrWidget() {
    final result = _qrResult!;

    // CASO 1: tenemos qr_data → renderizar localmente con qr_flutter
    if (!result.usarImagen && result.qrData != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: QrImageView(
          data: result.qrData!,
          version: QrVersions.auto,
          size: 200,
          gapless: true,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
          errorStateBuilder: (ctx, error) => const Icon(
            Icons.qr_code_2,
            size: 200,
            color: Colors.black87,
          ),
        ),
      );
    }

    // CASO 2: no hay qr_data pero hay qr_image → Image.network como fallback
    if (result.qrImage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Image.network(
          result.qrImage!,
          width: 200,
          height: 200,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.qr_code_2,
            size: 200,
            color: Colors.black87,
          ),
        ),
      );
    }

    // Fallback visual si llegó tieneQr pero ninguno de los dos tiene valor
    return const Icon(Icons.qr_code_2, size: 200, color: Colors.black87);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAGO QR',
              style: TextStyle(
                color: Color(0xFFC5A028),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR')
                  .format(widget.total),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading) ...[
              const CircularProgressIndicator(color: Color(0xFFC5A028)),
              const SizedBox(height: 16),
            ] else if (_isError) ...[
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A028),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reintentar'),
              ),
            ] else if (_qrResult != null) ...[
              _buildQrWidget(),
              const SizedBox(height: 8),
              Text(
                'Escaneá con Mercado Pago',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains('Aprobado') ? Colors.green : Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _cancelPayment,
              child: const Text(
                'Cancelar y Volver',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
