import 'dart:async';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  // Service disabled: User requested local-only unification and removed external API dependency.
  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[Push] Web: Service disabled (Standalone Mode)');
    }
  }
}
