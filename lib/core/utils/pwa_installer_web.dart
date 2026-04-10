import 'dart:js_util' as js_util;
import 'package:js/js.dart';
import 'package:flutter/foundation.dart';

@JS()
library pwa;

class PwaInstaller {
  static Future<bool> checkWebBiometrics() async {
    try {
      final jsResult = js_util.callMethod(js_util.globalThis, 'checkWebBiometrics', []);
      final val = await js_util.promiseToFuture<dynamic>(jsResult);
      debugPrint('[PwaInstaller] checkWebBiometrics raw: $val');
      return val == true || val.toString() == 'true';
    } catch (e) {
      debugPrint('[PwaInstaller] checkWebBiometrics error: $e');
      return false;
    }
  }

  static Future<String?> linkWebBiometrics(String userName) async {
    try {
      final jsResult = js_util.callMethod(js_util.globalThis, 'linkWebBiometrics', [userName]);
      final val = await js_util.promiseToFuture<dynamic>(jsResult);
      debugPrint('[PwaInstaller] linkWebBiometrics raw: $val');
      if (val == null || val == false || val.toString() == 'false') return null;
      return val.toString();
    } catch (e) {
      debugPrint('[PwaInstaller] linkWebBiometrics error: $e');
      return null;
    }
  }

  static Future<bool> authenticateWebBiometrics({String? credId}) async {
    try {
      final jsResult = js_util.callMethod(js_util.globalThis, 'authenticateWebBiometrics', [credId ?? '']);
      final val = await js_util.promiseToFuture<dynamic>(jsResult);
      debugPrint('[PwaInstaller] authenticateWebBiometrics raw: $val');
      return val == true || val.toString() == 'true';
    } catch (e) {
      debugPrint('[PwaInstaller] authenticateWebBiometrics error: $e');
      return false;
    }
  }

  static Future<bool> installPWA() async {
    try {
      final jsResult = js_util.callMethod(js_util.globalThis, 'installPWA', []);
      final val = await js_util.promiseToFuture<dynamic>(jsResult);
      return val == true || val.toString() == 'true';
    } catch (e) {
      return false;
    }
  }
}
