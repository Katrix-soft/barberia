import 'package:equatable/equatable.dart';

enum AppointmentStatus { pending, completed, cancelled, paid }

class Appointment extends Equatable {
  final int? id;
  final int? customerId;
  final String customerName;
  final int? serviceId;
  final String serviceName;
  final DateTime dateTime;
  final AppointmentStatus status;
  final String? notes;
  final String? paymentMethod;
  final DateTime? paidAt;

  const Appointment({
    this.id,
    this.customerId,
    required this.customerName,
    this.serviceId,
    required this.serviceName,
    required this.dateTime,
    this.status = AppointmentStatus.pending,
    this.notes,
    this.paymentMethod,
    this.paidAt,
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
    paymentMethod,
    paidAt,
  ];
}
