import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import 'expense_event.dart';
import 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final ExpenseRepository repository;

  ExpenseBloc({required this.repository}) : super(const ExpenseState()) {
    on<LoadExpenses>(_onLoadExpenses);
    on<AddExpenseEvent>(_onAddExpense);
    on<DeleteExpenseEvent>(_onDeleteExpense);
    on<ToggleExpensePaidEvent>(_onToggleExpensePaid);
  }

  Future<void> _onLoadExpenses(
    LoadExpenses event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseStatus.loading));
    final result = await repository.getExpenses();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ExpenseStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (expenses) => emit(
        state.copyWith(status: ExpenseStatus.loaded, expenses: expenses),
      ),
    );
  }

  Future<void> _onAddExpense(
    AddExpenseEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseStatus.loading));
    final result = await repository.saveExpense(event.expense);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ExpenseStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) {
        emit(state.copyWith(status: ExpenseStatus.success));
        add(LoadExpenses());
      },
    );
  }

  Future<void> _onDeleteExpense(
    DeleteExpenseEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    final result = await repository.deleteExpense(event.id);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ExpenseStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) => add(LoadExpenses()),
    );
  }

  Future<void> _onToggleExpensePaid(
    ToggleExpensePaidEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    final updated = Expense(
      id: event.expense.id,
      description: event.expense.description,
      amount: event.expense.amount,
      dueDate: event.expense.dueDate,
      category: event.expense.category,
      isPaid: !event.expense.isPaid,
    );
    final result = await repository.saveExpense(updated);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ExpenseStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) {
        emit(
          state.copyWith(
            status: ExpenseStatus.success,
            lastUpdatedExpense: updated,
          ),
        );
        add(LoadExpenses());
      },
    );
  }
}
