import 'package:equatable/equatable.dart';

enum AppointmentStatus { pending, completed, cancelled }

class Appointment extends Equatable {
  final int? id;
  final int? customerId;
  final String customerName;
  final int? serviceId;
  final String serviceName;
  final DateTime dateTime;
  final AppointmentStatus status;
  final String? notes;

  const Appointment({
    this.id,
    this.customerId,
    required this.customerName,
    this.serviceId,
    required this.serviceName,
    required this.dateTime,
    this.status = AppointmentStatus.pending,
    this.notes,
  });

  @override
  List<Object?> get props => [
    id,
    customerId,
    customerName,
    serviceId,
    serviceName,
    dateTime,
    status,
    notes,
  ];
}
