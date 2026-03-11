import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/customer_repository.dart';
import 'customer_event.dart';
import 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final CustomerRepository repository;

  CustomerBloc({required this.repository}) : super(const CustomerState()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<SaveCustomer>(_onSaveCustomer);
  }

  Future<void> _onLoadCustomers(
    LoadCustomers event,
    Emitter<CustomerState> emit,
  ) async {
    emit(state.copyWith(status: CustomerStatus.loading));
    final result = await repository.getCustomers();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CustomerStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (customers) => emit(
        state.copyWith(status: CustomerStatus.loaded, customers: customers),
      ),
    );
  }

  Future<void> _onSaveCustomer(
    SaveCustomer event,
    Emitter<CustomerState> emit,
  ) async {
    emit(state.copyWith(status: CustomerStatus.loading));
    final result = await repository.saveCustomer(event.customer);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CustomerStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) => add(LoadCustomers()), // Refresh list
    );
  }
}
