import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

class MercadoPagoOAuthHandler {
  final String clientId;
  final String clientSecret;
  final String redirectUri;

  MercadoPagoOAuthHandler({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
  });

  Router get router {
    final router = Router();

    // Endpoint para recibir el código de autorización
    router.get('/oauth/callback', _handleCallback);

    // Endpoint para obtener la URL de autorización
    router.get('/oauth/authorize-url', _handleAuthorizeUrl);

    return router;
  }

  // Handler del callback de OAuth
  Future<Response> _handleCallback(Request request) async {
    try {
      // Obtener el código de la query string
      final code = request.url.queryParameters['code'];

      if (code == null) {
        return Response.badRequest(
          body: json.encode({
            'error': 'No se recibió el código de autorización',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      print('✅ Código OAuth recibido: $code');

      // Intercambiar el código por access_token
      final tokenData = await _exchangeCodeForToken(code);

      if (tokenData == null) {
        return Response.internalServerError(
          body: json.encode({'error': 'Error al obtener el token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      print('✅ Token OAuth obtenido:');
      print('   - access_token: ${tokenData['access_token']}');
      print('   - refresh_token: ${tokenData['refresh_token']}');
      print('   - user_id: ${tokenData['user_id']}');
      print('   - public_key: ${tokenData['public_key']}');

      // TODO: Guardar en base de datos
      // await _saveToDatabase(tokenData);

      // Retornar página de éxito
      return Response.ok(
        _successPage(tokenData),
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );
    } catch (e) {
      print('❌ Error en OAuth callback: $e');
      return Response.internalServerError(
        body: json.encode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Handler para devolver la URL de autorización
  Future<Response> _handleAuthorizeUrl(Request request) async {
    final authUrl = getAuthorizationUrl();
    return Response.ok(
      json.encode({'authorization_url': authUrl}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Intercambiar código por token
  Future<Map<String, dynamic>?> _exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.mercadopago.com/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_secret': clientSecret,
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print('❌ Error al obtener token: ${response.statusCode}');
        print('   Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al obtener token: $e');
      return null;
    }
  }

  // Página HTML de éxito
  String _successPage(Map<String, dynamic> tokenData) {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <title>¡Conexión Exitosa!</title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      font-family: Arial, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
    .card {
      background: white;
      padding: 40px;
      border-radius: 10px;
      box-shadow: 0 10px 40px rgba(0,0,0,0.2);
      text-align: center;
      max-width: 500px;
      width: 90%;
    }
    h1 { color: #667eea; margin-bottom: 20px; }
    .success-icon { font-size: 80px; margin-bottom: 20px; }
    .info {
      background: #f5f5f5;
      padding: 20px;
      border-radius: 5px;
      margin-top: 20px;
      text-align: left;
    }
    .info p {
      margin: 8px 0;
      font-family: monospace;
      font-size: 13px;
    }
    .close-btn {
      margin-top: 20px;
      padding: 10px 30px;
      background: #667eea;
      color: white;
      border: none;
      border-radius: 5px;
      cursor: pointer;
      font-size: 16px;
    }
    .close-btn:hover { background: #5a6fd8; }
  </style>
</head>
<body>
  <div class="card">
    <div class="success-icon">✅</div>
    <h1>¡MercadoPago Conectado!</h1>
    <p>La cuenta se conectó exitosamente.</p>
    <div class="info">
      <p><strong>User ID:</strong> ${tokenData['user_id']}</p>
      <p><strong>Public Key:</strong> ${tokenData['public_key'] ?? 'N/A'}</p>
      <p><strong>Token guardado:</strong> ✓</p>
    </div>
    <button class="close-btn" onclick="window.close()">Cerrar</button>
  </div>
</body>
</html>
    ''';
  }

  // Generar URL de autorización
  String getAuthorizationUrl() {
    final params = {
      'client_id': clientId,
      'response_type': 'code',
      'platform_id': 'mp',
      'redirect_uri': redirectUri,
    };

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return 'https://auth.mercadopago.com.ar/authorization?$queryString';
  }
}
