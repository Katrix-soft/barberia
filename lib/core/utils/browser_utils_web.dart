import 'dart:js_interop';
import 'package:web/web.dart' as web;

class BrowserUtils {
  static Future<void> hardReload() async {
    try {
      // 1. Unregister Service Workers to clear PWA cache
      final sw = web.window.navigator.serviceWorker;
      final regs = await sw.getRegistrations().toDart;
      for (var reg in regs.toDart) {
        reg.active?.postMessage({'type': 'SKIP_WAITING'}.jsify());
        await reg.unregister().toDart;
      }

      // 2. Clear Caches
      await web.window.caches.delete('bm-barber-v1').toDart;

      // 3. Hard Reload using a timestamp to bypass server/browser cache
      final String currentBaseUrl =
          web.window.location.href.split('?').first;
      final String timestamp =
          DateTime.now().millisecondsSinceEpoch.toString();
      web.window.location.href = '$currentBaseUrl?v=$timestamp';
    } catch (e) {
      // Fallback to simple reload
      web.window.location.reload();
    }
  }
}
