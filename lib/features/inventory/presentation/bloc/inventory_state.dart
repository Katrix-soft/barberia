import 'package:equatable/equatable.dart';
import '../../domain/entities/product.dart';

enum InventoryStatus { initial, loading, loaded, success, error }

class InventoryState extends Equatable {
  final InventoryStatus status;
  final List<Product> products;
  final String? errorMessage;

  const InventoryState({
    this.status = InventoryStatus.initial,
    this.products = const [],
    this.errorMessage,
  });

  InventoryState copyWith({
    InventoryStatus? status,
    List<Product>? products,
    String? errorMessage,
  }) {
    return InventoryState(
      status: status ?? this.status,
      products: products ?? this.products,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, products, errorMessage];
}
