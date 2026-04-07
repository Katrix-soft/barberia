import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/services/mercadopago_service.dart';

class MercadopagoQRDialog extends StatefulWidget {
  final double total;
  final String orderReference;

  const MercadopagoQRDialog({
    super.key,
    required this.total,
    required this.orderReference,
  });

  @override
  State<MercadopagoQRDialog> createState() => _MercadopagoQRDialogState();
}

class _MercadopagoQRDialogState extends State<MercadopagoQRDialog> {
  final MercadoPagoService _mpService = MercadoPagoService();
  bool _isLoading = true;
  bool _isError = false;
  String _statusMessage = 'Generando orden...';
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
      _statusMessage = 'Enviando orden a caja...';
    });

    final success = await _mpService.crearOrder(
      widget.orderReference,
      widget.total,
      'Pos Barber Venta #${widget.orderReference}',
    );

    if (success) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          setState(() {
            _statusMessage = '¡Pago Aprobado!';
          });
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      } else if (status == 'closed') { // Closed but not approved (rejected/cancelled)
        timer.cancel();
         if (mounted) {
          setState(() {
             _isError = true;
             _statusMessage = 'Pago rechazado o cancelado';
          });
        }
      } else if (status == 'error') {
         // Optionally retry or fail
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
              NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(widget.total),
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
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.network(
                  _mpService.qrImageUrl,
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.qr_code_2,
                    size: 200,
                    color: Colors.black87,
                  ),
                ),
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
