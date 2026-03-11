import '../../domain/entities/appointment.dart';

class AppointmentModel extends Appointment {
  const AppointmentModel({
    super.id,
    super.customerId,
    required super.customerName,
    super.serviceId,
    required super.serviceName,
    required super.dateTime,
    super.status = AppointmentStatus.pending,
    super.notes,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'],
      customerId: map['customer_id'],
      customerName: map['customer_name'],
      serviceId: map['service_id'],
      serviceName: map['service_name'],
      dateTime: DateTime.parse(map['date_time']),
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'service_id': serviceId,
      'service_name': serviceName,
      'date_time': dateTime.toIso8601String(),
      'status': status.name,
      'notes': notes,
    };
  }

  factory AppointmentModel.fromEntity(Appointment entity) {
    return AppointmentModel(
      id: entity.id,
      customerId: entity.customerId,
      customerName: entity.customerName,
      serviceId: entity.serviceId,
      serviceName: entity.serviceName,
      dateTime: entity.dateTime,
      status: entity.status,
      notes: entity.notes,
    );
  }
}
