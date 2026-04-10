import 'dart:js_interop';

@JS('checkWebBiometrics')
external JSPromise<JSBoolean> _checkWebBiometrics();

@JS('linkWebBiometrics')
external JSPromise<JSString?> _linkWebBiometrics(JSString userName);

@JS('authenticateWebBiometrics')
external JSPromise<JSBoolean> _authenticateWebBiometrics(JSString? credId);

class PwaInstaller {
  static Future<bool> installPWA() async {
    return false; 
  }

  static Future<bool> checkWebBiometrics() async {
    try {
      final JSBoolean result = await _checkWebBiometrics().toDart;
      return result.toDart;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> linkWebBiometrics(String userName) async {
    try {
      final JSString? result = await _linkWebBiometrics(userName.toJS).toDart;
      return result?.toDart;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> authenticateWebBiometrics({String? credId}) async {
    try {
      final JSBoolean result = await _authenticateWebBiometrics(credId?.toJS).toDart;
      return result.toDart;
    } catch (e) {
      return false;
    }
  }
}
