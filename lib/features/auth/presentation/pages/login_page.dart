import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../../../../core/utils/pwa_installer.dart';
import '../../../../core/utils/version_info.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  bool _isBiometricSupported = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _initAuth();
    _animationController.forward();
  }

  Future<void> _initAuth() async {
    await _loadSavedCredentials();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    
    try {
      bool shouldOfferBiometrics = false;

      if (kIsWeb) {
        // Reintentar hasta 3 veces con delay si falla inicialmente
        for (int i = 0; i < 3; i++) {
          shouldOfferBiometrics = await PwaInstaller.checkWebBiometrics();
          if (shouldOfferBiometrics) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } else {
        final isSupported = await auth.isDeviceSupported();
        final canCheckBiometrics = await auth.canCheckBiometrics;
        shouldOfferBiometrics = isSupported || canCheckBiometrics;
      }

      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final useBiometrics = prefs.getBool('use_biometrics') ?? false;

        setState(() {
          // Solo mostramos el botón si el dispositivo es compatible Y el usuario ya lo habilitó
          _isBiometricSupported = shouldOfferBiometrics && useBiometrics;
        });

        if (shouldOfferBiometrics && useBiometrics) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) _authenticateWithBiometrics();
          });
        }
      }
    } catch (e) {
      debugPrint('[Auth] Biometrics check error: $e');
    }
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    if (savedEmail != null && savedPassword != null) {
      if (mounted) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
        });
      }
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', _emailController.text.trim());
    await prefs.setString('saved_password', _passwordController.text);
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      if (kIsWeb) {
        // Restaurar credId desde SharedPreferences a localStorage si fue limpiado
        final prefs = await SharedPreferences.getInstance();
        final credId = prefs.getString('bio_cred_id');
        final authenticated = await PwaInstaller.authenticateWebBiometrics(credId: credId);
        if (authenticated) {
          _onBiometricAuthSuccess();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometría no disponible o denegada. Ingresá con tu contraseña.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          // Desactivar biometría si falla para que no moleste más
          await prefs.setBool('use_biometrics', false);
          setState(() => _isBiometricSupported = false);
        }
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Inicia sesión de forma segura con Face ID o Huella',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (authenticated) {
        _onBiometricAuthSuccess();
      }
    } on PlatformException catch (e) {
      debugPrint('[Auth] Biometric auth error: ${e.code}');
    }
  }

  Future<void> _onBiometricAuthSuccess() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      await _loadSavedCredentials();
    }

    if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      _submitLogin();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          } else if (state is Authenticated) {
            // El diálogo de activación se maneja ahora solo en PosPage para evitar duplicados.
          }
        },
        child: Stack(
          children: [
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC5A028).withOpacity(0.08),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFC5A028).withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFC5A028).withOpacity(0.1),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 120,
                              width: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => const Icon(
                                FontAwesomeIcons.scissors,
                                size: 60,
                                color: Color(0xFFC5A028),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'BM BARBER',
                          style: GoogleFonts.outfit(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFC5A028),
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFFC5A028).withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildBrandingField(
                                controller: _emailController,
                                label: 'Usuario o Email',
                                icon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 24),
                              _buildBrandingField(
                                controller: _passwordController,
                                label: 'Contraseña',
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              const SizedBox(height: 32),
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final isLoading = state is AuthLoading;
                                  return ElevatedButton(
                                    onPressed: isLoading ? null : _submitLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFC5A028),
                                      minimumSize: const Size(double.infinity, 58),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: isLoading
                                        ? const CircularProgressIndicator(color: Colors.black)
                                        : Text(
                                            'INICIAR SESIÓN',
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.black,
                                            ),
                                          ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        if (_isBiometricSupported) ...[
                          const SizedBox(height: 32),
                          InkWell(
                            onTap: _authenticateWithBiometrics,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFC5A028).withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(0xFFC5A028).withOpacity(0.05),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.fingerprint_rounded, color: Color(0xFFC5A028)),
                                  const SizedBox(width: 12),
                                  Text(
                                    'ACCESO BIOMÉTRICO',
                                    style: GoogleFonts.outfit(color: const Color(0xFFC5A028), fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 48),
                        Text(
                          'PREMIUM EDITION v${VersionInfo.appVersion}',
                          style: GoogleFonts.outfit(color: Colors.white12, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(color: const Color(0xFFC5A028), fontSize: 11, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF262626),
            prefixIcon: Icon(icon, color: Colors.white38),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white38),
                    onPressed: onSuffixTap,
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

}
