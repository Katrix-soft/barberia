import 'dart:html' as html;

class BrowserUtils {
  static Future<void> hardReload() async {
    try {
      // 1. Unregister Service Workers to clear PWA cache
      final regs = await html.window.navigator.serviceWorker?.getRegistrations();
      if (regs != null) {
        for (var reg in regs) {
          // Send skip waiting message
          reg.active?.postMessage({'type': 'SKIP_WAITING'});
          await reg.unregister();
        }
      }
      
      // 2. Clear Caches
      await html.window.caches?.delete('bm-barber-v1');
      
      // 3. Hard Reload using a timestamp to bypass server/browser cache
      final String currentBaseUrl = html.window.location.href.split('?')[0];
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      html.window.location.href = '$currentBaseUrl?v=$timestamp';
    } catch (e) {
      // Fallback to simple reload
      html.window.location.reload();
    }
  }
}
