import 'package:dartz/dartz.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/error/failures.dart';
import '../models/appointment_model.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  final DatabaseHelper dbHelper;

  BookingRepositoryImpl({required this.dbHelper});

  @override
  Future<Either<Failure, List<Appointment>>> getAppointments() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'appointments',
        orderBy: 'date_time ASC',
      );
      return Right(maps.map((map) => AppointmentModel.fromMap(map)).toList());
    } catch (e) {
      return Left(DatabaseFailure('Error al cargar turnos: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> saveAppointment(Appointment appointment) async {
    try {
      final db = await dbHelper.database;
      final model = AppointmentModel.fromEntity(appointment);
      if (model.id != null) {
        await db.update(
          'appointments',
          model.toMap(),
          where: 'id = ?',
          whereArgs: [model.id],
        );
        return Right(model.id!);
      } else {
        final id = await db.insert('appointments', model.toMap());
        return Right(id);
      }
    } catch (e) {
      return Left(DatabaseFailure('Error al guardar turno: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAppointment(int id) async {
    try {
      final db = await dbHelper.database;
      await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Error al eliminar turno: $e'));
    }
  }
}
