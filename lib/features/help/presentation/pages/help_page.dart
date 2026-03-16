import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  int _selectedSection = 0;

  final List<Map<String, dynamic>> _sections = [
    {
      'title': 'Instalación PWA',
      'icon': Icons.install_mobile_rounded,
      'content': [
        {
          'subtitle': '📱 En Android (Chrome)',
          'text': '1. Abre la web en Chrome.\n2. Presiona el botón "INSTALAR APLICACIÓN" en el login.\n3. Confirma la instalación y aparecerá el icono en tu escritorio.',
        },
        {
          'subtitle': '🍎 En iPhone (Safari)',
          'text': '1. Abre la web en Safari.\n2. Toca el botón "Compartir" (el cuadrado con la flecha).\n3. Selecciona "Agregar a pantalla de inicio".\n4. Presiona "Agregar" arriba a la derecha.',
        },
      ],
    },
    {
      'title': 'Acceso Biométrico',
      'icon': Icons.fingerprint_rounded,
      'content': [
        {
          'subtitle': '🔐 Configuración Inicial',
          'text': '1. Inicia sesión con tu usuario y contraseña.\n2. El sistema te preguntará si quieres activar el acceso rápido.\n3. Presiona "Sí, habilitar" y pon tu huella o FaceID.',
        },
        {
          'subtitle': '💻 Uso en la Web',
          'text': 'En el navegador, al tocar el botón de huella, aparecerá una ventana emergente de seguridad. Usa el lector de tu dispositivo para validar tu identidad sin escribir la contraseña.',
        },
      ],
    },
    {
      'title': 'Uso Diario (POS)',
      'icon': Icons.point_of_sale_rounded,
      'content': [
        {
          'subtitle': '🛒 Realizar una Venta',
          'text': '1. Selecciona los productos tocándolos.\n2. En el resumen de compra, presiona "COBRAR".\n3. Selecciona el barbero que realiza el servicio para que su comisión se asigne correctamente.',
        },
        {
          'subtitle': '📊 Cierre de Caja',
          'text': 'Admin y Barbero Jefe pueden ver el cierre del día en la sección de "Reportes". Allí verás el total de ventas, efectivo y comisiones generadas.',
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(
          'CENTRO DE AYUDA',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Row(
        children: [
          // Sidebar (GitBook Style)
          Container(
            width: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: ListView.builder(
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedSection == index;
                return InkWell(
                  onTap: () => setState(() => _selectedSection = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? const Color(0xFFC5A028) : Colors.transparent,
                          width: 4,
                        ),
                      ),
                      color: isSelected ? const Color(0xFFC5A028).withOpacity(0.05) : null,
                    ),
                    child: Icon(
                      _sections[index]['icon'] as IconData,
                      color: isSelected ? const Color(0xFFC5A028) : Colors.white24,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
          ),
          // Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sections[_selectedSection]['title'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFC5A028),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    width: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A028).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ...(_sections[_selectedSection]['content'] as List<Map<String, String>>).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 48.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['subtitle']!,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item['text']!,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.white70,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
