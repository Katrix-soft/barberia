import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/user_bloc.dart';
import '../bloc/user_event.dart';
import '../bloc/user_state.dart';
import '../../../../core/services/email_service.dart';
import '../../domain/entities/user.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import '../../../../core/database/database_helper.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  bool _isSendingEmail = false;

  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(LoadUsers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Personal')),
      body: BlocConsumer<UserBloc, UserState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == UserStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state.status == UserStatus.deleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Colaborador eliminado correctamente'),
                backgroundColor: Colors.black87,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == UserStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final authState = context.watch<AuthBloc>().state;
          final currentUser = authState is Authenticated ? authState.user : null;
          final bool isAdmin = currentUser?.role == UserRole.admin;
          final isHeadBarber = currentUser?.role == UserRole.headBarber;

          // Filter users: Head Barbers only see employees
          final visibleUsers = isHeadBarber 
              ? state.users.where((u) => u.role == UserRole.employee).toList()
              : state.users;

          return Column(
            children: [
              if (isAdmin)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.blue.withOpacity(0.1),
                  child: const Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'MODO OBSERVADOR: No puedes modificar el personal.',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
            itemCount: visibleUsers.length,
            itemBuilder: (context, index) {
              final user = visibleUsers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.role == UserRole.admin
                      ? Colors.deepPurple[50]
                      : user.role == UserRole.headBarber
                      ? Colors.orange[50]
                      : Colors.green[50],
                  child: Icon(
                    user.role == UserRole.admin
                        ? Icons.admin_panel_settings
                        : user.role == UserRole.headBarber
                        ? Icons.content_cut
                        : Icons.badge_outlined,
                    color: user.role == UserRole.admin
                        ? Colors.deepPurple
                        : user.role == UserRole.headBarber
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                title: Text(user.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user.email} - Rol: ${user.role == UserRole.admin ? 'Admin' : (user.role == UserRole.headBarber ? 'Barbero Jefe' : 'Barbero')}',
                    ),
                    if (user.dailyRate > 0)
                      Text(
                        'Pago Diario: \$${user.dailyRate.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.receipt_long_outlined, color: Colors.blueGrey),
                      tooltip: 'Pagar / Ver Recibos',
                      onPressed: () => _showPayrollDialog(context, user),
                    ),
                   ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isAdmin) ...[
                      IconButton(
                        icon: const Icon(Icons.receipt_long_outlined, color: Colors.blueGrey),
                        tooltip: 'Pagar / Ver Recibos',
                        onPressed: () => _showPayrollDialog(context, user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showUserDialog(context, user: user),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  },
),
floatingActionButton: BlocBuilder<AuthBloc, AuthState>(
  builder: (context, authState) {
    final bool isAdmin = authState is Authenticated && authState.user.role == UserRole.admin;
    if (isAdmin) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'history',
          onPressed: () => _showPayrollHistory(context),
          label: const Text('Historial Pagos'),
          icon: const Icon(Icons.history),
          backgroundColor: Colors.blueGrey,
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'add',
          onPressed: () => _showUserDialog(context),
          child: const Icon(Icons.person_add),
        ),
      ],
    );
  },
),
    );
  }

  void _showUserDialog(BuildContext context, {User? user}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user?.name ?? '');
    final usernameController = TextEditingController(
      text: user?.username ?? '',
    );
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    final dailyRateController = TextEditingController(
      text: user != null && user.dailyRate > 0 ? user.dailyRate.toStringAsFixed(0) : '',
    );
    UserRole selectedRole = user?.role ?? UserRole.employee;

    final authState = context.read<AuthBloc>().state;
    final currentUser = authState is Authenticated ? authState.user : null;
    final isHeadBarber = currentUser?.role == UserRole.headBarber;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return BlocListener<UserBloc, UserState>(
              listener: (context, state) {
                if (state.status == UserStatus.success) {
                  Navigator.pop(context); // Cerrar este dialogo
                  _showSuccessDialog(
                    context,
                    name: nameController.text,
                    username: usernameController.text,
                    password: passwordController.text.isNotEmpty 
                        ? passwordController.text 
                        : (user?.password ?? ''),
                    email: emailController.text,
                  );
                }
              },
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.badge, color: Color(0xFFC5A028)),
                              const SizedBox(width: 8),
                              Text(
                                user == null
                                    ? 'Nuevo Colaborador'
                                    : 'Editar Colaborador',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Nombre y Apellido *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Requerido'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: usernameController,
                            decoration: InputDecoration(
                              labelText: 'Nombre de Usuario *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(
                                Icons.account_circle_outlined,
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Requerido'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: emailController,
                            decoration: InputDecoration(
                              labelText: 'Correo Electrónico *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Requerido';
                              final emailRegex = RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              );
                              if (!emailRegex.hasMatch(value)) {
                                return 'Formato de email inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: passwordController,
                            decoration: InputDecoration(
                              labelText: user == null
                                  ? 'Contraseña *'
                                  : 'Nueva Contraseña (Opcional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (user == null &&
                                  (value == null || value.isEmpty)) {
                                return 'La contraseña es requerida para nuevos usuarios';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: dailyRateController,
                            decoration: InputDecoration(
                              labelText: 'Pago Diario \$ *',
                              hintText: 'Ej: 5000',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.payments_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Requerido'
                                : null,
                          ),
                          if (user != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final pwd = passwordController.text.isEmpty
                                      ? '(Tu contraseña actual)'
                                      : passwordController.text;
                                  
                                  final success = await EmailService.sendPasswordRecovery(
                                    toName: nameController.text,
                                    toEmail: emailController.text,
                                    username: usernameController.text,
                                    password: pwd,
                                  );
 
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success 
                                          ? 'Correo enviado correctamente.' 
                                          : 'Error al enviar correo.'),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.mail_outline, size: 18),
                                label: const Text('Enviar accesos por email'),
                              ),
                            ),
                          const SizedBox(height: 24),
                          const Text(
                            'Nivel de Acceso',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                RadioListTile<UserRole>(
                                  title: const Text(
                                    'Barbero / Empleado',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: const Text(
                                    'Acceso al POS unicamente',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  value: UserRole.employee,
                                  activeColor: const Color(0xFFC5A028),
                                  groupValue: selectedRole,
                                  onChanged: (val) =>
                                      setState(() => selectedRole = val!),
                                ),
                                if (!isHeadBarber) ...[
                                  const Divider(height: 1),
                                  RadioListTile<UserRole>(
                                    title: const Text(
                                      'Barbero Jefe',
                                      style: TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: const Text(
                                      'Acceso a POS y Reportes (Maneja su equipo)',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    value: UserRole.headBarber,
                                    activeColor: const Color(0xFFC5A028),
                                    groupValue: selectedRole,
                                    onChanged: (val) =>
                                        setState(() => selectedRole = val!),
                                  ),
                                  const Divider(height: 1),
                                  RadioListTile<UserRole>(
                                    title: const Text(
                                      'Administrador / Dueño',
                                      style: TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: const Text(
                                      'Acceso total y reportes',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    value: UserRole.admin,
                                    activeColor: const Color(0xFFC5A028),
                                    groupValue: selectedRole,
                                    onChanged: (val) =>
                                        setState(() => selectedRole = val!),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (user != null)
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      context.read<UserBloc>().add(
                                        DeleteUser(user.id!),
                                      );
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    style: TextButton.styleFrom(
                                      alignment: Alignment.centerLeft,
                                    ),
                                  ),
                                ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              BlocBuilder<UserBloc, UserState>(
                                builder: (context, state) {
                                  final isLoading = state.status == UserStatus.loading;
                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFC5A028),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: isLoading ? null : () async {
                                      if (formKey.currentState!.validate()) {
                                        final pwd = passwordController.text;
                                        final newUser = User(
                                          id: user?.id,
                                          name: nameController.text,
                                          username: usernameController.text,
                                          email: emailController.text,
                                          role: selectedRole,
                                          dailyRate: double.tryParse(dailyRateController.text) ?? 0.0,
                                          password: pwd.isNotEmpty ? pwd : user?.password,
                                        );
                                        
                                        context.read<UserBloc>().add(
                                          SaveUser(newUser, pwd),
                                        );
                                      }
                                    },
                                    child: isLoading 
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text(
                                          'Guardar',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(
    BuildContext context, {
    required String name,
    required String username,
    required String password,
    required String email,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFC5A028), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('¡PERSONAL GUARDADO!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Acceso listo para el colaborador:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            _buildDataRow('Nombre:', name),
            _buildDataRow('Usuario:', username),
            _buildDataRow('Contraseña:', password),
          ],
        ),
        actions: [
          StatefulBuilder(
            builder: (context, setDialogState) {
              return TextButton(
                onPressed: _isSendingEmail ? null : () async {
                  setDialogState(() => _isSendingEmail = true);
                  final success = await EmailService.sendPasswordRecovery(
                    toName: name,
                    toEmail: email,
                    username: username,
                    password: password,
                  );
                  setDialogState(() => _isSendingEmail = false);
                  
                  if (context.mounted) {
                    String message = success ? 'Email enviado correctamente vía Resend' : 'Error al enviar email.';
                    if (!success && EmailService.lastError.contains('testing emails')) {
                      message = 'Resend: Debes verificar tu dominio para enviar a barberos. Usa el botón COPIAR mientras tanto.';
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: success ? Colors.green : Colors.orange[800],
                        duration: const Duration(seconds: 4),
                        action: success ? null : SnackBarAction(
                          label: 'OK',
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    );
                  }
                },
                child: _isSendingEmail 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC5A028)))
                    : const Text('ENVIAR EMAIL', style: TextStyle(color: Color(0xFFC5A028))),
              );
            }
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC5A028),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final text = 'Hola $name, tus accesos son:\nUsuario: $username\nPass: $password\nApp: BM BARBER';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('¡Copiado para WhatsApp!'), backgroundColor: Colors.green),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('COPIAR DATOS'),
          ),
        ],
      ),
    );
  }

  void _showPayrollDialog(BuildContext context, User user) {
    final amountController = TextEditingController(text: user.dailyRate > 0 ? user.dailyRate.toStringAsFixed(0) : '');
    final notesController = TextEditingController();
    String paymentMethod = 'Efectivo';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Pagar Sueldo a ${user.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Text('Registrar pago diario para generar recibo.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                   const SizedBox(height: 16),
                   TextFormField(
                     controller: amountController,
                     decoration: const InputDecoration(labelText: 'Monto a Pagar \$', border: OutlineInputBorder()),
                     keyboardType: TextInputType.number,
                   ),
                   const SizedBox(height: 16),
                   DropdownButtonFormField<String>(
                     value: paymentMethod,
                     decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                     items: ['Efectivo', 'Transferencia', 'Mercado Pago'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                     onChanged: (val) => setDialogState(() => paymentMethod = val!),
                   ),
                   const SizedBox(height: 16),
                   TextFormField(
                     controller: notesController,
                     decoration: const InputDecoration(labelText: 'Notas / Observaciones', border: OutlineInputBorder()),
                     maxLines: 2,
                   ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A028), foregroundColor: Colors.white),
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (amount <= 0) return;

                    // In a real app we'd use a repository, but for speed let's record it
                    final db = await DatabaseHelper().database;
                    await db.insert('payroll', {
                      'user_id': user.id,
                      'user_name': user.name,
                      'date': DateTime.now().toIso8601String(),
                      'amount': amount,
                      'payment_method': paymentMethod,
                      'notes': notesController.text,
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      _showReceipt(context, user, amount, paymentMethod, notesController.text);
                    }
                  },
                  child: const Text('GENERAR RECIBO'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showReceipt(BuildContext context, User user, double amount, String method, String notes) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.content_cut, color: Colors.black, size: 30),
                  Text('RECIBO DE PAGO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 18)),
                ],
              ),
              const Divider(color: Colors.black),
              const SizedBox(height: 16),
              _receiptRow('Fecha:', dateStr),
              _receiptRow('Empleado:', user.name),
              _receiptRow('Cuil/Usuario:', user.username),
              _receiptRow('Método:', method),
              if (notes.isNotEmpty) _receiptRow('Detalle:', notes),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL PAGADO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    Text('\$${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text('___________________________', style: TextStyle(color: Colors.grey)),
              const Text('Firma del Responsable', style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('CERRAR'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                      onPressed: () {
                        // Copy as text for WhatsApp
                        final text = '*RECIBO DE PAGO - Katrix*\n\n'
                                   'Fecha: $dateStr\n'
                                   'Empleado: ${user.name}\n'
                                   'Método: $method\n'
                                   'Monto: \$${amount.toStringAsFixed(0)}\n'
                                   '--------------------------\n'
                                   'Gracias por tu trabajo.';
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Recibo copiado para WhatsApp!')));
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('COMPARTIR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showPayrollHistory(BuildContext context) async {
    final db = await DatabaseHelper().database;
    final history = await db.query('payroll', orderBy: 'date DESC');
    
    if (!context.mounted) return;

    // Calculate last month total
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, now.day);
    double lastMonthTotal = 0;
    for (var entry in history) {
      final date = DateTime.parse(entry['date'] as String);
      if (date.isAfter(lastMonth)) {
        lastMonthTotal += (entry['amount'] as num).toDouble();
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                   Icon(Icons.history, color: Color(0xFFC5A028)),
                   SizedBox(width: 8),
                   Text('Historial de Sueldos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Últimos 30 días:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${lastMonthTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: history.isEmpty 
                  ? const Center(child: Text('No hay registros de pagos aún.'))
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final date = DateTime.parse(item['date'] as String);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item['user_name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${date.day}/${date.month}/${date.year} - ${item['payment_method']}'),
                          trailing: Text('\$${(item['amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        );
                      },
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CERRAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
