import 'package:equatable/equatable.dart';
import '../../domain/entities/expense.dart';

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();

  @override
  List<Object?> get props => [];
}

class LoadExpenses extends ExpenseEvent {
  final String? userName;
  const LoadExpenses({this.userName});

  @override
  List<Object?> get props => [userName];
}

class AddExpenseEvent extends ExpenseEvent {
  final Expense expense;
  const AddExpenseEvent(this.expense);

  @override
  List<Object?> get props => [expense];
}

class DeleteExpenseEvent extends ExpenseEvent {
  final int id;
  const DeleteExpenseEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class ToggleExpensePaidEvent extends ExpenseEvent {
  final Expense expense;
  const ToggleExpensePaidEvent(this.expense);

  @override
  List<Object?> get props => [expense];
}

class SettleAllExpensesEvent extends ExpenseEvent {
  final String userName;
  const SettleAllExpensesEvent(this.userName);

  @override
  List<Object?> get props => [userName];
}
