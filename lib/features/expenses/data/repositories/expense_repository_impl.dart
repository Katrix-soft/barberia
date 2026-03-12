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
  Future<Either<Failure, List<Expense>>> getExpenses([String? userName]) async {
    try {
      final db = await dbHelper.database;
      
      final List<Map<String, dynamic>> maps;
      if (userName != null) {
        maps = await db.query(
          'expenses',
          where: 'user_name = ?',
          whereArgs: [userName],
          orderBy: 'due_date ASC',
        );
      } else {
        maps = await db.query(
          'expenses',
          orderBy: 'due_date ASC',
        );
      }
      
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
      final map = model.toMap();
      if (model.id != null) {
        map.remove('id');
        await db.update(
          'expenses',
          map,
          where: 'id = ?',
          whereArgs: [model.id],
        );
      } else {
        map.remove('id');
        await db.insert('expenses', map);
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
