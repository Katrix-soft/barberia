import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class DownloadHelper {
  static Future<String?> downloadExcel(List<int> bytes, String fileName) async {
    final content = base64Encode(bytes);
    final anchor =
        html.AnchorElement(
            href: "data:application/octet-stream;base64,$content",
          )
          ..setAttribute("download", fileName)
          ..click();
    return "Descargado en el navegador";
  }
}
