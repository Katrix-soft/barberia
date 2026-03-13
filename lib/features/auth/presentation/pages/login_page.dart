import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/services/email_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/browser_utils.dart';
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

    // Sequence our initialization for stability
    _initAuth();
    _animationController.forward();
  }

  Future<void> _initAuth() async {
    // 1. Load credentials first
    await _loadSavedCredentials();
    // 2. Then check and trigger biometrics with a small delay for UI to settle
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final isSupported = await auth.isDeviceSupported();
      final canCheckBiometrics = await auth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics =
          await auth.getAvailableBiometrics();

      final prefs = await SharedPreferences.getInstance();
      final useBiometrics = prefs.getBool('use_biometrics') ?? false;
      final hasSavedCreds = prefs.getString('saved_email') != null &&
          prefs.getString('saved_password') != null;

      // IMPROVEMENT: Relaxed check. If the device IS SUPPORTED, we show the option.
      // This allows the user to click it and let the system guide them to enroll if not already done,
      // or gives us a chance to show a specific error why it's not working yet.
      final shouldOfferBiometrics = isSupported || canCheckBiometrics || availableBiometrics.isNotEmpty;

      debugPrint('[Auth] Biometrics check: supported=$isSupported, canCheck=$canCheckBiometrics, enrolled=${availableBiometrics.isNotEmpty}');

      if (mounted) {
        setState(() {
          _isBiometricSupported = shouldOfferBiometrics;
        });

        // Auto-trigger ONLY if explicitly enabled by the user previously
        if (shouldOfferBiometrics && useBiometrics && hasSavedCreds && availableBiometrics.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _authenticateWithBiometrics();
          });
        }
      }
    } catch (e) {
      debugPrint('[Auth] Biometrics stability check error: $e');
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
      // Re-verify enrollment before attempting to avoid generic "Not Available" errors where possible
      final List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();
      
      if (availableBiometrics.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay biometría configurada en este dispositivo. Por favor, configura FaceID o Huella en los ajustes de tu teléfono.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Inicia sesión de forma segura con Face ID o Huella',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN as fallback if biometrics fail
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
          await _loadSavedCredentials();
        }

        if (_emailController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty) {
          _submitLogin();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometría exitosa, pero no hay credenciales guardadas. Inicia sesión manualmente una vez.'),
                backgroundColor: Colors.blue,
              ),
            );
          }
        }
      }
    } on PlatformException catch (e) {
      debugPrint('[Auth] Biometric auth error: ${e.code} - ${e.message}');
      String errorMessage = 'Error de biometría: ${e.message}';
      
      if (e.code == 'NotAvailable') {
        errorMessage = 'Tu dispositivo no tiene biometría configurada o no es compatible.';
      } else if (e.code == 'LockedOut') {
        errorMessage = 'Biometría bloqueada temporalmente por demasiados intentos.';
      } else if (e.code == 'PermanentlyLockedOut') {
        errorMessage = 'Biometría bloqueada. Usa tu PIN o contraseña del teléfono para desbloquearla.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
          ),
        );
      }
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
      backgroundColor: const Color(0xFF0A0A0A), // Deep Black
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is Authenticated) {
            final prefs = await SharedPreferences.getInstance();
            final hasAsked = prefs.getBool('use_biometrics_asked') ?? false;
            
            if (!hasAsked && _isBiometricSupported) {
               // If it's the first time and biometrics are possible, ask them
               if (mounted) _showEnableBiometricDialog(context);
            }
          }
        },
        child: Stack(
          children: [
            // Ambient Glows
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
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC5A028).withOpacity(0.05),
                ),
              ),
            ),

            // Main Content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo Container with elevation
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFC5A028).withOpacity(0.2),
                            ),
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
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'LA EXCELENCIA ES NUESTRO ESTÁNDAR',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white54,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // Form Card
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFFC5A028).withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildBrandingField(
                                controller: _emailController,
                                label: 'Usuario o Email',
                                icon: Icons.person_outline_rounded,
                                isEmail: true,
                              ),
                              const SizedBox(height: 24),
                              _buildBrandingField(
                                controller: _passwordController,
                                label: 'Contraseña',
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                onSuffixTap: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: GoogleFonts.outfit(
                                      color: const Color(
                                        0xFFC5A028,
                                      ).withOpacity(0.8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final isLoading = state is AuthLoading;
                                  return Container(
                                    height: 58,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: isLoading
                                            ? [
                                                Colors.grey[800]!,
                                                Colors.grey[900]!,
                                              ]
                                            : [
                                                const Color(0xFFD4AF37),
                                                const Color(0xFFC5A028),
                                                const Color(0xFFB8860B),
                                              ],
                                      ),
                                      boxShadow: [
                                        if (!isLoading)
                                          BoxShadow(
                                            color: const Color(
                                              0xFFC5A028,
                                            ).withOpacity(0.4),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: isLoading
                                          ? null
                                          : _submitLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        minimumSize: const Size(
                                          double.infinity,
                                          58,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.black,
                                                strokeWidth: 3,
                                              ),
                                            )
                                          : Text(
                                              'INICIAR SESIÓN',
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.5,
                                                color: Colors.black,
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Biometric Section
                        if (_isBiometricSupported) ...[
                          const SizedBox(height: 32),
                          InkWell(
                            onTap: _authenticateWithBiometrics,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(
                                    0xFFC5A028,
                                  ).withOpacity(0.3),
                                ),
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(
                                  0xFFC5A028,
                                ).withOpacity(0.05),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.fingerprint_rounded,
                                    color: Color(0xFFC5A028),
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'ACCESO BIOMÉTRICO',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFC5A028),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 60),
                        Column(
                          children: [
                            Text(
                              'PREMIUM EDITION v${VersionInfo.appVersion}',
                              style: GoogleFonts.outfit(
                                color: Colors.white12,
                                fontSize: 11,
                                letterSpacing: 3,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // NUCLEAR RESET (Subtle diagnostic tool)
                            TextButton(
                              onPressed: () => _confirmNuclearReset(context),
                              child: Text(
                                '¿PROBLEMAS? RESETEAR APP',
                                style: TextStyle(
                                  color: Colors.red.withOpacity(0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
    bool isEmail = false,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              color: const Color(0xFFC5A028),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF262626),
            prefixIcon: Icon(icon, color: Colors.white38, size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white38,
                    ),
                    onPressed: onSuffixTap,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 20,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFC5A028), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: Color(0xFFC5A028), width: 0.5),
        ),
        title: Text(
          'RECUPERAR ACCESO',
          style: GoogleFonts.outfit(
            color: const Color(0xFFC5A028),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa tus datos para recibir un correo de recuperación instantáneo.',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email o Usuario',
                labelStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF262626),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFC5A028)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC5A028),
              minimumSize: const Size(100, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final identifier = emailCtrl.text.trim();
              if (identifier.isEmpty) return;

              // 1. Check if user exists
              final userMap = await DatabaseHelper().getUserByEmailOrUsername(identifier);

              if (userMap != null) {
                final String userEmail = userMap['email'];
                final String userName = userMap['name'];
                final int userId = userMap['id'];

                // 2. Generate OTP
                final String otp = (100000 + (DateTime.now().millisecond * 899)).toString().substring(0, 6);
                
                if (context.mounted) Navigator.pop(context); // Close first dialog

                // 3. Send Email (SMTP)
                final emailSent = await EmailService.sendOTP(
                  toEmail: userEmail,
                  toName: userName,
                  otpCode: otp,
                );

                if (!emailSent) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al enviar el correo. Verifica tu conexión o configuración SMTP.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                // 4. Show OTP Verification Dialog
                if (context.mounted) {
                  _showOtpVerificationDialog(userId, otp, userName);
                }

              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Usuario o correo no encontrado.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'ENVIAR',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOtpVerificationDialog(int userId, String correctOtp, String userName) {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Text('VERIFICACIÓN', style: GoogleFonts.outfit(color: const Color(0xFFC5A028), fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Se ha enviado un código a tu correo. Ingresalo para continuar.', style: GoogleFonts.outfit(color: Colors.white70)),
            const SizedBox(height: 24),
            TextField(
              controller: otpCtrl,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: const Color(0xFF262626),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A028)),
            onPressed: () {
              if (otpCtrl.text == correctOtp) {
                Navigator.pop(context);
                _showNewPasswordDialog(userId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código incorrecto'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('VERIFICAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNewPasswordDialog(int userId) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Text('NUEVA CONTRASEÑA', style: GoogleFonts.outfit(color: const Color(0xFFC5A028), fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Establece tu nueva contraseña de acceso.', style: GoogleFonts.outfit(color: Colors.white70)),
            const SizedBox(height: 24),
            TextField(
              controller: passCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nueva Contraseña',
                labelStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF262626),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A028)),
            onPressed: () async {
              if (passCtrl.text.isEmpty) return;
              
              final db = await DatabaseHelper().database;
              await db.update(
                'users',
                {'password': passCtrl.text},
                where: 'id = ?',
                whereArgs: [userId],
              );

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contraseña actualizada con éxito'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('GUARDAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  void _showEnableBiometricDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: Color(0xFFC5A028), width: 0.5),
        ),
        title: Text(
          '¿ACTIVAR ACCESO RÁPIDO?',
          style: GoogleFonts.outfit(
            color: const Color(0xFFC5A028),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          '¿Te gustaría usar Face ID o Huella para entrar directamente la próxima vez?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('use_biometrics_asked', true);
              await prefs.setBool('use_biometrics', false);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('AHORA NO', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC5A028),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('use_biometrics_asked', true);
              await prefs.setBool('use_biometrics', true);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Acceso biométrico activado para la próxima vez'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'SÍ, ACTIVAR',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmNuclearReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('RESETEO NUCLEAR', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Esto borrará TODA la base de datos local y cerrará todas las sesiones. ¿Estás seguro?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper().resetDatabase();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sistema reseteado. Reiniciando...')),
                );
                Future.delayed(const Duration(seconds: 1), () {
                  if (kIsWeb) {
                    BrowserUtils.hardReload();
                  }
                });
              }
            },
            child: const Text('BORRAR TODO', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
