import 'dart:js_util' as js_util;
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show debugPrint;

class PwaInstaller {
  static Future<bool> installPWA() async {
    try {
      if (!js.context.hasProperty('installPWA')) {
        return false;
      }
      final dynamic result = js.context.callMethod('installPWA');
      if (result != null && js_util.hasProperty(result, 'then')) {
        final future = js_util.promiseToFuture(result);
        final finalResult = await future;
        return finalResult == true;
      }
      return result == true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> linkWebBiometrics(String userName) async {
    try {
      if (!js.context.hasProperty('linkWebBiometrics')) return null;
      final dynamic result = js.context.callMethod('linkWebBiometrics', [userName]);
      if (result != null && js_util.hasProperty(result, 'then')) {
        final val = await js_util.promiseToFuture(result);
        if (val == null || val == false) return null;
        return val.toString();
      }
      if (result == null || result == false) return null;
      return result.toString();
    } catch (e) {
      debugPrint('[PWA] Error linking: $e');
      return null;
    }
  }

  static Future<bool> authenticateWebBiometrics(String? credId) async {
    try {
      if (!js.context.hasProperty('authenticateWebBiometrics')) return false;
      final dynamic result = js.context.callMethod('authenticateWebBiometrics', [credId ?? '']);
      if (result != null && js_util.hasProperty(result, 'then')) {
        final val = await js_util.promiseToFuture(result);
        return val == true;
      }
      return result == true;
    } catch (e) {
      debugPrint('[PWA] Error auth: $e');
      return false;
    }
  }

  static Future<bool> checkWebBiometrics() async {
    try {
      if (!js.context.hasProperty('checkWebBiometrics')) {
        return false;
      }
      final dynamic result = js.context.callMethod('checkWebBiometrics');
      if (result != null && js_util.hasProperty(result, 'then')) {
        final future = js_util.promiseToFuture(result);
        final finalResult = await future;
        return finalResult == true;
      }
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
