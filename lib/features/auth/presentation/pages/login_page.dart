import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/database/database_helper.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  bool _isBiometricSupported = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final isSupported = await auth.isDeviceSupported();
      final canCheckBiometrics = await auth.canCheckBiometrics;
      final prefs = await SharedPreferences.getInstance();
      final useBiometrics = prefs.getBool('use_biometrics') ?? false;

      final supportedAndEnabled =
          (isSupported || canCheckBiometrics) && useBiometrics;

      if (mounted) {
        setState(() {
          _isBiometricSupported = supportedAndEnabled;
        });

        if (supportedAndEnabled) {
          // Prevenir múltiples llamadas si el widget se reconstruye rápidamente
          Future.microtask(() => _authenticateWithBiometrics());
        }
      }
    } catch (e) {
      debugPrint('Biometrics error: $e');
    }
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    if (savedEmail != null && savedPassword != null) {
      _emailController.text = savedEmail;
      _passwordController.text = savedPassword;
    } else {
      _emailController.text = 'admin@barberia.com';
      _passwordController.text = 'admin';
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', _emailController.text.trim());
    await prefs.setString('saved_password', _passwordController.text);
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      if (!_isBiometricSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autenticación biométrica no disponible'),
          ),
        );
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Posbarber pide la autorización',
      );

      if (authenticated) {
        if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
          // Si no hay datos en los controladores, intentamos cargar de prefs
          await _loadSavedCredentials();
        }

        if (_emailController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty) {
          _submitLogin();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Por favor, ingresa tus credenciales manualmente la primera vez.',
                ),
              ),
            );
          }
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de autenticación: ${e.message}')),
        );
      }
    }
  }

  void _submitLogin() {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }
    _saveCredentials();
    context.read<AuthBloc>().add(
      LoginSubmitted(_emailController.text.trim(), _passwordController.text),
    );
  }

  Future<void> _enableBiometricsIfSupported() async {
    try {
      final isSupported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      if (isSupported || canCheck) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('use_biometrics', true);
        debugPrint('Biometrics auto-enabled after successful login');
      }
    } catch (e) {
      debugPrint('Error enabling biometrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            // Si el login es exitoso, marcamos que puede usar biometría si es soportada
            _enableBiometricsIfSupported();
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.05),
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC5A028).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFC5A028).withOpacity(0.2),
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 160,
                          width: 160,
                          fit: BoxFit.cover,
                          cacheWidth: 350,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.content_cut_rounded,
                                size: 80,
                                color: Color(0xFFC5A028),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Posbarber',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: const Color(0xFFC5A028),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bienvenido de nuevo. Ingresa para continuar.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 48),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Usuario o Correo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(color: Color(0xFFC5A028)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return ElevatedButton(
                          onPressed: state is AuthLoading ? null : _submitLogin,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFFC5A028),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: state is AuthLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Iniciar Sesión',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        );
                      },
                    ),
                    if (_isBiometricSupported) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _authenticateWithBiometrics,
                        icon: const Icon(
                          Icons.fingerprint,
                          size: 28,
                          color: Color(0xFFC5A028),
                        ),
                        label: const Text(
                          'Ingresar con Face ID / Huella',
                          style: TextStyle(
                            color: Color(0xFFC5A028),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu usuario o correo para recibir tus credenciales vía email.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Usuario o Correo',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC5A028),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (emailCtrl.text.isEmpty) return;
              final userMap = await DatabaseHelper().getUserByEmailOrUsername(
                emailCtrl.text.trim(),
              );
              if (userMap != null) {
                final pwd = userMap['password'];
                final email = userMap['email'];
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: email,
                  queryParameters: {
                    'subject': 'Recuperación de contraseña - Barber POS',
                    'body':
                        'Hola,\n\nHas solicitado recuperar tu contraseña.\nUsuario: ${userMap['username']}\nContraseña: $pwd\n\nSaludos.',
                  },
                );
                try {
                  await launchUrl(emailLaunchUri);
                } catch (e) {
                  // ignorar si no hay cliente
                }
              }
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Si el usuario existe en el sistema, se preparará el correo electrónico.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Recuperar'),
          ),
        ],
      ),
    );
  }
}
