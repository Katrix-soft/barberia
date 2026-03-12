import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:js_interop';

class PushNotificationService {
  // REPLACE with your real VAPID Public Key generated from your server
  static const String vapidPublicKey = 'BEl62i_SJbx896h7uU6X6B62_N2S6H-KREK7y_99K_99K_99K_99K_99K_99K_99K_99K';
  static const String serverUrl = 'https://api.katrix.com.ar/api/notifications/subscribe';

  static Future<void> initialize() async {
    if (!kIsWeb) return;

    try {
      await _requestPermissionAndSubscribe();
    } catch (e) {
      debugPrint('[Push] Failed to initialize: $e');
    }
  }

  static Future<void> _requestPermissionAndSubscribe() async {
    // This is a bridge to JS as Flutter doesn't have a direct Web Push API in core
    // We'll use a small JS snippet in index.html to help, or direct JS interop.
    
    // Check if ServiceWorker is supported
    // For brevity and reliability, we'll call a JS function defined in index.html
    _jsSubscribe(vapidPublicKey, serverUrl);
  }
}

@JS('window.subscribeToPush')
external void _jsSubscribe(String publicKey, String apiUrl);
