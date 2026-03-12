import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_event.dart';
import '../../../../core/theme/bloc/theme_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _useBiometrics = false;
  bool _isBiometricSupported = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometricSupport();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useBiometrics = prefs.getBool('use_biometrics') ?? false;
    });
  }

  Future<void> _checkBiometricSupport() async {
    final isSupported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    setState(() {
      _isBiometricSupported = isSupported || canCheck;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      try {
        final authenticated = await _auth.authenticate(
          localizedReason:
              'Confirma tu identidad para activar el acceso biométrico',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        if (authenticated) {
          await prefs.setBool('use_biometrics', true);
          setState(() => _useBiometrics = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Acceso biométrico activado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } on PlatformException catch (e) {
        debugPrint('Error activating biometrics: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al activar biometría: ${e.message}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      await prefs.setBool('use_biometrics', false);
      setState(() => _useBiometrics = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGold = const Color(0xFFC5A028);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryGold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AJUSTES',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: primaryGold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color(0xFF0A0A0A), const Color(0xFF141414)]
              : [const Color(0xFFF8F8F8), const Color(0xFFEEEEEE)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _buildSectionHeader('SEGURIDAD', primaryGold),
            if (_isBiometricSupported)
              _buildSettingCard(
                context,
                icon: Icons.fingerprint_rounded,
                title: 'Acceso Biométrico',
                subtitle: 'Usa Face ID o Huella para iniciar sesión',
                trailing: Switch(
                  value: _useBiometrics,
                  onChanged: _toggleBiometrics,
                  activeColor: primaryGold,
                ),
              )
            else
              _buildSettingCard(
                context,
                icon: Icons.fingerprint_rounded,
                title: 'Acceso Biométrico',
                subtitle: 'No disponible en este dispositivo',
                trailing: Icon(Icons.error_outline, color: isDark ? Colors.grey : Colors.black26),
              ),
            const SizedBox(height: 24),
            _buildSectionHeader('APARIENCIA', primaryGold),
            BlocBuilder<ThemeBloc, ThemeState>(
              builder: (context, state) {
                final currentIsDark = state.themeMode == ThemeMode.dark;
                return _buildSettingCard(
                  context,
                  icon: currentIsDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: 'Modo Oscuro',
                  subtitle: 'Cambia el tema visual de la aplicación',
                  trailing: Switch(
                    value: currentIsDark,
                    onChanged: (val) =>
                        context.read<ThemeBloc>().add(ToggleTheme()),
                    activeColor: primaryGold,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('SISTEMA', primaryGold),
            _buildSettingCard(
              context,
              icon: Icons.info_outline_rounded,
              title: 'Versión',
              subtitle: 'BM BARBER v0.1.0',
              trailing:
                  Text('Beta', style: TextStyle(color: isDark ? Colors.grey : Colors.black38)),
            ),
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'EQUIPO BM BARBER',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: primaryGold.withOpacity(0.4),
                  letterSpacing: 6,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryGold = const Color(0xFFC5A028);

    return Card(
      elevation: isDark ? 0 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryGold),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold, 
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 12, 
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
