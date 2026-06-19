import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class DownloadHelper {
  static Future<String?> downloadExcel(
      List<int> bytes, String fileName) async {
    try {
      final jsBytes = bytes.map((b) => b.toJS).toList().toJS;
      final blob = web.Blob(
        jsBytes,
        web.BlobPropertyBag(
          type:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      );
      final url = web.URL.createObjectURL(blob);

      final anchor =
          web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = fileName;
      anchor.style.display = 'none';

      web.document.body?.append(anchor);
      anchor.click();

      // Keep it in DOM for a moment before cleanup
      Timer(const Duration(milliseconds: 500), () {
        anchor.remove();
        web.URL.revokeObjectURL(url);
      });

      return 'Descargado: $fileName';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }
}
