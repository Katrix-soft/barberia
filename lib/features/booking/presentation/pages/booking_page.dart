import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import '../../domain/entities/appointment.dart';
import '../../../../core/database/database_helper.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  String _selectedFilter = 'Todos';
  List<Map<String, dynamic>> _barbers = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _customers = [];

  @override
  void initState() {
    super.initState();
    context.read<BookingBloc>().add(LoadAppointments());
    _loadSelections();
  }

  Future<void> _loadSelections() async {
    try {
      final db = await DatabaseHelper().database;
      final users = await db.query('users', where: "role != 'admin'");
      final services = await db.query('products', where: 'is_service = 1');
      final customers = await db.query('customers');
      setState(() {
        _barbers = users;
        _services = services;
        _customers = customers;
      });
    } catch (e) {
      debugPrint('[DB] Error al cargar selecciones para turnos: $e');
    }
  }

  List<Appointment> _getFilteredAppointments(List<Appointment> appointments) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return appointments.where((appointment) {
      final appDate = DateTime(appointment.dateTime.year, appointment.dateTime.month, appointment.dateTime.day);
      if (_selectedFilter == 'Hoy') {
        return appDate.isAtSameMomentAs(today);
      } else if (_selectedFilter == 'Mañana') {
        return appDate.isAtSameMomentAs(tomorrow);
      } else if (_selectedFilter == 'Esta Semana') {
        return appDate.isAfter(today.subtract(const Duration(days: 1))) &&
            appDate.isBefore(today.add(const Duration(days: 7)));
      }
      return true;
    }).toList();
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
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: BlocBuilder<BookingBloc, BookingState>(
              builder: (context, state) {
                if (state.status == BookingStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filtered = _getFilteredAppointments(state.appointments);

                if (filtered.isEmpty) {
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
                        Text(
                          _selectedFilter == 'Todos'
                              ? 'No hay turnos programados'
                              : 'No hay turnos para: $_selectedFilter',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final appointment = filtered[index];
                    return _buildAppointmentCard(appointment);
                  },
                );
              },
            ),
          ),
        ],
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

  Widget _buildFilterBar() {
    final filters = ['Todos', 'Hoy', 'Mañana', 'Esta Semana'];
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFC5A028),
              backgroundColor: Colors.grey[200],
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final Color statusColor = appointment.status == AppointmentStatus.completed
        ? Colors.green
        : appointment.status == AppointmentStatus.cancelled
        ? Colors.red
        : appointment.status == AppointmentStatus.paid
        ? Colors.blue
        : const Color(0xFFC5A028);

    String statusLabel = 'PENDIENTE';
    switch (appointment.status) {
      case AppointmentStatus.completed: statusLabel = 'COMPLETADO'; break;
      case AppointmentStatus.cancelled: statusLabel = 'CANCELADO'; break;
      case AppointmentStatus.paid: statusLabel = 'PAGADO'; break;
      case AppointmentStatus.pending: statusLabel = 'PENDIENTE'; break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    appointment.status == AppointmentStatus.paid
                        ? Icons.check_circle_outline
                        : Icons.calendar_today,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appointment.serviceName,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<AppointmentStatus>(
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
                      value: AppointmentStatus.paid,
                      child: Text('Pagado'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: statusColor, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Assigned Barber Badge
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      appointment.barberName ?? 'Sin asignar',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                // Date & Time
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM HH:mm').format(appointment.dateTime),
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (appointment.status == AppointmentStatus.paid) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.blue),
                    ],
                  ],
                ),
              ],
            ),
            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        appointment.notes!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddAppointmentDialog(BuildContext context) {
    String? selectedBarber;
    String? selectedService;
    String? selectedCustomer;
    final newCustomerNameController = TextEditingController();
    final notesController = TextEditingController();
    bool isNewCustomer = false;

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Programar Turno',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A028)),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Registrado', style: TextStyle(fontSize: 12)),
                          selected: !isNewCustomer,
                          onSelected: (val) {
                            setDialogState(() => isNewCustomer = !val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Nuevo', style: TextStyle(fontSize: 12)),
                          selected: isNewCustomer,
                          onSelected: (val) {
                            setDialogState(() => isNewCustomer = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isNewCustomer)
                    TextField(
                      controller: newCustomerNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Cliente',
                        prefixIcon: const Icon(Icons.person_add_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedCustomer,
                      decoration: InputDecoration(
                        labelText: 'Seleccionar Cliente',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _customers.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['name'] as String,
                          child: Text(c['name'] as String),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedCustomer = val);
                      },
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedService,
                    decoration: InputDecoration(
                      labelText: 'Servicio / Tratamiento',
                      prefixIcon: const Icon(Icons.content_cut),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _services.map((s) {
                      return DropdownMenuItem<String>(
                        value: s['name'] as String,
                        child: Text('${s['name']} (\$${s['price']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedService = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBarber,
                    decoration: InputDecoration(
                      labelText: 'Asignar Barbero',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _barbers.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['name'] as String,
                        child: Text(b['name'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedBarber = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.grey[100],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            title: const Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                            trailing: const Icon(Icons.calendar_today, color: Color(0xFFC5A028)),
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
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            title: const Text('Hora', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(selectedTime.format(context)),
                            trailing: const Icon(Icons.access_time, color: Color(0xFFC5A028)),
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
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notas (Opcional)',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC5A028),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final customerName = isNewCustomer ? newCustomerNameController.text : selectedCustomer;
                if (customerName == null || customerName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, selecciona o ingresa un cliente')),
                  );
                  return;
                }
                if (selectedService == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, selecciona un servicio')),
                  );
                  return;
                }
                if (selectedBarber == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, asigna un barbero')),
                  );
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
                      customerName: customerName,
                      serviceName: selectedService!,
                      barberName: selectedBarber,
                      dateTime: finalDateTime,
                      notes: notesController.text.isNotEmpty ? notesController.text : null,
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
