import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../bloc/pos_bloc.dart';
import '../bloc/pos_event.dart';
import '../bloc/pos_state.dart';
import '../../domain/entities/sale.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../../inventory/presentation/pages/inventory_page.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../widgets/mercadopago_qr_dialog.dart';
import '../../../auth/presentation/pages/staff_page.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/bloc/user_bloc.dart';
import '../../../auth/presentation/bloc/user_event.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../reports/presentation/pages/cashbox_closing_page.dart';
import '../../../reports/presentation/pages/payroll_page.dart';
import '../../../booking/presentation/pages/booking_page.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../expenses/presentation/bloc/expense_event.dart';
import '../../../expenses/presentation/bloc/expense_state.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import 'package:posbarber/core/database/database_helper.dart';
import 'package:posbarber/core/utils/pwa_installer.dart';
import 'package:posbarber/core/utils/version_info.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../help/presentation/pages/help_page.dart';
import '../../../auth/presentation/pages/admin_profile_page.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  void _loadData() {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    String? userName;
    if (authState is Authenticated) {
      userName = authState.user.name;
    }

    // Pass the current user's role to the Bloc so it can decide what to load
    context.read<PosBloc>().add(LoadPosData(userName: userName));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLoginRequirements();
    });
  }

  Future<void> _checkFirstLoginRequirements() async {
    if (mounted) {
      _checkBiometricOptIn();
    }
  }

  Future<void> _checkBiometricOptIn() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool('use_biometrics_asked') ?? false;
    if (hasAsked) return;

    await Future.delayed(const Duration(milliseconds: 1000));
    bool isSupported = false;
    try {
      if (kIsWeb) {
        // Reintentar hasta 3 veces con delay
        for (int i = 0; i < 3; i++) {
          isSupported = await PwaInstaller.checkWebBiometrics();
          if (isSupported) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } else {
        final auth = LocalAuthentication();
        final deviceSupported = await auth.isDeviceSupported();
        final canCheck = await auth.canCheckBiometrics;
        isSupported = deviceSupported || canCheck;
      }
    } catch (e) {
      debugPrint('[Biometrics] Error checking support: $e');
    }

    if (isSupported) {
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Inicio de sesión rápido', style: TextStyle(color: Color(0xFFC5A028))),
          content: const Text(
            '¿Deseas habilitar tu Face ID / Huella para acceder automáticamente la próxima vez?',
            style: TextStyle(color: Colors.white70),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'No por ahora',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC5A028),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sí, habilitar'),
            ),
          ],
        ),
      );

      await prefs.setBool('use_biometrics_asked', true);
      if (result == true) {
        bool linked = false;
        if (kIsWeb) {
          final authState = context.read<AuthBloc>().state;
          final userName = authState is Authenticated ? authState.user.name : 'Staff';
          final credId = await PwaInstaller.linkWebBiometrics(userName);
          if (credId != null) {
            await prefs.setString('bio_cred_id', credId);
            linked = true;
          }
        } else {
          linked = true; // On mobile, if they said yes, we trust the already performed auth
        }

        if (linked) {
          await prefs.setBool('use_biometrics', true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometría activada con éxito.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo vincular la biometría.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    } else {
      // Even if not supported, mark as asked to avoid repetitive checks
      await prefs.setBool('use_biometrics_asked', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final bool isAdmin = authState is Authenticated && authState.user.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC5A028).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: -2,
                    offset: const Offset(0, 2),
                  ),
                ],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 48,
                  cacheWidth: 150,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.content_cut_rounded, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BM BARBER',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (!isAdmin)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                onPressed: () async {
                  final barcode = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
                  );
                  if (barcode != null && mounted) {
                    final state = context.read<PosBloc>().state;
                    try {
                      final product = state.products.firstWhere(
                        (p) => p.barcode == barcode,
                      );
                      context.read<PosBloc>().add(AddProductToCart(product));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Agregado: ${product.name}'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Producto no encontrado: $barcode'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, size: 20),
              onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
            ),
          ),
        ],
      ),
      drawer: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final isHeadBarber =
              authState is Authenticated &&
              authState.user.role == UserRole.headBarber;
          return Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        const Color(0xFFC5A028),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: const Color(0xFFC5A028).withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 110,
                              width: 110,
                              fit: BoxFit.cover,
                              cacheWidth: 250,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.content_cut_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'BM BARBER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (authState is Authenticated)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${authState.user.name} • ${isAdmin ? 'Admin' : (isHeadBarber ? 'Barbero Jefe' : 'Personal')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                  // Eliminamos las rutas sueltas de Admin y Staff de la parte superior
                if (authState is Authenticated && authState.user.role == UserRole.employee)
                  BlocBuilder<PosBloc, PosState>(
                    builder: (context, posState) {
                      final userName = authState.user.name.trim().toLowerCase();
                      double grossCommission = 0;
                      double pendingBalance = 0;
                      
                      // Case-insensitive service commission
                      for (var entry in posState.barberServiceSales.entries) {
                        if (entry.key.toLowerCase() == userName) {
                          grossCommission = entry.value * 0.5;
                          break;
                        }
                      }

                      // Case-insensitive pending balance
                      for (var entry in posState.barberPendingBalance.entries) {
                        if (entry.key.toLowerCase() == userName) {
                          pendingBalance = entry.value;
                          break;
                        }
                      }

                      final netTotal = grossCommission - pendingBalance;

                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC5A028).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFC5A028).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'PAGO ESTIMADO (HOY)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFC5A028),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Icon(Icons.account_balance_wallet_outlined, size: 14, color: const Color(0xFFC5A028).withOpacity(0.5)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildSalaryRow('Ventas Totales', posState.currentUserDailySales, isBold: false),
                              const SizedBox(height: 4),
                              _buildSalaryRow('Comisión (50%)', grossCommission, isBold: false),
                              const SizedBox(height: 4),
                              _buildSalaryRow('Saldo A Cuenta', -pendingBalance, isBold: false, color: Colors.redAccent),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Divider(height: 1, color: Colors.white10),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'PAGO NETO FINAL',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                                  ),
                                  Text(
                                    NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(netTotal),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFC5A028),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Se descontará al cierre del día',
                                style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.point_of_sale_rounded),
                  title: const Text('Terminal de Ventas'),
                  onTap: () => Navigator.pop(context),
                  selected: true,
                  selectedColor: const Color(0xFFC5A028),
                  selectedTileColor: const Color(0xFFC5A028).withOpacity(0.05),
                ),
                ListTile(
                  leading: const Icon(Icons.event_note_rounded),
                  title: const Text('Agenda de Turnos'),
                  onTap: () async {
                    final nav = Navigator.of(context);
                    nav.pop();
                    await nav.push(
                      MaterialPageRoute(builder: (_) => const BookingPage()),
                    );
                    _loadData();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Clientes'),
                  onTap: () async {
                    final nav = Navigator.of(context);
                    nav.pop();
                    await nav.push(
                      MaterialPageRoute(builder: (_) => const CustomersPage()),
                    );
                    _loadData();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Control de Gastos'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ExpensesPage()),
                    );
                    _loadData();
                  },
                ),
                const Divider(),
                if (isAdmin || isHeadBarber)
                  ExpansionTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFC5A028)),
                    title: const Text('Panel Administrativo', style: TextStyle(fontWeight: FontWeight.bold)),
                    childrenPadding: const EdgeInsets.only(left: 16),
                    collapsedIconColor: const Color(0xFFC5A028),
                    iconColor: const Color(0xFFC5A028),
                    children: [
                      if (isAdmin)
                        ListTile(
                          leading: const Icon(Icons.hub_outlined, size: 20, color: Color(0xFFC5A028)),
                          title: const Text('Central de Control', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A028))),
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminProfilePage()),
                            );
                            _loadData();
                          },
                        ),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined, size: 20),
                        title: const Text('Gestión de Personal'),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          nav.pop();
                          await nav.push(
                            MaterialPageRoute(builder: (_) => const StaffPage()),
                          );
                          _loadData();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.inventory_2, size: 20),
                        title: const Text('Inventario'),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          nav.pop();
                          await nav.push(
                            MaterialPageRoute(builder: (_) => const InventoryPage()),
                          );
                          _loadData();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.bar_chart, size: 20),
                        title: const Text('Reportes Generales'),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          nav.pop();
                          await nav.push(
                            MaterialPageRoute(builder: (_) => const ReportsPage()),
                          );
                          _loadData();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.point_of_sale, size: 20, color: Color(0xFFC5A028)),
                        title: const Text('Cierre de Caja', style: TextStyle(color: Color(0xFFC5A028))),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          nav.pop();
                          await nav.push(
                            MaterialPageRoute(builder: (_) => const CashboxClosingPage()),
                          );
                          _loadData();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.account_balance_wallet, size: 20, color: Color(0xFFC5A028)),
                        title: const Text('Liquidaciones', style: TextStyle(color: Color(0xFFC5A028))),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          nav.pop();
                          await nav.push(
                            MaterialPageRoute(builder: (_) => const PayrollPage()),
                          );
                          _loadData();
                        },
                      ),
                    ],
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded, color: Color(0xFFC5A028)),
                  title: const Text('Ayuda y Tutorial'),
                  subtitle: const Text('¿Cómo usar el sistema?'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Ajustes'),
                  subtitle: const Text('Seguridad y apariencia'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                    _loadData();
                  },
                ),
                if (isAdmin) ...[
                  if (isAdmin)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'MODO OBSERVADOR: Como Admin solo puedes visualizar el sistema.',
                              style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isAdmin && kIsWeb)
                    ListTile(
                      leading: const Icon(
                        Icons.install_mobile_rounded,
                        color: Color(0xFFC5A028),
                      ),
                      title: const Text('Instalar Aplicación'),
                      subtitle: const Text('Acceso rápido desde tu escritorio'),
                      onTap: () async {
                        final installed = await PwaInstaller.installPWA();
                        if (installed) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Gracias por instalar!'),
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Si estás en iPhone/iOS, usa el botón "Compartir" y luego "Agregar a pantalla de inicio".',
                                ),
                                duration: Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  if (isAdmin) const Divider(),
                  if (isAdmin)
                    ListTile(
                      leading: const Icon(Icons.refresh, color: Colors.red),
                      title: const Text(
                        'Reiniciar Base de Datos',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('¿Reiniciar Base de Datos?'),
                            content: const Text(
                              'Se borrarán todos los datos y se cargarán los productos por defecto (Barba, Corte, Bebidas, etc).',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Sí, Reiniciar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          try {
                            await DatabaseHelper().resetDatabase();
                            if (mounted) {
                              _loadData();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Base de datos reiniciada con éxito',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al reiniciar: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                ],
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        'Katrix Barber v${VersionInfo.appVersion}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DB Version: ${VersionInfo.dbVersion}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.withOpacity(0.4),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
            listener: (context, authState) {
              if (authState is Authenticated) {
                _loadData();
              }
            },
          ),
          BlocListener<PosBloc, PosState>(
            listenWhen: (previous, current) =>
                previous.status != current.status ||
                previous.errorMessage != current.errorMessage,
            listener: (context, state) {
              if (state.status == PosStatus.error && state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (state.status == PosStatus.success) {
                _showSuccessDialog(context, state);
              }
            },
          ),
          BlocListener<ExpenseBloc, ExpenseState>(
            listener: (context, state) {
              if (state.status == ExpenseStatus.success) {
                // When debt is settled or expenses change, refresh POS data to update summary card
                _loadData();
              }
            },
          ),
        ],
        child: ScreenTypeLayout.builder(
          mobile: (context) {
            final authState = context.read<AuthBloc>().state;
            final bool isAdmin = authState is Authenticated && authState.user.role == UserRole.admin;
            return _buildMobileLayout(context, isAdmin: isAdmin);
          },
          tablet: (context) {
            final authState = context.read<AuthBloc>().state;
            final bool isAdmin = authState is Authenticated && authState.user.role == UserRole.admin;
            return _buildTabletLayout(context, isAdmin: isAdmin);
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, {bool isAdmin = false}) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        return Column(
          children: [
            Expanded(child: _buildProductList(state, isAdmin: isAdmin)),
            if (!isAdmin) _buildCartSummary(state),
          ],
        );
      },
    );
  }

  Widget _buildTabletLayout(BuildContext context, {bool isAdmin = false}) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        return Row(
          children: [
            Expanded(flex: 2, child: _buildProductList(state, isAdmin: isAdmin)),
            const VerticalDivider(width: 1),
            if (!isAdmin) Expanded(flex: 1, child: _buildCartSidebar(state)),
          ],
        );
      },
    );
  }

  Widget _buildProductList(PosState state, {bool isAdmin = false}) {
    if (state.status == PosStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No hay productos registrados',
              style: TextStyle(color: Colors.grey),
            ),
            TextButton(onPressed: () {}, child: const Text('Ir a Inventario')),
          ],
        ),
      );
    }

    final categories = state.availableCategories;
    final filteredProducts = state.filteredProducts;

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (state.pendingExpensesAmount != null && state.pendingExpensesAmount! > 0)
            SliverToBoxAdapter(
              child: _buildFinancialSummary(state),
            ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 20, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Categorías',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: state.selectedCategory == category,
                      onSelected: (selected) {
                        if (selected) {
                          context.read<PosBloc>().add(SelectCategory(category));
                        }
                      },
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: state.selectedCategory == category
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 32, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'SERVICIOS Y PRODUCTOS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Color(0xFFC5A028),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: getValueForScreenType(
                  context: context,
                  mobile: 2,
                  tablet: 3,
                  desktop: 4,
                ),
                childAspectRatio: getValueForScreenType(
                  context: context,
                  mobile: 0.85,
                  tablet: 0.95,
                  desktop: 1.1,
                ),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = filteredProducts[index];
                  return _buildProductCard(product, index, isAdmin: isAdmin);
                },
                childCount: filteredProducts.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(PosState state) {
    final authState = context.read<AuthBloc>().state;
    final bool isHeadBarber = authState is Authenticated && authState.user.role == UserRole.headBarber;

    final earnings = isHeadBarber ? state.dailySalesTotal : state.currentUserDailySales;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFC5A028).withOpacity(0.15),
            const Color(0xFFC5A028).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC5A028).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHeadBarber ? 'RECAUDACIÓN TOTAL HOY' : 'RECAUDADO HOY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: const Color(0xFFC5A028),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(
              symbol: '\$',
              decimalDigits: 0,
              locale: 'es_AR',
            ).format(earnings),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(dynamic product, int index, {bool isAdmin = false}) {
    IconData getIcon() {
      if (product.isService) return Icons.content_cut_rounded;
      switch (product.category.toLowerCase()) {
        case 'bebidas':
          return Icons.local_bar_rounded;
        case 'perfumes':
          return Icons.auto_awesome;
        case 'ropa':
          return Icons.checkroom_rounded;
        default:
          return Icons.shopping_bag_outlined;
      }
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 200 + (index * 50).clamp(0, 400)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () => context.read<PosBloc>().add(AddProductToCart(product)),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.03) // Subtle lift
                        : const Color(0xFFC5A028).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inner glow for images
                      if (Theme.of(context).brightness == Brightness.dark)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.03),
                                blurRadius: 40,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      Hero(
                        tag: 'product_${product.id}',
                        child:
                            product.imageUrl != null &&
                                product.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: product.imageUrl!.startsWith('assets/')
                                    ? Image.asset(
                                        product.imageUrl!,
                                        fit: BoxFit.contain,
                                        cacheWidth: 200,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                                  getIcon(),
                                                  size: 40,
                                                  color: const Color(
                                                    0xFFC5A028,
                                                  ),
                                                ),
                                      )
                                    : Image.network(
                                        product.imageUrl!,
                                        fit: BoxFit.contain,
                                        cacheWidth: 200,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                                  getIcon(),
                                                  size: 40,
                                                  color: const Color(
                                                    0xFFC5A028,
                                                  ),
                                                ),
                                      ),
                              )
                            : Icon(
                                getIcon(),
                                size: 44,
                                color: const Color(0xFFC5A028),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5, // Balanced space
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.category.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFC5A028),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            NumberFormat.currency(
                              symbol: '\$',
                              decimalDigits: 0,
                              locale: 'es_AR',
                            ).format(product.price),
                            style: const TextStyle(
                              color: Color(0xFFC5A028),
                              fontWeight: FontWeight.w900,
                              fontSize: 19, // Highlight price
                            ),
                          ),
                          if (!product.isService)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (product.stock > 5
                                        ? Colors.green
                                        : Colors.orange)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${product.stock}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: product.stock > 5
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSidebar(PosState state) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_bag_rounded,
                  color: const Color(0xFFC5A028),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Carrito',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A028).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.cartCount}',
                    style: const TextStyle(
                      color: Color(0xFFC5A028),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (state.cartItems.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                    tooltip: 'Vaciar Carrito',
                    onPressed: () => _confirmClearCart(context),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Customer Selection Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFC5A028).withOpacity(0.05),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: state.selectedCustomer != null
                      ? const Color(0xFFC5A028)
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.selectedCustomer?.name ?? 'Seleccionar Cliente',
                    style: TextStyle(
                      fontWeight: state.selectedCustomer != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: state.selectedCustomer != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.grey,
                    ),
                  ),
                ),
                if (state.selectedCustomer != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () =>
                        context.read<PosBloc>().add(const SelectCustomer(null)),
                  )
                else
                  TextButton(
                    onPressed: () =>
                        _showCustomerSelectionDialog(context, state),
                    child: const Text('Cambiar'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildCartItemsList(state)),
          _buildCheckoutSection(state),
        ],
      ),
    );
  }

  Widget _buildCartSummary(PosState state) {
    if (state.cartItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final bool isStaff = authState is Authenticated && 
                (authState.user.role == UserRole.employee || 
                 authState.user.role == UserRole.admin || 
                 authState.user.role == UserRole.headBarber);
            
            final bool hasServices = state.cartItems.any((item) => item.isService);
            final bool hasProducts = state.cartItems.any((item) => !item.isService);
            
            // Show "A Cuenta" only if it has products and the user is staff. 
            // If it has services, we prioritize the general POS (Confirmar Venta) flow for now.
            final bool showACuenta = isStaff && hasProducts && !hasServices;
            // Show "Confirmar Venta" for customers (has services) or for anyone selling to public.
            // If it has ONLY products and the user is staff, we hide it as per user's request.
            final bool showConfirmar = hasServices || (!isStaff && hasProducts);

            return Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL A PAGAR',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(state.total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFC5A028),
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _confirmClearCart(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.2), width: 1),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.remove_circle_outline_rounded, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'CANCELAR',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                if (showACuenta) ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFC5A028).withOpacity(0.3), width: 1),
                      color: const Color(0xFFC5A028).withOpacity(0.05),
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (state.cartItems.isEmpty) return;
                        _showCheckoutBottomSheet(context, state, isPersonal: true);
                      },
                      icon: const Icon(Icons.person_pin_rounded, color: Color(0xFFC5A028)),
                      tooltip: 'Consumo Personal (A Cuenta)',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
                if (showConfirmar) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (state.cartItems.isEmpty) return;
                        _showCheckoutBottomSheet(context, state, isPersonal: false);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        backgroundColor: const Color(0xFFC5A028),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'COBRAR VENTA',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartItemsList(PosState state) {
    if (state.cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: Colors.grey.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Tu carrito está vacío',
              style: TextStyle(
                color: Colors.grey.withOpacity(0.5),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.cartItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = state.cartItems[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${item.price.toStringAsFixed(2)} c/u',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _CartQtyButton(
                    icon: Icons.remove,
                    onTap: () => context.read<PosBloc>().add(
                      UpdateItemQuantity(item.productId, item.quantity - 1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _CartQtyButton(
                    icon: Icons.add,
                    onTap: () => context.read<PosBloc>().add(
                      UpdateItemQuantity(item.productId, item.quantity + 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection(PosState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '\$${state.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              Text(
                '\$${state.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: Color(0xFFC5A028),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (state.cartItems.isEmpty) return;
              _showCheckoutBottomSheet(context, state);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: state.cartItems.isEmpty
                  ? Colors.grey
                  : const Color(0xFFC5A028),
              foregroundColor: state.cartItems.isEmpty
                  ? Colors.black54
                  : Colors.black,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              elevation: 0,
            ),
            child: const Text('Confirmar Venta'),
          ),
        ],
      ),
    );
  }

  void _showCheckoutBottomSheet(BuildContext context, PosState state, {bool isPersonal = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPersonal ? 'REGISTRAR' : 'FINALIZAR',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFC5A028),
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        isPersonal ? 'A CUENTA' : 'VENTA',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A028).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(state.total),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFC5A028),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (!isPersonal)
                Row(
                  children: [
                    Expanded(
                      child: _PaymentMethodButton(
                        label: 'EFECTIVO',
                        icon: Icons.payments_rounded,
                        onTap: () => _finalizeSale(context, PaymentMethod.cash),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PaymentMethodButton(
                        label: 'PAGO QR',
                        icon: Icons.qr_code_2_rounded,
                        onTap: () async {
                          final ref = 'VEN-${DateTime.now().millisecondsSinceEpoch}';
                          final success = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => MercadopagoQRDialog(
                              total: state.total,
                              orderReference: ref,
                            ),
                          );
                          if (success == true) {
                            final authState = context.read<AuthBloc>().state;
                            final String effectiveUserName =
                                authState is Authenticated
                                    ? authState.user.name
                                    : 'Staff';
                            context.read<PosBloc>().add(ConfirmSale(
                                  PaymentMethod.qr,
                                  effectiveUserName,
                                  externalReference: ref,
                                ));
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              if (isPersonal)
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, authState) {
                    final String currentUserName = authState is Authenticated ? authState.user.name : 'Vendedor';
                    final String userNameKey = currentUserName.trim().toLowerCase();
                    
                    // Get current service sales for commission calculation
                    double serviceSales = 0;
                    for (var entry in state.barberServiceSales.entries) {
                      if (entry.key.toLowerCase() == userNameKey) {
                        serviceSales = entry.value;
                        break;
                      }
                    }
                    
                    final double grossCommission = serviceSales * 0.5;
                    final double currentBalance = state.barberPendingBalance[userNameKey] ?? 0.0;
                    final double currentNetPay = grossCommission - currentBalance;
                    final double projectedNetPay = currentNetPay - state.total;
                    
                    final bool isNegative = projectedNetPay < 0;
                    final bool isWarning = projectedNetPay >= 0 && projectedNetPay <= 15000;

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isNegative 
                                ? Colors.red.withOpacity(0.1) 
                                : (isWarning ? Colors.orange.withOpacity(0.1) : Colors.white.withOpacity(0.03)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isNegative 
                                  ? Colors.red.withOpacity(0.3) 
                                  : (isWarning ? Colors.orange.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildDebtRow('Tus ganancias de hoy (50%)', grossCommission),
                              _buildDebtRow('Tu deuda acumulada', -currentBalance, color: Colors.redAccent),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Divider(height: 1, color: Colors.white10),
                              ),
                              _buildDebtRow('Tu paga neta actual', currentNetPay, isBold: true, color: currentNetPay >= 0 ? Colors.green : Colors.red),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    _buildDebtRow('Este consumo restará', -state.total, color: const Color(0xFFC5A028)),
                                    const SizedBox(height: 4),
                                    _buildDebtRow(
                                      'Paga final estimada', 
                                      projectedNetPay, 
                                      isBold: true, 
                                      color: isNegative ? Colors.red : (isWarning ? Colors.orange : Colors.green)
                                    ),
                                  ],
                                ),
                              ),
                              if (isNegative) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '¡PELIGRO! Tu saldo pasará a ser negativo. Le deberás dinero a la barbería.',
                                        style: TextStyle(color: Colors.red.shade300, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (isWarning) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Cuidado, te va a quedar muy poca paga neta hoy.',
                                        style: TextStyle(color: Colors.orange.shade300, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _PaymentMethodButton(
                          label: isNegative ? 'CONFIRMAR (VIVIR AL LÍMITE)' : 'CONFIRMAR REGISTRO (@$currentUserName)',
                          icon: isNegative ? Icons.priority_high_rounded : Icons.person_pin_rounded,
                          isSecondary: false,
                          onTap: () {
                            _finalizeSale(context, PaymentMethod.personal, userName: currentUserName);
                          },
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebtRow(String label, double value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(value),
          style: TextStyle(
            color: color ?? Colors.white70,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _finalizeSale(BuildContext context, PaymentMethod method, {String? userName}) {
    final authState = context.read<AuthBloc>().state;
    final String effectiveUserName = userName ?? (authState is Authenticated ? authState.user.name : 'Staff');

    debugPrint('[POS] Finalizing sale for user: $effectiveUserName');
    context.read<PosBloc>().add(ConfirmSale(method, effectiveUserName));
    Navigator.pop(context);

    // Show feedback
    String title = 'Venta exitosa';
    String message = 'La venta se ha registrado correctamente.';
    IconData icon = Icons.check_circle_rounded;
    Color color = Colors.green;

    if (method == PaymentMethod.personal) {
      title = 'Consumo registrado';
      message = 'El gasto se ha cargado a la cuenta de $effectiveUserName.';
      icon = Icons.person_pin_circle_rounded;
      color = const Color(0xFFC5A028);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    Text(
                      message,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStaffSelectionForACuenta(BuildContext context, PosState state) async {
    // We need to fetch barbers from UserBloc or DB
    final db = await DatabaseHelper().database;
    final staffMaps = await db.query('users', where: 'role != ?', whereArgs: ['admin']);
    final staffs = staffMaps.map((m) => {
      'id': m['id'],
      'name': m['name'],
      'username': m['username'],
    }).toList();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿A cuenta de quién?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: staffs.length,
            itemBuilder: (context, index) {
              final staff = staffs[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFC5A028),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(staff['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('@${staff['username']}'),
                onTap: () async {
                  Navigator.pop(ctx); // Cerrar dialogo staff
                  Navigator.pop(context); // Cerrar bottom sheet checkout
                  
                  // 1. Save Sale as 'personal' attributed to the selected staff member
                  context.read<PosBloc>().add(ConfirmSale(PaymentMethod.personal, staff['name'] as String));

                  // 2. Create Expense entry
                  final String itemsDesc = state.cartItems.map((i) => '${i.quantity}x ${i.productName}').join(', ');
                  await db.insert('expenses', {
                    'description': 'Consumo Personal: $itemsDesc',
                    'amount': state.total,
                    'due_date': DateTime.now().toIso8601String(),
                    'is_paid': 0,
                    'category': 'Consumo Personal',
                    'user_name': staff['name'],
                    'staff_user_id': staff['id'],
                    'type': 'consumption',
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cargado a la cuenta de ${staff['name']}'),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCustomerSelectionDialog(BuildContext context, PosState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar Cliente'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.customers.length,
            itemBuilder: (context, index) {
              final customer = state.customers[index];
              return ListTile(
                title: Text(customer.name),
                subtitle: Text(customer.phone ?? ''),
                onTap: () {
                  context.read<PosBloc>().add(SelectCustomer(customer));
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmClearCart(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Vaciar Carrito?'),
        content: const Text('Se eliminarán todos los productos seleccionados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, volver'),
          ),
          TextButton(
            onPressed: () {
              context.read<PosBloc>().add(ClearPos());
              Navigator.pop(ctx);
            },
            child: const Text('Sí, Vaciar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, PosState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('¡Venta Exitosa!', textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'La venta se ha procesado correctamente.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (state.lastConfirmedSale != null) {
                    _sendWhatsAppReceipt(
                      state.lastConfirmedCustomer,
                      state.lastConfirmedSale!,
                    );
                  }
                },
                icon: const FaIcon(FontAwesomeIcons.whatsapp),
                label: const Text('Enviar Ticket WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsAppReceipt(Customer? customer, Sale sale) async {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('✂️ *Ticket Digital - Barber POS* ✂️');
    final customerName = customer?.name ?? 'Cliente';
    buffer.writeln('Hola *$customerName*, gracias por tu visita.');
    buffer.writeln('');
    buffer.writeln('*Detalle:*');
    for (var item in sale.items) {
      buffer.writeln(
        '- ${item.productName} x ${item.quantity} (\$${item.total.toStringAsFixed(0)})',
      );
    }
    buffer.writeln('');
    buffer.writeln('*Total:* \$${sale.total.toStringAsFixed(0)}');
    buffer.writeln('*Pago:* ${sale.paymentMethod.name.toUpperCase()}');
    buffer.writeln('');
    buffer.writeln('¡Te esperamos pronto! 💈');

    final String message = Uri.encodeComponent(buffer.toString());
    
    // Si tenemos cliente con teléfono, lo mandamos directo. Si no, abrimos WhatsApp genérico.
    Uri url;
    if (customer != null && customer.phone != null && customer.phone!.isNotEmpty) {
      final String phone = customer.phone!.replaceAll(RegExp(r'\D'), '');
      final String targetPhone = phone.startsWith('54') ? phone : '54$phone';
      url = Uri.parse('https://wa.me/$targetPhone?text=$message');
    } else {
      url = Uri.parse('https://wa.me/?text=$message');
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSalaryRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(amount),
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showSettleConfirmation(BuildContext context, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 16),
            const Text(
              'BORRAR DEUDA',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de que el barbero ya pagó todo su consumo personal?',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Esta acción marcará todos los gastos pendientes como PAGADOS y el contador volverá a cero.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC5A028),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'CANCELAR',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ExpenseBloc>().add(SettleAllExpensesEvent(userName));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'SÍ, BORRAR TODO',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CartQtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFC5A028).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 14, color: const Color(0xFFC5A028)),
      ),
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSecondary;

  const _PaymentMethodButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: isSecondary ? 100 : 120,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSecondary 
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFC5A028).withOpacity(0.15),
          ),
          borderRadius: BorderRadius.circular(20),
          color: isSecondary 
              ? Colors.black.withOpacity(0.3)
              : const Color(0xFFC5A028).withOpacity(0.05),
          boxShadow: isSecondary ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isSecondary ? Colors.white38 : const Color(0xFFC5A028), 
              size: isSecondary ? 28 : 32
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSecondary ? 10 : 11,
                fontWeight: isSecondary ? FontWeight.normal : FontWeight.w900,
                color: isSecondary ? Colors.white38 : Colors.white,
                letterSpacing: isSecondary ? 0.0 : 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.all],
  );
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    controller.start(); // Forzar encendido de camara en nativo (Android/iOS)
  }

  @override
  void dispose() {
    controller.stop();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  _isScanned = true;
                  Navigator.pop(context, code);
                }
              }
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFC5A028), width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                onPressed: () => controller.toggleTorch(),
                icon: const Icon(
                  Icons.flashlight_on_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
