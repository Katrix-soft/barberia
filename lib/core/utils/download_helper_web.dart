import 'dart:async';
import 'dart:html' as html;

class DownloadHelper {
  static Future<String?> downloadExcel(List<int> bytes, String fileName) async {
    try {
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.document.createElement('a') as html.AnchorElement;
      anchor.href = url;
      anchor.download = fileName;
      anchor.style.display = 'none';
      
      html.document.body?.append(anchor);
      anchor.click();
      
      // Keep it in DOM for a moment before cleanup
      Timer(const Duration(milliseconds: 500), () {
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      });
      
      return "Descargado: $fileName";
    } catch (e) {
      return "Error: ${e.toString()}";
    }
  }
}
