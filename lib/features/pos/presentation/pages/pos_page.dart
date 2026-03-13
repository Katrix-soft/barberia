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
import '../../../auth/presentation/pages/staff_page.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/bloc/user_bloc.dart';
import '../../../auth/presentation/bloc/user_event.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../booking/presentation/pages/booking_page.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../expenses/presentation/bloc/expense_event.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import 'package:posbarber/core/database/database_helper.dart';
import 'package:posbarber/core/utils/pwa_installer.dart';
import 'package:posbarber/core/utils/version_info.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../customers/domain/entities/customer.dart';

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
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    final user = authState.user;

    final prefs = await SharedPreferences.getInstance();
    final hasVerified =
        prefs.getBool('first_login_verified_${user.username}') ?? false;

    if (!hasVerified && mounted) {
      final changed = await _showForcePasswordChangeDialog(user);
      if (changed == true) {
        await prefs.setBool('first_login_verified_${user.username}', true);
      } else {
        if (mounted) context.read<AuthBloc>().add(LogoutRequested());
        return;
      }
    }

    if (mounted) {
      _checkBiometricOptIn();
    }
  }

  Future<bool?> _showForcePasswordChangeDialog(User user) {
    final pwdController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Color(0xFFC5A028)),
              SizedBox(width: 8),
              Text('Protege tu cuenta'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Este parece ser tu primer ingreso. Por razones de seguridad, debes cambiar tu contraseña temporal por una nueva para continuar.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pwdController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Nueva Contraseña',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (value) => value == null || value.length < 4
                      ? 'Mínimo 4 caracteres requeridos'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Salir', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC5A028),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  context.read<UserBloc>().add(
                    SaveUser(user, pwdController.text),
                  );
                  Navigator.pop(ctx, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contraseña actualizada con éxito.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Actualizar y Entrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkBiometricOptIn() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool('has_asked_biometrics') ?? false;
    if (hasAsked) return;

    final auth = LocalAuthentication();
    final isSupported = await auth.isDeviceSupported();
    final canCheck = await auth.canCheckBiometrics;

    if (isSupported || canCheck) {
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Inicio de sesión rápido'),
          content: const Text(
            '¿Deseas habilitar tu Face ID / Huella para acceder automáticamente la próxima vez?',
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

      await prefs.setBool('has_asked_biometrics', true);
      if (result == true) {
        await prefs.setBool('use_biometrics', true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometría activada con éxito.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
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
                              _buildSalaryRow('Comisión Bruta (50%)', grossCommission, isBold: false),
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
                                    'TOTAL NETO',
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
                if (isAdmin || isHeadBarber)
                  ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: const Text('Inventario'),
                    onTap: () async {
                      final nav = Navigator.of(context);
                      nav.pop();
                      await nav.push(
                        MaterialPageRoute(
                          builder: (_) => const InventoryPage(),
                        ),
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
                if (isAdmin || isHeadBarber)
                  ListTile(
                    leading: const Icon(Icons.bar_chart),
                    title: const Text('Reportes'),
                    onTap: () async {
                    final nav = Navigator.of(context);
                    nav.pop();
                    await nav.push(
                      MaterialPageRoute(builder: (_) => const ReportsPage()),
                    );
                    _loadData();
                    },
                  ),
                if (isAdmin || isHeadBarber)
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text('Personal'),
                    subtitle: isHeadBarber ? const Text('Gestionar mi equipo') : null,
                    onTap: () async {
                      final nav = Navigator.of(context);
                      nav.pop();
                      await nav.push(
                        MaterialPageRoute(builder: (_) => const StaffPage()),
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
                  if (!isAdmin) const Divider(),
                  if (!isAdmin)
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
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, authState) {
          if (authState is Authenticated) {
            _loadData();
          }
        },
        child: BlocListener<PosBloc, PosState>(
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
    final totalGoal = state.pendingExpensesAmount ?? 0;
    final progress = totalGoal > 0
        ? (earnings / totalGoal).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (totalGoal - earnings).clamp(0.0, double.infinity); 

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHeadBarber ? 'RECAUDACIÓN TOTAL HOY' : 'RECAUDADO HOY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Color(0xFFC5A028),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.currency(
                      symbol: '\$',
                      decimalDigits: 0,
                      locale: 'es_AR',
                    ).format(earnings),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (remaining <= 0 && totalGoal > 0)
                      ? Colors.green.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: (remaining <= 0 && totalGoal > 0)
                      ? Border.all(color: Colors.green.withOpacity(0.5))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      remaining <= 0 && totalGoal > 0
                          ? (remaining < 0
                              ? 'SUPERADO POR ${NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(remaining.abs())} ✨'
                              : 'META CUMPLIDA! ✨')
                          : 'FALTAN ${NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(remaining)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: (remaining <= 0 && totalGoal > 0)
                            ? Colors.green
                            : const Color(0xFFC5A028),
                      ),
                    ),
                    if (totalGoal > 0) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showSettleConfirmation(context, authState is Authenticated ? authState.user.name : 'admin'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3), width: 0.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cleaning_services, size: 10, color: Colors.red),
                              SizedBox(width: 4),
                              Text(
                                'BORRAR (YA PAGÓ)',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    height: 8,
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC5A028), Color(0xFFE5C158)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC5A028).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (state.pendingExpenseDescription != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tu próximo gasto: ${state.pendingExpenseDescription}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (isHeadBarber && state.barberSales.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text(
              'RENDIMIENTO POR BARBERO (HOY)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ...state.barberSales.entries.map((e) {
              final String name = e.key;
              final double totalValue = e.value;
              final double serviceValue = state.barberServiceSales[name] ?? 0;
              final double pendingBalance = state.barberPendingBalance[name] ?? 0;
              final double commission = serviceValue * 0.5;
              final double netTotal = commission - pendingBalance;
              final double percent = earnings > 0 ? totalValue / earnings : 0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                              if (pendingBalance > 0)
                                Text(
                                  'A Cuenta: -${NumberFormat.currency(symbol: r'$', decimalDigits: 0, locale: 'es_AR').format(pendingBalance)}',
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Bruto: ${NumberFormat.currency(symbol: r'$', decimalDigits: 0, locale: 'es_AR').format(commission)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                            ),
                            Text(
                              'NETO: ${NumberFormat.currency(symbol: r'$', decimalDigits: 0, locale: 'es_AR').format(netTotal)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC5A028), fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: percent,
                      backgroundColor: Colors.black12,
                      color: const Color(0xFFC5A028).withOpacity(0.6),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
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
        child: Row(
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
                  '\$${state.total.toStringAsFixed(2)}',
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
            TextButton.icon(
              onPressed: () => _confirmClearCart(context),
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
              label: const Text(
                'CANCELAR',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (state.cartItems.isEmpty) return;
                _showCheckoutBottomSheet(context, state);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                backgroundColor: state.cartItems.isEmpty
                    ? Colors.grey
                    : const Color(0xFFC5A028),
                foregroundColor: state.cartItems.isEmpty
                    ? Colors.black54
                    : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CONFIRMAR'),
            ),
          ],
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

  void _showCheckoutBottomSheet(BuildContext context, PosState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white24
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Finalizar Venta',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text(
                'Método de Pago',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _PaymentMethodButton(
                    label: 'Efectivo',
                    icon: Icons.payments_rounded,
                    onTap: () => _finalizeSale(context, PaymentMethod.cash),
                  ),
                  const SizedBox(width: 12),
                  _PaymentMethodButton(
                    label: 'Transferencia',
                    icon: Icons.account_balance_rounded,
                    onTap: () => _finalizeSale(context, PaymentMethod.transfer),
                  ),
                  const SizedBox(width: 12),
                  _PaymentMethodButton(
                    label: 'Tarjeta',
                    icon: Icons.credit_card_rounded,
                    onTap: () => _finalizeSale(context, PaymentMethod.card),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PaymentMethodButton(
                label: 'A CUENTA (PERSONAL)',
                icon: Icons.person_pin_circle_outlined,
                onTap: () => _showStaffSelectionForACuenta(context, state),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _finalizeSale(BuildContext context, PaymentMethod method) {
    final authState = context.read<AuthBloc>().state;
    String? userName;
    
    if (authState is Authenticated) {
      userName = authState.user.name;
    } else {
      // If for some reason state is not authenticated, check shared preferences fallback
      // but ideally we should have a name here.
      userName = 'Staff';
    }

    debugPrint('[POS] Finalizing sale for user: $userName');
    context.read<PosBloc>().add(ConfirmSale(method, userName));
    Navigator.pop(context);
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
            if (state.pendingExpensesAmount != null &&
                state.pendingExpensesAmount! > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFC5A028).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFC5A028).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '¡Buena venta! 💰',
                      style: TextStyle(
                        color: const Color(0xFFC5A028),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Te faltan \$${(state.pendingExpensesAmount! - state.dailySalesTotal).clamp(0, double.infinity).toStringAsFixed(2)} para cubrir tus gastos pendientes.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (state.pendingExpenseDescription != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '(Próximo pago: ${state.pendingExpenseDescription})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.lastConfirmedCustomer != null &&
                  state.lastConfirmedCustomer?.phone != null &&
                  state.lastConfirmedCustomer!.phone!.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {
                    if (state.lastConfirmedCustomer != null &&
                        state.lastConfirmedSale != null) {
                      _sendWhatsAppReceipt(
                        state.lastConfirmedCustomer!,
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

  Future<void> _sendWhatsAppReceipt(Customer customer, Sale sale) async {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('✂️ *Ticket Digital - Barber POS* ✂️');
    buffer.writeln('Hola *${customer.name}*, gracias por tu visita.');
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
    final String phone = (customer.phone ?? '').replaceAll(RegExp(r'\D'), '');
    // Ensure phone has at least a country code or handle common cases
    final String targetPhone = phone.startsWith('54') ? phone : '54$phone';
    final Uri url = Uri.parse('https://wa.me/$targetPhone?text=$message');
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
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.red),
            SizedBox(width: 8),
            Text('BORRAR DEUDA'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que el barbero ya pagó todo su consumo personal? '
          '\n\nEsta acción marcará todos los gastos pendientes como PAGADOS y el contador volverá a cero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ExpenseBloc>().add(SettleAllExpensesEvent(userName));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('SÍ, BORRAR TODO'),
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

  const _PaymentMethodButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.08),
            ),
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).cardColor,
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFC5A028), size: 36),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
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
  void dispose() {
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
