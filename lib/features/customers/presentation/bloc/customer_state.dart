import 'package:equatable/equatable.dart';
import '../../domain/entities/customer.dart';

enum CustomerStatus { initial, loading, loaded, success, error }

class CustomerState extends Equatable {
  final CustomerStatus status;
  final List<Customer> customers;
  final String? errorMessage;

  const CustomerState({
    this.status = CustomerStatus.initial,
    this.customers = const [],
    this.errorMessage,
  });

  CustomerState copyWith({
    CustomerStatus? status,
    List<Customer>? customers,
    String? errorMessage,
  }) {
    return CustomerState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, customers, errorMessage];
}
