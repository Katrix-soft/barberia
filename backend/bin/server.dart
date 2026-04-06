import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'handlers/webhook_handler.dart';

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8090');
  final dbPath = Platform.environment['DB_PATH'] ?? '/data/pos_barber.db';

  print('[Server] BM Barber Backend iniciando...');
  print('[Server] Puerto: $port');
  print('[Server] DB Path: $dbPath');

  final webhookHandler = WebhookHandler(dbPath: dbPath);

  final router = Router();

  // Health check
  router.get('/health', (Request req) {
    return Response.ok('OK - BM Barber Backend v1.0\n');
  });

  // Mercado Pago webhook
  router.post('/webhook/mercadopago', webhookHandler.handle);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('[Server] Escuchando en http://${server.address.host}:${server.port}');
}

/// Middleware CORS básico — Mercado Pago no necesita CORS pero es buena práctica.
Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
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
