import 'package:equatable/equatable.dart';
import '../../domain/entities/product.dart';

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();
  @override
  List<Object?> get props => [];
}

class LoadInventory extends InventoryEvent {}

class SaveProduct extends InventoryEvent {
  final Product product;
  const SaveProduct(this.product);
  @override
  List<Object?> get props => [product];
}

class DeleteProduct extends InventoryEvent {
  final int id;
  const DeleteProduct(this.id);
  @override
  List<Object?> get props => [id];
}
