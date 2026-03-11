import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import '../../domain/entities/appointment.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  @override
  void initState() {
    super.initState();
    context.read<BookingBloc>().add(LoadAppointments());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agenda de Turnos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: BlocBuilder<BookingBloc, BookingState>(
        builder: (context, state) {
          if (state.status == BookingStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.appointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay turnos programados',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.appointments.length,
            itemBuilder: (context, index) {
              final appointment = state.appointments[index];
              return _buildAppointmentCard(appointment);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAppointmentDialog(context),
        backgroundColor: const Color(0xFFC5A028),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Turno'),
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final Color statusColor = appointment.status == AppointmentStatus.completed
        ? Colors.green
        : appointment.status == AppointmentStatus.cancelled
        ? Colors.red
        : const Color(0xFFC5A028);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person, color: statusColor),
        ),
        title: Text(
          appointment.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              appointment.serviceName,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(appointment.dateTime),
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<AppointmentStatus>(
          initialValue: appointment.status,
          onSelected: (status) {
            context.read<BookingBloc>().add(
              UpdateAppointmentStatus(appointment.id!, status),
            );
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: AppointmentStatus.pending,
              child: Text('Pendiente'),
            ),
            const PopupMenuItem(
              value: AppointmentStatus.completed,
              child: Text('Completado'),
            ),
            const PopupMenuItem(
              value: AppointmentStatus.cancelled,
              child: Text('Cancelado'),
            ),
            PopupMenuItem(
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => context.read<BookingBloc>().add(
                DeleteAppointmentEvent(appointment.id!),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              appointment.status.name.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAppointmentDialog(BuildContext context) async {
    // Simplification: Using controllers for text if Bloc states are not ready or empty
    final nameController = TextEditingController();
    final serviceController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Programar Turno'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Cliente',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: serviceController,
                  decoration: const InputDecoration(
                    labelText: 'Servicio / Tratamiento',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Fecha'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setDialogState(() => selectedDate = date);
                  },
                ),
                ListTile(
                  title: const Text('Hora'),
                  subtitle: Text(selectedTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) setDialogState(() => selectedTime = time);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    serviceController.text.isEmpty) {
                  return;
                }

                final finalDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                context.read<BookingBloc>().add(
                  AddAppointment(
                    Appointment(
                      customerName: nameController.text,
                      serviceName: serviceController.text,
                      dateTime: finalDateTime,
                    ),
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
