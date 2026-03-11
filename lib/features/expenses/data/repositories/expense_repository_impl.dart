import 'package:dartz/dartz.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/error/failures.dart';
import '../models/expense_model.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final DatabaseHelper dbHelper;

  ExpenseRepositoryImpl({required this.dbHelper});

  @override
  Future<Either<Failure, List<Expense>>> getExpenses() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'expenses',
        orderBy: 'due_date ASC',
      );
      return Right(maps.map((map) => ExpenseModel.fromMap(map)).toList());
    } catch (e) {
      return Left(DatabaseFailure('Error al cargar gastos: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveExpense(Expense expense) async {
    try {
      final db = await dbHelper.database;
      final model = ExpenseModel.fromEntity(expense);
      if (model.id != null) {
        await db.update(
          'expenses',
          model.toMap(),
          where: 'id = ?',
          whereArgs: [model.id],
        );
      } else {
        await db.insert('expenses', model.toMap());
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Error al guardar gasto: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExpense(int id) async {
    try {
      final db = await dbHelper.database;
      await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Error al eliminar gasto: $e'));
    }
  }
}
