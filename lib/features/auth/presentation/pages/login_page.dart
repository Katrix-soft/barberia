import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/database/database_helper.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
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
    _loadSavedCredentials();
    _checkBiometrics();
    _animationController.forward();
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
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', _emailController.text.trim());
    await prefs.setString('saved_password', _passwordController.text);
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      if (!_isBiometricSupported) return;

      final authenticated = await auth.authenticate(
        localizedReason: 'Inicia sesión de forma segura con biometría',
      );

      if (authenticated) {
        if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
          await _loadSavedCredentials();
        }

        if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
          _submitLogin();
        }
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: ${e.message}');
    }
  }

  void _submitLogin() {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
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
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC5A028).withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC5A028).withOpacity(0.03),
                ),
              ),
            ),
            
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFC5A028).withOpacity(0.1),
                                blurRadius: 40,
                                spreadRadius: 5,
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
                          'LUXURY POSBARBER',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFC5A028),
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'Excelencia en cada corte',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white70,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 48),

                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTextField(
                                controller: _emailController,
                                label: 'Usuario o Correo',
                                icon: Icons.person_outline,
                                isEmail: true,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Contraseña',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                onSuffixIconPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFC5A028),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  return _buildGoldButton(
                                    onPressed: state is AuthLoading ? null : _submitLogin,
                                    isLoading: state is AuthLoading,
                                    text: 'INICIAR SESIÓN',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        if (_isBiometricSupported) ...[
                          const SizedBox(height: 24),
                          _buildBiometricButton(),
                        ],
                        
                        const SizedBox(height: 40),
                        Text(
                          'v0.1.0 Premium Edition',
                          style: GoogleFonts.outfit(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
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

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC5A028).withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isEmail = false,
    bool obscureText = false,
    VoidCallback? onSuffixIconPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: const Color(0xFFC5A028),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF262626),
            prefixIcon: Icon(icon, color: Colors.white38, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: onSuffixIconPressed,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC5A028), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoldButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String text,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFC5A028), Color(0xFFB8860B)],
              ),
        color: onPressed == null ? Colors.grey[800] : null,
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: const Color(0xFFC5A028).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                text,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return InkWell(
      onTap: _authenticateWithBiometrics,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFC5A028).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fingerprint, color: Color(0xFFC5A028), size: 24),
            const SizedBox(width: 12),
            Text(
              'BIOMETRÍA RÁPIDA',
              style: GoogleFonts.outfit(
                color: const Color(0xFFC5A028),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFFC5A028).withOpacity(0.2)),
        ),
        title: Text(
          'RECUPERAR ACCESO',
          style: GoogleFonts.outfit(color: const Color(0xFFC5A028), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa tu usuario o correo para recibir tus credenciales vía email.',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Usuario o Correo',
                labelStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF262626),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFC5A028))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC5A028),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (emailCtrl.text.isEmpty) return;
              final userMap = await DatabaseHelper().getUserByEmailOrUsername(emailCtrl.text.trim());
              if (userMap != null) {
                final pwd = userMap['password'];
                final email = userMap['email'];
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: email,
                  queryParameters: {
                    'subject': '🔑 Recuperación de Credenciales - Posbarber',
                    'body': 'Hola ${userMap['name']},\n\nHas solicitado recuperar tus credenciales para Posbarber.\n\nUsuario: ${userMap['username']}\nContraseña: $pwd\n\nPor favor, inicia sesión y cambia tu contraseña por seguridad.\n\nSaludos,\nEquipo Posbarber.',
                  },
                );
                try {
                  await launchUrl(emailLaunchUri);
                } catch (e) {
                  debugPrint('Could not launch email');
                }
              }
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Se ha preparado el correo de recuperación'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('ENVIAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
