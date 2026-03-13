import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/version_service.dart';
import '../utils/browser_utils.dart';
import '../utils/version_info.dart';

class ForceUpdateGuard extends StatefulWidget {
  final Widget child;

  const ForceUpdateGuard({Key? key, required this.child}) : super(key: key);

  @override
  _ForceUpdateGuardState createState() => _ForceUpdateGuardState();
}

class _ForceUpdateGuardState extends State<ForceUpdateGuard> {
  final VersionService _versionService = VersionService();
  bool _needsUpdate = false;
  bool _maintenanceMode = false;
  String _message = '';
  String _updateUrl = '';
  bool _checking = true;
  bool _updateTriggered = false;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final status = await _versionService.checkVersion();
      if (mounted) {
        bool needAction = status['needsUpdate'] ?? false;
        
        setState(() {
          _needsUpdate = needAction;
          _maintenanceMode = status['maintenanceMode'] ?? false;
          _message = status['message'] ?? '';
          _updateUrl = status['update_url'] ?? '';
          _checking = false;
        });

        // SAFE AUTOMATIC ACTION
        if (needAction && !_maintenanceMode && !_updateTriggered) {
          _updateTriggered = true;
          // Wait for the UI to render the "Updating" screen first
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _doHardUpdate();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _doHardUpdate() async {
    // Add a tiny delay so the user sees the screen
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (kIsWeb) {
      await BrowserUtils.hardReload();
    } else {
      if (_updateUrl.isNotEmpty) {
        final url = Uri.parse(_updateUrl);
        try {
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Error launching update URL: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF0D0D0D),
          body: Center(
            child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
          ),
        ),
      );
    }

    if (_needsUpdate || _maintenanceMode) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: Colors.amber,
        ),
        home: Scaffold(
          body: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 45,
                  height: 45,
                  child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                ),
                const SizedBox(height: 40),
                Text(
                  _maintenanceMode ? 'MANTENIMIENTO' : 'ACTUALIZANDO KATRIX',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _maintenanceMode 
                    ? _message 
                    : 'Instalando la última versión para sincronizar base de datos y UI...',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (!_maintenanceMode)
                  Text(
                    'REINICIANDO...',
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.amber.withOpacity(0.8),
                      letterSpacing: 2,
                    ),
                  ),
                const SizedBox(height: 60),
                // DEBUG INFO (Subtle)
                Opacity(
                  opacity: 0.3,
                  child: Text(
                    'Local: ${VersionInfo.appVersion} | Remota: $_message', // _message often contains info
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
                if (_updateUrl.isNotEmpty)
                   Opacity(
                    opacity: 0.3,
                    child: Text(
                      'Link: $_updateUrl',
                      style: const TextStyle(fontSize: 8, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
