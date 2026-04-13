import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'handlers/webhook_handler.dart';
import 'handlers/mp_handler.dart';
import 'handlers/mercadopago_oauth_handler.dart';
import 'middleware/rate_limiter.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load(['../.env']);
  final port = int.parse(env['PORT'] ?? '8090');
  final dbPath = env['DB_PATH'] ?? '/data/pos_barber.db';

  print('[Server] BM Barber Backend iniciando...');
  print('[Server] Puerto: $port');
  print('[Server] DB Path: $dbPath');

  final webhookHandler = WebhookHandler(dbPath: dbPath);
  final mpHandler = MpHandler(env);

  // Configurar OAuth handler para MercadoPago Connect
  final oauthHandler = MercadoPagoOAuthHandler(
    clientId: env['MP_CLIENT_ID'] ?? '4551113108292732',
    clientSecret: env['MP_CLIENT_SECRET'] ?? '',
    redirectUri: env['MP_REDIRECT_URI'] ?? 'https://barber.katrix.com.ar/oauth/callback',
  );

  print('[OAuth] URL de autorización:');
  print('   ${oauthHandler.getAuthorizationUrl()}');

  final router = Router();

  router.get('/health', (Request req) {
    return Response.ok('OK - BM Barber Backend v1.0\n');
  });

  // Webhook MP — máximo 10 por minuto por IP
  router.post('/webhook/mercadopago',
    Pipeline().addMiddleware(rateLimiter(maxRequests: 10, windowSeconds: 60))
      .addHandler(webhookHandler.handle));

  // MP proxy — máximo 30 por minuto por IP
  final mpRateLimited = Pipeline()
      .addMiddleware(rateLimiter(maxRequests: 30, windowSeconds: 60));

  router.put('/mp/order',
    mpRateLimited.addHandler(mpHandler.crearOrder));
  router.delete('/mp/order',
    mpRateLimited.addHandler(mpHandler.cancelarOrder));
  router.get('/mp/order/status',
    mpRateLimited.addHandler(mpHandler.obtenerEstado));
  router.get('/mp/qr-image',
    mpRateLimited.addHandler(mpHandler.qrImage));

  // OAuth routes — MercadoPago Connect
  router.mount('/', oauthHandler.router);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('[Server] Escuchando en http://${server.address.host}:${server.port}');

  await ProcessSignal.sigint.watch().first;
}

Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, GET, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        });
      }
      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        ...response.headers,
      });
    };
  };
}
