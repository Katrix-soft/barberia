import 'dart:async';

abstract class DownloadHelper {
  static Future<String?> downloadExcel(List<int> bytes, String fileName) =>
      throw UnsupportedError(
        'Cannot download without a platform implementation',
      );
}
