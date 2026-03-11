import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadHelper {
  static Future<String?> downloadExcel(List<int> bytes, String fileName) async {
    Directory? directory;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final String filePath = "${directory.path}/$fileName";
    final File file = File(filePath);
    await file.writeAsBytes(bytes);

    // Try to open the file location
    try {
      if (Platform.isWindows) {
        // Windows specific: open the folder
        await launchUrl(Uri.file(directory.path));
      } else {
        await launchUrl(Uri.directory(directory.path));
      }
    } catch (e) {
      // Ignorar si no se puede abrir
    }

    return filePath;
  }
}
