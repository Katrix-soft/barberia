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

  double _progress = 0.0;

  Future<void> _doHardUpdate() async {
    // We'll simulate progress over 2 seconds to give the user time to read
    const int totalSteps = 100;
    const Duration stepDuration = Duration(milliseconds: 20);

    for (int i = 1; i <= totalSteps; i++) {
      if (!mounted) return;
      await Future.delayed(stepDuration);
      setState(() {
        _progress = i / 100;
      });
    }
    
    // Final wait
    await Future.delayed(const Duration(milliseconds: 300));
    
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
                // Animated Icon or Spinner at top
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _maintenanceMode ? Icons.engineering : Icons.cloud_download,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  _maintenanceMode ? 'MANTENIMIENTO' : 'ACTUALIZANDO KATRIX',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _maintenanceMode 
                    ? _message 
                    : 'Instalando la última versión y sincronizando base de datos...',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),

                // PROGRESS SECTION
                if (!_maintenanceMode) ...[
                   Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${(_progress * 100).toInt()}% COMPLETADO',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.amber,
                    ),
                  ),
                ] else
                   const CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),

                const SizedBox(height: 80),
                // DEBUG INFO (Subtle)
                Opacity(
                  opacity: 0.3,
                  child: Text(
                    'Local: ${VersionInfo.appVersion} | Remota: v$_message', 
                    style: const TextStyle(fontSize: 10, color: Colors.white),
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
