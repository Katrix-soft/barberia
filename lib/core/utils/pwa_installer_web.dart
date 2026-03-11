import 'dart:js' as js;

class PwaInstaller {
  static Future<bool> installPWA() async {
    try {
      final dynamic result = js.context.callMethod('installPWA');
      if (result is Future) {
        return (await result) == true;
      }
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
