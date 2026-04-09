import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'handlers/webhook_handler.dart';
import 'handlers/mp_handler.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  // Cargar variables de entorno desde el archivo .env en la raíz
  final env = DotEnv(includePlatformEnvironment: true)..load(['../.env']);
  final port = int.parse(env['PORT'] ?? '8090');
  final dbPath = env['DB_PATH'] ?? '/data/pos_barber.db';

  print('[Server] BM Barber Backend iniciando...');
  print('[Server] Puerto: $port');
  print('[Server] DB Path: $dbPath');

  final webhookHandler = WebhookHandler(dbPath: dbPath);
  final mpHandler = MpHandler(env);

  final router = Router();

  // Health check
  router.get('/health', (Request req) {
    return Response.ok('OK - BM Barber Backend v1.0\n');
  });

  // Mercado Pago webhook
  router.post('/webhook/mercadopago', webhookHandler.handle);

  // Mercado Pago proxy
  router.put('/mp/order', mpHandler.crearOrder);
  router.post('/mp/order', mpHandler.crearOrder);
  router.delete('/mp/order', mpHandler.cancelarOrder);
  router.get('/mp/order/status', mpHandler.obtenerEstado);
  router.get('/mp/qr-image', mpHandler.qrImage);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('[Server] Escuchando en http://${server.address.host}:${server.port}');

  // Mantiene el proceso vivo indefinidamente (evita que el main termine y Docker reinicie el contenedor)
  await ProcessSignal.sigint.watch().first;
}

/// Middleware CORS — Permite peticiones desde el frontend (Web)
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
