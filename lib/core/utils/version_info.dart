import 'package:flutter/foundation.dart';

class VersionInfo {
  static const String appVersion = '1.4.28';
  static const int dbVersion = 29;
  
  // URL where version.json is hosted
  static String get remoteVersionUrl => kIsWeb ? '/version.json' : 'https://barber.katrix.com.ar/version.json'; 
}
