import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/entities/appointment.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository repository;

  BookingBloc({required this.repository}) : super(const BookingState()) {
    on<LoadAppointments>(_onLoadAppointments);
    on<AddAppointment>(_onAddAppointment);
    on<DeleteAppointmentEvent>(_onDeleteAppointment);
    on<UpdateAppointmentStatus>(_onUpdateAppointmentStatus);
  }

  Future<void> _onLoadAppointments(
    LoadAppointments event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(status: BookingStatus.loading));
    final result = await repository.getAppointments();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BookingStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (appointments) => emit(
        state.copyWith(
          status: BookingStatus.loaded,
          appointments: appointments,
        ),
      ),
    );
  }

  Future<void> _onAddAppointment(
    AddAppointment event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(status: BookingStatus.loading));
    final result = await repository.saveAppointment(event.appointment);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BookingStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) {
        emit(state.copyWith(status: BookingStatus.success));
        add(LoadAppointments());
      },
    );
  }

  Future<void> _onDeleteAppointment(
    DeleteAppointmentEvent event,
    Emitter<BookingState> emit,
  ) async {
    final result = await repository.deleteAppointment(event.id);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BookingStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) => add(LoadAppointments()),
    );
  }

  Future<void> _onUpdateAppointmentStatus(
    UpdateAppointmentStatus event,
    Emitter<BookingState> emit,
  ) async {
    // Find the appointment first
    final appointment = state.appointments.firstWhere((a) => a.id == event.id);
    final updatedAppointment = Appointment(
      id: appointment.id,
      customerId: appointment.customerId,
      customerName: appointment.customerName,
      serviceId: appointment.serviceId,
      serviceName: appointment.serviceName,
      dateTime: appointment.dateTime,
      status: event.status,
      notes: appointment.notes,
    );

    final result = await repository.saveAppointment(updatedAppointment);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BookingStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) => add(LoadAppointments()),
    );
  }
}
