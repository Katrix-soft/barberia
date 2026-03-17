import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/user.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  int _selectedSection = 0;

  List<Map<String, dynamic>> _getSections(UserRole role) {
    final bool isStaff = role == UserRole.employee;

    if (isStaff) {
      return [
        {
          'title': 'Mi Comisión',
          'icon': Icons.account_balance_wallet_rounded,
          'content': [
            {
              'subtitle': '💰 Seguimiento Diario',
              'text': 'Puedes ver tu comisión del día abriendo el menú lateral (Drawer). Allí verás:\n• Comisión Bruta (50% de servicios).\n• Descuentos (Adelantos o gastos a cuenta).\n• Total Neto a cobrar al final de la jornada.',
            },
            {
              'subtitle': '📋 Asignación de Servicios',
              'text': 'Al realizar una venta, asegúrate de que el cajero seleccione tu nombre en la lista de barberos. Solo así se sumará la comisión a tu perfil.',
            },
          ],
        },
        {
          'title': 'Ventas y POS',
          'icon': Icons.point_of_sale_rounded,
          'content': [
            {
              'subtitle': '🛒 Uso de la Terminal',
              'text': '1. Selecciona los productos tocándolos en la pantalla.\n2. Usa el icono de QR arriba a la derecha para escanear productos con código de barras.\n3. Presiona "COBRAR" para finalizar.',
            },
          ],
        },
        _pwaSection,
        _biometricSection,
      ];
    } else {
      // Admin / Head Barber
      return [
        {
          'title': 'Gestión de Equipo',
          'icon': Icons.badge_rounded,
          'content': [
            {
              'subtitle': '👥 Administrar Personal',
              'text': 'En la sección "Personal", puedes:\n• Agregar nuevos barberos.\n• Editar perfiles y cambiar contraseñas.\n• Ver el desempeño individual del equipo.',
            },
          ],
        },
        {
          'title': 'Inventario',
          'icon': Icons.inventory_2_rounded,
          'content': [
            {
              'subtitle': '📦 Control de Stock',
              'text': 'Desde la sección "Inventario" puedes cargar nuevos productos, actualizar precios y controlar las existencias críticas.',
            },
          ],
        },
        {
          'title': 'Finanzas',
          'icon': Icons.bar_chart_rounded,
          'content': [
            {
              'subtitle': '📊 Reportes y Caja',
              'text': 'En "Reportes" puedes ver el cierre del día, filtrado por fecha. Incluye total de ventas, métodos de pago y desglose de comisiones pagadas.',
            },
          ],
        },
        _pwaSection,
        _biometricSection,
      ];
    }
  }

  final Map<String, dynamic> _pwaSection = {
    'title': 'Instalación',
    'icon': Icons.install_mobile_rounded,
    'content': [
      {
        'subtitle': '📱 En Android (Chrome)',
        'text': '1. Abre la web en Chrome.\n2. Presiona "Instalar Aplicación" en el menú.\n3. Confirma y aparecerá el icono en tu pantalla de inicio.',
      },
      {
        'subtitle': '🍎 En iPhone (Safari)',
        'text': '1. Toca el botón "Compartir".\n2. Selecciona "Agregar a pantalla de inicio".',
      },
    ],
  };

  final Map<String, dynamic> _biometricSection = {
    'title': 'Biometría',
    'icon': Icons.fingerprint_rounded,
    'content': [
      {
        'subtitle': '🔐 Acceso Rápido',
        'text': 'Activa Face ID o Huella en "Ajustes" para entrar al sistema sin escribir tu contraseña cada vez.',
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final role = (authState is Authenticated) ? authState.user.role : UserRole.employee;
    final sections = _getSections(role);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(
          'AYUDA: ${role == UserRole.employee ? 'BARBEROS' : 'ADMINISTRACIÓN'}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Row(
        children: [
          Container(
            width: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: ListView.builder(
              itemCount: sections.length,
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
                      sections[index]['icon'] as IconData,
                      color: isSelected ? const Color(0xFFC5A028) : Colors.white24,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sections[_selectedSection]['title'] as String,
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
                  ...(sections[_selectedSection]['content'] as List<Map<String, String>>).map((item) {
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
