import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/version_info.dart';

class VersionService {
  Future<Map<String, dynamic>> checkVersion() async {
    try {
      // In web, we fetch from the same origin. 
      // If it's a relative URL, it will use the current domain.
      final response = await http.get(Uri.parse(VersionInfo.remoteVersionUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final String remoteAppVersion = data['app_version'] ?? VersionInfo.appVersion;
        final int remoteDbVersion = data['db_version'] ?? VersionInfo.dbVersion;
        final bool forceUpdate = data['force_update'] ?? false;
        final bool maintenanceMode = data['maintenance_mode'] ?? false;

        // Simple version comparison (can be improved with a more robust parser)
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
    // Basic implementation for 0.1.2+1 format
    // For production, consider using 'pub_semver' package.
    final v1Clean = v1.split('+')[0];
    final v2Clean = v2.split('+')[0];
    
    final v1Parts = v1Clean.split('.').map(int.parse).toList();
    final v2Parts = v2Clean.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      if (v1Parts[i] < v2Parts[i]) return -1;
      if (v1Parts[i] > v2Parts[i]) return 1;
    }
    return 0;
  }
}
