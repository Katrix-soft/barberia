import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'inventory_event.dart';
import 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository repository;

  InventoryBloc({required this.repository}) : super(const InventoryState()) {
    on<LoadInventory>(_onLoadInventory);
    on<SaveProduct>(_onSaveProduct);
    on<DeleteProduct>(_onDeleteProduct);
  }

  Future<void> _onLoadInventory(
    LoadInventory event,
    Emitter<InventoryState> emit,
  ) async {
    emit(state.copyWith(status: InventoryStatus.loading));
    final result = await repository.getProducts();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: InventoryStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (products) => emit(
        state.copyWith(status: InventoryStatus.loaded, products: products),
      ),
    );
  }

  Future<void> _onSaveProduct(
    SaveProduct event,
    Emitter<InventoryState> emit,
  ) async {
    emit(state.copyWith(status: InventoryStatus.loading));
    final result = await repository.saveProduct(event.product);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: InventoryStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) => add(LoadInventory()), // Refresh list
    );
  }

  Future<void> _onDeleteProduct(
    DeleteProduct event,
    Emitter<InventoryState> emit,
  ) async {
    emit(state.copyWith(status: InventoryStatus.loading));
    final result = await repository.deleteProduct(
      event.id,
    ); // Wait, event.id was fixed?
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: InventoryStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) => add(LoadInventory()), // Refresh list
    );
  }
}
