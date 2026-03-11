import 'package:equatable/equatable.dart';
import '../../domain/entities/expense.dart';

enum ExpenseStatus { initial, loading, loaded, success, error }

class ExpenseState extends Equatable {
  final ExpenseStatus status;
  final List<Expense> expenses;
  final String? errorMessage;
  final Expense? lastUpdatedExpense;

  const ExpenseState({
    this.status = ExpenseStatus.initial,
    this.expenses = const [],
    this.errorMessage,
    this.lastUpdatedExpense,
  });

  ExpenseState copyWith({
    ExpenseStatus? status,
    List<Expense>? expenses,
    String? errorMessage,
    Expense? lastUpdatedExpense,
  }) {
    return ExpenseState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      errorMessage: errorMessage ?? this.errorMessage,
      lastUpdatedExpense: lastUpdatedExpense ?? this.lastUpdatedExpense,
    );
  }

  double get totalPending =>
      expenses.where((e) => !e.isPaid).fold(0, (sum, e) => sum + e.amount);

  @override
  List<Object?> get props => [
    status,
    expenses,
    errorMessage,
    lastUpdatedExpense,
  ];
}
