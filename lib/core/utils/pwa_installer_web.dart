import 'dart:js_util' as js_util;
import 'dart:js' as js;

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

  static Future<bool> authenticateWebBiometrics() async {
    try {
      if (!js.context.hasProperty('authenticateWebBiometrics')) {
        return false;
      }
      final dynamic result = js.context.callMethod('authenticateWebBiometrics');
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
