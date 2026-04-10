import 'dart:js_interop';

@JS('checkWebBiometrics')
external JSPromise<JSBool> _checkWebBiometrics();

@JS('linkWebBiometrics')
external JSPromise<JSString?> _linkWebBiometrics(JSString userName);

@JS('authenticateWebBiometrics')
external JSPromise<JSBool> _authenticateWebBiometrics(JSString? credId);

class PwaInstallerWeb {
  static Future<bool> checkWebBiometrics() async {
    try {
      final result = await _checkWebBiometrics().toDart;
      return result.toDart;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> linkWebBiometrics(String userName) async {
    try {
      final result = await _linkWebBiometrics(userName.toJS).toDart;
      return result?.toDart;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> authenticateWebBiometrics({String? credId}) async {
    try {
      final result = await _authenticateWebBiometrics(credId?.toJS).toDart;
      return result.toDart;
    } catch (e) {
      return false;
    }
  }
}
