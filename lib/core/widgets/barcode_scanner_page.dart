import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Devuelve true si la plataforma actual soporta cámara nativa vía mobile_scanner.
bool get _isCameraSupported {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late MobileScannerController controller;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    if (_isCameraSupported) {
      controller = MobileScannerController(
        formats: [BarcodeFormat.all],
      );
      controller.start();
    }
  }

  @override
  void dispose() {
    if (_isCameraSupported) {
      controller.stop();
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // En web, Windows, macOS, Linux → fallback con input manual
    if (!_isCameraSupported) {
      return _buildFallback();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear Código'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  _isScanned = true;
                  Navigator.pop(context, code.trim());
                }
              }
            },
          ),
          // Visor central con esquinas doradas
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFFC5A028).withOpacity(0.4),
                        width: 1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                // Esquinas doradas
                ...['tl', 'tr', 'bl', 'br'].map((pos) {
                  final top = pos.startsWith('t');
                  final left = pos.endsWith('l');
                  return Positioned(
                    top: top ? 0 : null,
                    bottom: !top ? 0 : null,
                    left: left ? 0 : null,
                    right: !left ? 0 : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        border: Border(
                          top: top
                              ? const BorderSide(
                                  color: Color(0xFFC5A028), width: 3)
                              : BorderSide.none,
                          bottom: !top
                              ? const BorderSide(
                                  color: Color(0xFFC5A028), width: 3)
                              : BorderSide.none,
                          left: left
                              ? const BorderSide(
                                  color: Color(0xFFC5A028), width: 3)
                              : BorderSide.none,
                          right: !left
                              ? const BorderSide(
                                  color: Color(0xFFC5A028), width: 3)
                              : BorderSide.none,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: (top && left)
                              ? const Radius.circular(4)
                              : Radius.zero,
                          topRight: (top && !left)
                              ? const Radius.circular(4)
                              : Radius.zero,
                          bottomLeft: (!top && left)
                              ? const Radius.circular(4)
                              : Radius.zero,
                          bottomRight: (!top && !left)
                              ? const Radius.circular(4)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Apuntá la cámara al código de barras',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => controller.toggleTorch(),
                      icon: const Icon(
                        Icons.flashlight_on_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      onPressed: () => _showManualInputDialog(context),
                      icon: const Icon(
                        Icons.keyboard_alt_outlined,
                        color: Color(0xFFC5A028),
                        size: 32,
                      ),
                      tooltip: 'Ingresar manualmente',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback para Web / Windows / macOS / Linux
  Widget _buildFallback() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Ingresar Código'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFC5A028).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFC5A028).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 56,
                  color: Color(0xFFC5A028),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Escaneo no disponible',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresá el código de barras manualmente\no usá un escáner USB/Bluetooth.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => _showManualInputDialog(context),
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('INGRESAR CÓDIGO MANUALMENTE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A028),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualInputDialog(BuildContext context) {
    final inputController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Ingresar código',
          style: TextStyle(color: Color(0xFFC5A028), fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: inputController,
          autofocus: true,
          keyboardType: TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ej: 7791234567890',
            hintStyle: const TextStyle(color: Colors.white30),
            prefixIcon: const Icon(Icons.qr_code, color: Color(0xFFC5A028)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC5A028)),
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(ctx);
              Navigator.pop(context, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = inputController.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.pop(context, val);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC5A028),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
