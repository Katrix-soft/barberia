import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/version_info.dart';

class VersionService {
  Future<Map<String, dynamic>> checkVersion() async {
    try {
      // Add a timestamp to bypass browser/CDN cache
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String separator = VersionInfo.remoteVersionUrl.contains('?') ? '&' : '?';
      final String url = '${VersionInfo.remoteVersionUrl}${separator}t=$timestamp';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final String remoteAppVersion = data['app_version'] ?? VersionInfo.appVersion;
        final int remoteDbVersion = data['db_version'] ?? VersionInfo.dbVersion;
        final bool forceUpdate = data['force_update'] ?? false;
        final bool maintenanceMode = data['maintenance_mode'] ?? false;

        bool needsAppUpdate = _compareVersions(VersionInfo.appVersion, remoteAppVersion) < 0 || forceUpdate;
        bool needsDbUpdate = VersionInfo.dbVersion < remoteDbVersion;

        return {
          'needsUpdate': needsAppUpdate || needsDbUpdate || maintenanceMode,
          'maintenanceMode': maintenanceMode,
          'message': data['message'] ?? 'Nueva versión disponible',
          'appVersion': remoteAppVersion,
          'dbVersion': remoteDbVersion,
          'update_url': data['update_url'] ?? '',
        };
      }
    } catch (e) {
      debugPrint('Error checking version: $e');
    }
    
    return {'needsUpdate': false};
  }

  /// Returns < 0 if v1 < v2, 0 if v1 == v2, > 0 if v1 > v2
  int _compareVersions(String v1, String v2) {
    try {
      // Remove build suffix (+1) and trim
      final v1Clean = v1.split('+')[0].trim();
      final v2Clean = v2.split('+')[0].trim();
      
      final v1Parts = v1Clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      final v2Parts = v2Clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      
      // Compare up to the length of the shortest version string
      final minLength = v1Parts.length < v2Parts.length ? v1Parts.length : v2Parts.length;
      
      for (int i = 0; i < minLength; i++) {
        if (v1Parts[i] < v2Parts[i]) return -1;
        if (v1Parts[i] > v2Parts[i]) return 1;
      }
      
      // If common parts are equal, the one with more parts is "newer"
      if (v1Parts.length < v2Parts.length) return -1;
      if (v1Parts.length > v2Parts.length) return 1;
      
      return 0;
    } catch (e) {
      debugPrint('Error comparing versions ($v1 vs $v2): $e');
      return 0; // Default to no update needed on error to avoid loops
    }
  }
}
