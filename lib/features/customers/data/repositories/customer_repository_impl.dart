import 'package:dartz/dartz.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_model.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final DatabaseHelper databaseHelper;

  CustomerRepositoryImpl({required this.databaseHelper});

  @override
  Future<Either<Failure, List<Customer>>> getCustomers() async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'customers',
        orderBy: 'name ASC',
      );
      return Right(maps.map((m) => CustomerModel.fromMap(m)).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveCustomer(Customer customer) async {
    try {
      final db = await databaseHelper.database;
      final customerModel = CustomerModel(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        points: customer.points,
        notes: customer.notes,
      );

      if (customer.id == null) {
        await db.insert('customers', customerModel.toMap());
      } else {
        final map = customerModel.toMap();
        map.remove('id');
        await db.update(
          'customers',
          map,
          where: 'id = ?',
          whereArgs: [customer.id],
        );
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
