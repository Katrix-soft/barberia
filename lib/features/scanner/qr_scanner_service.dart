import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerService {
  static bool get isSupported => !kIsWeb;

  static Widget buildScanner({
    required Function(String) onDetect,
  }) {
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.qr_code_scanner, size: 64),
            SizedBox(height: 16),
            Text('Escaneo QR no disponible en web'),
            SizedBox(height: 8),
            Text('Ingresá el código manualmente'),
          ],
        ),
      );
    }

    return MobileScanner(
      onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        for (final barcode in barcodes) {
          if (barcode.rawValue != null) {
            onDetect(barcode.rawValue!);
            break;
          }
        }
      },
    );
  }
}
