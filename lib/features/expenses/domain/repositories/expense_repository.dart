import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<Either<Failure, List<Expense>>> getExpenses([String? userName]);
  Future<Either<Failure, void>> saveExpense(Expense expense);
  Future<Either<Failure, void>> deleteExpense(int id);
  Future<Either<Failure, void>> settleAllPendingExpenses(String userName);
}
