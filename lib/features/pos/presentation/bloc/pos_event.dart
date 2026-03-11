import 'package:equatable/equatable.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../domain/entities/sale.dart';

abstract class PosEvent extends Equatable {
  const PosEvent();

  @override
  List<Object?> get props => [];
}

class LoadPosData extends PosEvent {}

class AddProductToCart extends PosEvent {
  final Product product;
  const AddProductToCart(this.product);

  @override
  List<Object?> get props => [product];
}

class RemoveProductFromCart extends PosEvent {
  final int productId;
  const RemoveProductFromCart(this.productId);

  @override
  List<Object?> get props => [productId];
}

class UpdateItemQuantity extends PosEvent {
  final int productId;
  final int quantity;
  const UpdateItemQuantity(this.productId, this.quantity);

  @override
  List<Object?> get props => [productId, quantity];
}

class SelectCustomer extends PosEvent {
  final Customer? customer;
  const SelectCustomer(this.customer);

  @override
  List<Object?> get props => [customer];
}

class ConfirmSale extends PosEvent {
  final PaymentMethod paymentMethod;
  final String userName;
  const ConfirmSale(this.paymentMethod, this.userName);

  @override
  List<Object?> get props => [paymentMethod, userName];
}

class ClearPos extends PosEvent {}

class SelectCategory extends PosEvent {
  final String category;
  const SelectCategory(this.category);

  @override
  List<Object?> get props => [category];
}
