import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/appointment.dart';

abstract class BookingRepository {
  Future<Either<Failure, List<Appointment>>> getAppointments();
  Future<Either<Failure, int>> saveAppointment(Appointment appointment);
  Future<Either<Failure, void>> deleteAppointment(int id);
}
