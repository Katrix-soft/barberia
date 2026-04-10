import 'package:flutter/foundation.dart' show kIsWeb;
import 'env_config_stub.dart'
    if (dart.library.io) 'env_config_mobile.dart'
    if (dart.library.js_util) 'env_config_web.dart'
    if (dart.library.html) 'env_config_web.dart';

class EnvConfig {
  static String get apiUrl => platformEnv.getApiUrl();
  static String get mpAccessToken => platformEnv.getMpAccessToken();
  static String get mpPublicKey => platformEnv.getMpPublicKey();
}

// Abstract bridge
abstract class EnvPlatform {
  String getApiUrl();
  String getMpAccessToken();
  String getMpPublicKey();
}
