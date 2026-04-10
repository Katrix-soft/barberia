import 'dart:collection';
import 'package:shelf/shelf.dart';

class _RateLimitEntry {
  int count;
  DateTime windowStart;
  _RateLimitEntry() : count = 0, windowStart = DateTime.now();
}

/// Rate limiter por IP. windowSeconds = duración de la ventana, maxRequests = máximo permitido.
Middleware rateLimiter({int maxRequests = 30, int windowSeconds = 60}) {
  final _store = HashMap<String, _RateLimitEntry>();

  return (Handler innerHandler) {
    return (Request request) async {
      // Extraer IP — Caddy pone la IP real en X-Forwarded-For
      final ip = request.headers['x-forwarded-for']?.split(',').first.trim()
          ?? request.headers['x-real-ip']
          ?? 'unknown';

      final now = DateTime.now();
      final entry = _store.putIfAbsent(ip, () => _RateLimitEntry());

      // Resetear ventana si expiró
      if (now.difference(entry.windowStart).inSeconds >= windowSeconds) {
        entry.count = 0;
        entry.windowStart = now;
      }

      entry.count++;

      if (entry.count > maxRequests) {
        print('[RateLimit] ❌ IP $ip bloqueada (${entry.count} reqs en ${windowSeconds}s)');
        return Response(
          429,
          body: 'Too Many Requests\n',
          headers: {
            'Content-Type': 'text/plain',
            'Retry-After': '$windowSeconds',
          },
        );
      }

      return innerHandler(request);
    };
  };
}
