import 'package:equatable/equatable.dart';
import '../../domain/entities/appointment.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

class LoadAppointments extends BookingEvent {}

class AddAppointment extends BookingEvent {
  final Appointment appointment;
  const AddAppointment(this.appointment);

  @override
  List<Object?> get props => [appointment];
}

class DeleteAppointmentEvent extends BookingEvent {
  final int id;
  const DeleteAppointmentEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateAppointmentStatus extends BookingEvent {
  final int id;
  final AppointmentStatus status;
  const UpdateAppointmentStatus(this.id, this.status);

  @override
  List<Object?> get props => [id, status];
}
