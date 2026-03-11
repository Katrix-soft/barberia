import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/user_bloc.dart';
import '../bloc/user_event.dart';
import '../bloc/user_state.dart';
import '../../domain/entities/user.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
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
          } else if (state.status == UserStatus.loaded &&
              state.errorMessage == null) {
            // Operación exitosa
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
            return Dialog(
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
                          validator: (value) => value == null || value.isEmpty
                              ? 'Requerido'
                              : null,
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
                                    ? '(No se proporcionó nueva contraseña en este formulario, utiliza la que ya tenías)'
                                    : passwordController.text;
                                final Uri emailLaunchUri = Uri(
                                  scheme: 'mailto',
                                  path: emailController.text,
                                  queryParameters: {
                                    'subject': 'Tus accesos - Barber POS',
                                    'body':
                                        'Hola ${nameController.text},\n\nTus credenciales para ingresar son:\n\nUsuario o Correo: ${emailController.text}\nContraseña: $pwd\n\nSaludos.',
                                  },
                                );
                                try {
                                  await launchUrl(emailLaunchUri);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No se pudo abrir la app de correo',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.mail_outline, size: 18),
                              label: const Text('Enviar contraseña por correo'),
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
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC5A028),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  final isNewUser = user == null;
                                  final pwd = passwordController.text;

                                  final newUser = User(
                                    id: user?.id,
                                    name: nameController.text,
                                    username: usernameController.text,
                                    email: emailController.text,
                                    role: selectedRole,
                                  );
                                  context.read<UserBloc>().add(
                                    SaveUser(newUser, pwd),
                                  );

                                  if (isNewUser) {
                                    final Uri emailLaunchUri = Uri(
                                      scheme: 'mailto',
                                      path: emailController.text,
                                      queryParameters: {
                                        'subject':
                                            'Bienvenido a Posbarber - Tus Accesos',
                                        'body':
                                            'Hola ${nameController.text},\n\nTus credenciales temporales para ingresar al sistema son:\n\nUsuario o Correo: ${emailController.text}\nContraseña: $pwd\n\nIMPORTANTE: Por razones de seguridad, debes cambiar tu contraseña la primera vez que inicies sesion y habilitar el Inicio con Face ID / Huella desde tu perfil.\n\nSaludos.',
                                      },
                                    );
                                    launchUrl(
                                      emailLaunchUri,
                                    ).catchError((_) => false);
                                  }

                                  Navigator.pop(context);
                                }
                              },
                              child: const Text(
                                'Guardar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}
