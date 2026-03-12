import 'package:flutter/foundation.dart';

class PushNotificationService {
  static Future<void> initialize() async {
    // No-op for non-web platforms
    debugPrint('[Push] Stub: Messaging not supported on this platform');
  }
}
