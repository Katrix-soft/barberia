import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:katrix_biometrics/katrix_biometrics.dart';
import '../../../../core/utils/version_info.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

// Silencia el aviso de dart:math no usado
// ignore: unused_import
export 'dart:math' show pi;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // Controllers
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Animation controllers
  late AnimationController _fadeCtrl, _pulseCtrl, _orb1Ctrl, _orb2Ctrl, _shakeCtrl;
  late Animation<double> _fadeAnim, _pulseAnim, _orb1Anim, _orb2Anim, _shakeAnim;

  // State
  bool _obscurePass = true;
  bool _isAvailable = false;
  bool _isEnabled = false;
  bool _bioMode = false;
  bool _bioLoading = false;
  bool _checkDone = false;

  static const _gold = Color(0xFFC5A028);
  static const _bg = Color(0xFF080808);
  static const _surface = Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initAuth();
  }

  void _setupAnimations() {
    _fadeCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _orb1Ctrl   = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _orb2Ctrl   = AnimationController(vsync: this, duration: const Duration(seconds: 11))..repeat(reverse: true);
    _shakeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween(begin: 0.88, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _orb1Anim  = CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut);
    _orb2Anim  = CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut);
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    _fadeCtrl.forward();
  }

  Future<void> _initAuth() async {
    await _loadSavedUser();
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) await _checkBiometrics();
  }

  Future<void> _loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email') ?? '';
    if (email.isNotEmpty && mounted) {
      setState(() => _userCtrl.text = email);
    }
  }

  Future<void> _checkBiometrics() async {
    if (_checkDone) return;
    _checkDone = true;
    try {
      final avail = await KatrixBiometrics.isAvailable;
      final enabled = await KatrixBiometrics.isEnabled;
      if (!mounted) return;
      setState(() {
        _isAvailable = avail;
        _isEnabled = enabled;
        _bioMode = avail && enabled;
      });
      if (_bioMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _triggerBio();
      } else if (avail && !enabled) {
        _showEnablePrompt();
      }
    } catch (e) {
      debugPrint('[KatrixBio] check error: $e');
    }
  }

  // ── Biometrics ─────────────────────────────────────────────────────────────

  Future<void> _triggerBio() async {
    if (_bioLoading) return;
    setState(() => _bioLoading = true);
    if (!kIsWeb) HapticFeedback.lightImpact();

    final result = await KatrixBiometrics.authenticate(
      reason: 'Accedé a BM Barber con tu biometría',
    );
    if (!mounted) return;
    setState(() => _bioLoading = false);

    switch (result) {
      case BiometricSuccess():
        if (!kIsWeb) HapticFeedback.heavyImpact();
        await _loginWithSaved();
      case BiometricFailed(reason: final r):
        debugPrint('[KatrixBio] failed: $r');
        _shakeCtrl.forward(from: 0);
        if (!kIsWeb) HapticFeedback.vibrate();
        _snack('Biometría fallida. Intentá de nuevo.', error: true);
      case BiometricUnavailable(reason: final r):
        debugPrint('[KatrixBio] unavail: $r');
        setState(() { _bioMode = false; _isAvailable = false; });
      case BiometricEnrolled():
        break;
    }
  }

  Future<void> _loginWithSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email') ?? '';
    final pass  = prefs.getString('saved_password') ?? '';
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _bioMode = false);
      return;
    }
    if (mounted) context.read<AuthBloc>().add(LoginSubmitted(email.trim(), pass));
  }

  void _submitManual() {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    _saveCredentials();
    context.read<AuthBloc>().add(LoginSubmitted(_userCtrl.text.trim(), _passCtrl.text));
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', _userCtrl.text.trim());
    await prefs.setString('saved_password', _passCtrl.text);
  }

  void _showEnablePrompt() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => _EnableBioDialog(
          onEnable: _enrollBio,
          onDecline: () => Navigator.pop(context),
        ),
      );
    });
  }

  Future<void> _enrollBio() async {
    Navigator.pop(context);
    final userId = _userCtrl.text.trim().isNotEmpty ? _userCtrl.text.trim() : 'usuario';
    final result = await KatrixBiometrics.enroll(userId: userId);
    if (!mounted) return;
    switch (result) {
      case BiometricSuccess() || BiometricEnrolled():
        setState(() { _isEnabled = true; _bioMode = true; });
        _snack('✓ Biometría activada', error: false);
      case BiometricFailed(reason: final r):
        _snack('No se pudo activar: $r', error: true);
      case BiometricUnavailable():
        break;
    }
  }

  void _snack(String msg, {required bool error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      backgroundColor: error ? Colors.redAccent.shade700 : const Color(0xFF1B9948),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  void dispose() {
    for (final c in [_fadeCtrl, _pulseCtrl, _orb1Ctrl, _orb2Ctrl, _shakeCtrl]) {
      c.dispose();
    }
    _userCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (_, state) {
          if (state is AuthError) _snack(state.message, error: true);
          if (state is Authenticated) setState(() => _checkDone = true);
        },
        child: Stack(children: [
          // Orbes de fondo animados
          _Orb(anim: _orb1Anim, top: -140, left: -90, size: 400, color: _gold),
          _Orb(anim: _orb2Anim, top: 340, right: -100, size: 300, color: const Color(0xFF7A5A10)),
          // Contenido
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Logo(pulse: _pulseAnim),
                        const SizedBox(height: 52),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 480),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
                              child: child,
                            ),
                          ),
                          child: _bioMode ? _buildBioPanel() : _buildFormPanel(),
                        ),
                        const SizedBox(height: 44),
                        Text(
                          'KATRIX POS v${VersionInfo.appVersion}',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.1),
                            fontSize: 9, letterSpacing: 2.5, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Bio panel ──────────────────────────────────────────────────────────────

  Widget _buildBioPanel() {
    return Column(
      key: const ValueKey('bio'),
      children: [
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child!),
          child: GestureDetector(
            onTap: _triggerBio,
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _gold.withValues(alpha: 0.2),
                    _gold.withValues(alpha: 0.03),
                  ]),
                  border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 50, spreadRadius: 2),
                    BoxShadow(color: _gold.withValues(alpha: 0.12), blurRadius: 90, spreadRadius: 10),
                  ],
                ),
                child: _bioLoading
                    ? const Padding(
                        padding: EdgeInsets.all(44),
                        child: CircularProgressIndicator(color: _gold, strokeWidth: 2.5),
                      )
                    : const Icon(Icons.fingerprint_rounded, size: 80, color: _gold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'TOCA PARA ACCEDER',
          style: GoogleFonts.outfit(color: _gold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        const SizedBox(height: 6),
        Text(
          'Huella digital · Face ID · Passkey',
          style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.38), fontSize: 12),
        ),
        const SizedBox(height: 36),
        TextButton.icon(
          onPressed: () => setState(() => _bioMode = false),
          icon: const Icon(Icons.lock_open_rounded, size: 15, color: Colors.white24),
          label: Text('Ingresar con contraseña', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
        ),
      ],
    );
  }

  // ── Form panel ─────────────────────────────────────────────────────────────

  Widget _buildFormPanel() {
    return Column(
      key: const ValueKey('form'),
      children: [
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child!),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _gold.withValues(alpha: 0.14), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 50, offset: const Offset(0, 20)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Field(ctrl: _userCtrl, label: 'USUARIO', icon: Icons.person_outline_rounded),
                const SizedBox(height: 18),
                _PasswordField(
                  ctrl: _passCtrl,
                  obscure: _obscurePass,
                  onToggle: () => setState(() => _obscurePass = !_obscurePass),
                  onSubmit: _submitManual,
                ),
                const SizedBox(height: 28),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (_, state) {
                    final loading = state is AuthLoading;
                    return _LoginButton(loading: loading, onTap: loading ? null : _submitManual);
                  },
                ),
              ],
            ),
          ),
        ),
        if (_isAvailable) ...[
          const SizedBox(height: 22),
          _BioToggleButton(enabled: _isEnabled, onTap: _isEnabled
              ? () => setState(() => _bioMode = true)
              : _showEnablePrompt),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sub-widgets reutilizables
// ────────────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final Animation<double> pulse;
  const _Logo({required this.pulse});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC5A028);
    return Column(children: [
      ScaleTransition(
        scale: pulse,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: const Color(0xFF111111),
            border: Border.all(color: gold.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(color: gold.withValues(alpha: 0.2), blurRadius: 70, spreadRadius: 10),
              BoxShadow(color: gold.withValues(alpha: 0.06), blurRadius: 130, spreadRadius: 25),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              height: 96, width: 96, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.content_cut_rounded, size: 46, color: gold),
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      Text('BM BARBER', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: gold, letterSpacing: 5)),
      const SizedBox(height: 4),
      Text('SISTEMA DE GESTIÓN', style: GoogleFonts.outfit(fontSize: 10, color: Colors.white.withValues(alpha: 0.3), letterSpacing: 4, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _Orb extends StatelessWidget {
  final Animation<double> anim;
  final Color color;
  final double? top, left, right;
  final double size;
  const _Orb({required this.anim, required this.color, required this.size, this.top, this.left, this.right});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Positioned(
        top: top != null ? top! + anim.value * 45 : null,
        left: left, right: right,
        child: IgnorePointer(
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                color.withValues(alpha: 0.14 + anim.value * 0.07),
                color.withValues(alpha: 0.0),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  const _Field({required this.ctrl, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC5A028);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.outfit(color: gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          filled: true, fillColor: const Color(0xFF1A1A1A),
          prefixIcon: Icon(icon, color: Colors.white30, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: gold, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    ]);
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool obscure;
  final VoidCallback onToggle;
  final VoidCallback onSubmit;
  const _PasswordField({required this.ctrl, required this.obscure, required this.onToggle, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC5A028);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CONTRASEÑA', style: GoogleFonts.outfit(color: gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        onSubmitted: (_) => onSubmit(),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          filled: true, fillColor: const Color(0xFF1A1A1A),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white30, size: 20),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white30, size: 20),
            onPressed: onToggle,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: gold, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    ]);
  }
}

class _LoginButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _LoginButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC5A028);
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: gold, foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
          : Text('INICIAR SESIÓN', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }
}

class _BioToggleButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _BioToggleButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC5A028);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.fingerprint_rounded, color: gold, size: 20),
      label: Text(
        enabled ? 'Usar biometría' : 'Activar acceso biométrico',
        style: GoogleFonts.outfit(color: gold, fontWeight: FontWeight.w700, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: gold, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    );
  }
}

class _EnableBioDialog extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onDecline;
  const _EnableBioDialog({required this.onEnable, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC5A028);
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.fingerprint_rounded, color: gold, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text('Acceso rápido', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
      ]),
      content: Text(
        '¿Querés usar tu huella o Face ID para entrar automáticamente la próxima vez?',
        style: GoogleFonts.outfit(color: Colors.white60, height: 1.6, fontSize: 14),
      ),
      actions: [
        TextButton(onPressed: onDecline, child: Text('Ahora no', style: GoogleFonts.outfit(color: Colors.white38))),
        ElevatedButton(
          onPressed: onEnable,
          style: ElevatedButton.styleFrom(
            backgroundColor: gold, foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text('Sí, activar', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
