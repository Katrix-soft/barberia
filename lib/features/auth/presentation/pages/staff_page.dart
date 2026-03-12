import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/user_bloc.dart';
import '../bloc/user_event.dart';
import '../bloc/user_state.dart';
import '../../../../core/services/email_service.dart';
import '../../domain/entities/user.dart';

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
          } else if (state.status == UserStatus.loaded) {
            // Ya no necesitamos snackbar aquí porque lo manejamos en el botón
          }
        },
        builder: (context, state) {
          if (state.status == UserStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: state.users.length,
            itemBuilder: (context, index) {
              final user = state.users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.role == UserRole.admin
                      ? Colors.deepPurple[50]
                      : user.role == UserRole.headBarber
                      ? Colors.orange[50]
                      : Colors.grey[100],
                  child: Icon(
                    user.role == UserRole.admin
                        ? Icons.admin_panel_settings
                        : user.role == UserRole.headBarber
                        ? Icons.content_cut
                        : Icons.person,
                    color: user.role == UserRole.admin
                        ? Colors.deepPurple
                        : user.role == UserRole.headBarber
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ),
                title: Text(user.name),
                subtitle: Text(
                  '${user.email} - Rol: ${user.role == UserRole.admin ? 'Admin' : (user.role == UserRole.headBarber ? 'Barbero Jefe' : 'Empleado')}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showUserDialog(context, user: user),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(context),
        child: const Icon(Icons.person_add),
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
    UserRole selectedRole = user?.role ?? UserRole.employee;

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
                                const Divider(height: 1),
                                RadioListTile<UserRole>(
                                  title: const Text(
                                    'Barbero Jefe',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: const Text(
                                    'Acceso a POS y Reportes (Sin permisos de dueño)',
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

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}
