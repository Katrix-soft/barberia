import 'package:equatable/equatable.dart';
import '../../domain/entities/customer.dart';

abstract class CustomerEvent extends Equatable {
  const CustomerEvent();
  @override
  List<Object?> get props => [];
}

class LoadCustomers extends CustomerEvent {}

class SaveCustomer extends CustomerEvent {
  final Customer customer;
  const SaveCustomer(this.customer);
  @override
  List<Object?> get props => [customer];
}
