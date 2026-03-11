import 'package:equatable/equatable.dart';
import '../../domain/entities/appointment.dart';

enum BookingStatus { initial, loading, loaded, success, error }

class BookingState extends Equatable {
  final BookingStatus status;
  final List<Appointment> appointments;
  final String? errorMessage;

  const BookingState({
    this.status = BookingStatus.initial,
    this.appointments = const [],
    this.errorMessage,
  });

  BookingState copyWith({
    BookingStatus? status,
    List<Appointment>? appointments,
    String? errorMessage,
  }) {
    return BookingState(
      status: status ?? this.status,
      appointments: appointments ?? this.appointments,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, appointments, errorMessage];
}
