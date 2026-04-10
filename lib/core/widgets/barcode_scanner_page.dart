import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  // We initialize the controller inside a lazy getter or similar to avoid issues on web if not used
  late MobileScannerController controller;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      controller = MobileScannerController(
        formats: [BarcodeFormat.all],
      );
      controller.start();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      controller.stop();
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebFallback();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear'),
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
                  Navigator.pop(context, code);
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFC5A028), width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                onPressed: () => controller.toggleTorch(),
                icon: const Icon(
                  Icons.flashlight_on_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFallback() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 100, color: Color(0xFFC5A028)),
            const SizedBox(height: 24),
            const Text(
              'Escaneo no disponible en Web',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Por favor, ingresá el código manualmente.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _showManualInputDialog(context),
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('INGRESAR CÓDIGO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC5A028),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInputDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Ingresar código', style: TextStyle(color: Color(0xFFC5A028))),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ej: 7791234567890',
            hintStyle: TextStyle(color: Colors.white30),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC5A028))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A028)),
            child: const Text('OK', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
