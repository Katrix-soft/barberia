import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/pos_repository.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import 'pos_event.dart';
import 'pos_state.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  final PosRepository repository;
  final ExpenseRepository expenseRepository;
  String? _lastUserName;

  PosBloc({required this.repository, required this.expenseRepository})
    : super(const PosState()) {
    on<LoadPosData>(_onLoadPosData);
    on<AddProductToCart>(_onAddProductToCart);
    on<RemoveProductFromCart>(_onRemoveProductFromCart);
    on<UpdateItemQuantity>(_onUpdateItemQuantity);
    on<SelectCustomer>(_onSelectCustomer);
    on<ConfirmSale>(_onConfirmSale);
    on<ClearPos>(_onClearPos);
    on<SelectCategory>(_onSelectCategory);
  }

  Future<void> _onLoadPosData(LoadPosData event, Emitter<PosState> emit) async {
    _lastUserName = event.userName;
    emit(state.copyWith(status: PosStatus.loading));
    
    final productsResult = await repository.getProducts();
    final customersResult = await repository.getCustomers();
    final dailySalesResult = await repository.getDailySales(DateTime.now());
    
    // We load ALL expenses to populate the barberPendingBalance map
    // but the summary card will still be filtered in logic below.
    final allSalesResult = await repository.getSales();

    double dailyTotal = 0;
    dailySalesResult.fold((_) => null, (total) => dailyTotal = total);

    Map<String, double> barberSalesMap = {};
    Map<String, double> barberServiceSalesMap = {};
    double userDailySales = 0;
    
    allSalesResult.fold((_) => null, (sales) {
      final today = DateTime.now();
      final todaySales = sales.where((s) => 
        s.date.year == today.year && 
        s.date.month == today.month && 
        s.date.day == today.day &&
        s.paymentMethod != PaymentMethod.personal
      );
      
      for (var sale in todaySales) {
        final nameKey = sale.userName.trim().toLowerCase();
        barberSalesMap[nameKey] = (barberSalesMap[nameKey] ?? 0) + sale.total;
        
        double serviceTotal = 0;
        for (var item in sale.items) {
          if (item.isService) serviceTotal += item.total;
        }
        barberServiceSalesMap[nameKey] = (barberServiceSalesMap[nameKey] ?? 0) + serviceTotal;

        if (event.userName != null && nameKey == event.userName!.trim().toLowerCase()) {
          userDailySales += sale.total;
        }
      }
    });

    // Load all expenses to populate the map for all barbers (Head Barber needs this)
    final allExpensesResult = await expenseRepository.getExpenses();
    Map<String, double> barberPendingBalanceMap = {};
    double pendingAmount = 0;
    double totalExpenses = 0;
    String? nextExpense;

    allExpensesResult.fold((_) => null, (expenses) {
      // 1. Populate the global map for all barbers
      for (var e in expenses) {
        if (!e.isPaid) {
          final nameKey = e.userName.trim().toLowerCase();
          barberPendingBalanceMap[nameKey] = (barberPendingBalanceMap[nameKey] ?? 0) + e.amount;
        }
      }

      // 2. Extract metrics for the current user summary
      final String? normalizedCurrentName = event.userName?.trim().toLowerCase();
      
      final currentUserExpenses = expenses.where((e) {
        final String expenseUserName = e.userName.trim().toLowerCase();
        if (normalizedCurrentName == null) {
          return expenseUserName == 'admin';
        }
        return expenseUserName == normalizedCurrentName;
      }).toList();

      final pending = currentUserExpenses.where((e) => !e.isPaid && e.category == 'Consumo Personal').toList();
      pendingAmount = pending.fold(0, (sum, e) => sum + e.amount);
      totalExpenses = currentUserExpenses.fold(0, (sum, e) => sum + e.amount);
      if (pending.isNotEmpty) {
        pending.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        nextExpense = pending.first.description;
      }
    });

    productsResult.fold(
      (failure) => emit(
        state.copyWith(status: PosStatus.error, errorMessage: failure.message),
      ),
      (products) => customersResult.fold(
        (failure) => emit(
          state.copyWith(
            status: PosStatus.error,
            errorMessage: failure.message,
          ),
        ),
        (customers) {
          final uniqueCategories = {'Todos'};
          for (var p in products) {
            if (p.category.isNotEmpty) uniqueCategories.add(p.category);
          }
          final availCats = uniqueCategories.toList();

          final filtered = state.selectedCategory == 'Todos'
              ? products
              : products
                    .where((p) => p.category == state.selectedCategory)
                    .toList();

          emit(
            state.copyWith(
              status: PosStatus.loaded,
              products: products,
              availableCategories: availCats,
              filteredProducts: filtered,
              customers: customers,
              dailySalesTotal: dailyTotal,
              pendingExpensesAmount: pendingAmount,
              pendingExpenseDescription: nextExpense,
              pendingTotalExpenses: totalExpenses,
              barberSales: barberSalesMap,
              barberServiceSales: barberServiceSalesMap,
              barberPendingBalance: barberPendingBalanceMap,
              currentUserDailySales: userDailySales,
            ),
          );
        },
      ),
    );
  }

  void _onAddProductToCart(AddProductToCart event, Emitter<PosState> emit) {
    if (!event.product.isService && event.product.stock <= 0) {
      emit(
        state.copyWith(
          status: PosStatus.error,
          errorMessage: 'Sin stock suficiente para ${event.product.name}',
        ),
      );
      emit(
        state.copyWith(
          status: PosStatus.loaded,
          errorMessage: null,
          clearCustomer: false,
        ),
      );
      return;
    }

    final existingItemIndex = state.cartItems.indexWhere(
      (item) => item.productId == event.product.id,
    );
    final List<SaleItem> updatedCart = List.from(state.cartItems);

    if (existingItemIndex != -1) {
      final existingItem = updatedCart[existingItemIndex];
      if (!event.product.isService &&
          existingItem.quantity >= event.product.stock) {
        emit(
          state.copyWith(
            status: PosStatus.error,
            errorMessage: 'Sin stock suficiente para ${event.product.name}',
          ),
        );
        emit(
          state.copyWith(
            status: PosStatus.loaded,
            errorMessage: null,
            clearCustomer: false,
          ),
        );
        return;
      }
      updatedCart[existingItemIndex] = SaleItem(
        productId: existingItem.productId,
        productName: existingItem.productName,
        quantity: existingItem.quantity + 1,
        price: existingItem.price,
        total: (existingItem.quantity + 1) * existingItem.price,
        isService: existingItem.isService,
      );
    } else {
      updatedCart.add(
        SaleItem(
          productId: event.product.id!,
          productName: event.product.name,
          quantity: 1,
          price: event.product.price,
          total: event.product.price,
          isService: event.product.isService,
        ),
      );
    }
    emit(state.copyWith(cartItems: updatedCart));
  }

  void _onRemoveProductFromCart(
    RemoveProductFromCart event,
    Emitter<PosState> emit,
  ) {
    final updatedCart = state.cartItems
        .where((item) => item.productId != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedCart));
  }

  void _onUpdateItemQuantity(UpdateItemQuantity event, Emitter<PosState> emit) {
    final List<SaleItem> updatedCart = List.from(state.cartItems);
    final index = updatedCart.indexWhere(
      (item) => item.productId == event.productId,
    );

    if (index != -1) {
      if (event.quantity <= 0) {
        updatedCart.removeAt(index);
      } else {
        final product = state.products.firstWhere(
          (p) => p.id == event.productId,
        );
        if (!product.isService && event.quantity > product.stock) {
          emit(
            state.copyWith(
              status: PosStatus.error,
              errorMessage: 'Sin stock suficiente para ${product.name}',
            ),
          );
          emit(
            state.copyWith(
              status: PosStatus.loaded,
              errorMessage: null,
              clearCustomer: false,
            ),
          );
          return;
        }

        final item = updatedCart[index];
        updatedCart[index] = SaleItem(
          productId: item.productId,
          productName: item.productName,
          quantity: event.quantity,
          price: item.price,
          total: event.quantity * item.price,
          isService: item.isService,
        );
      }
      emit(state.copyWith(cartItems: updatedCart));
    }
  }

  void _onSelectCustomer(SelectCustomer event, Emitter<PosState> emit) {
    emit(
      state.copyWith(
        selectedCustomer: event.customer,
        clearCustomer: event.customer == null,
      ),
    );
  }

  Future<void> _onConfirmSale(ConfirmSale event, Emitter<PosState> emit) async {
    if (state.cartItems.isEmpty) return;

    emit(state.copyWith(status: PosStatus.loading));

    final sale = Sale(
      customerId: state.selectedCustomer?.id,
      customerName: state.selectedCustomer?.name,
      date: DateTime.now(),
      total: state.total,
      paymentMethod: event.paymentMethod,
      userName: event.userName,
      items: state.cartItems,
      externalReference: event.externalReference,
      isPaid: event.paymentMethod == PaymentMethod.qr ? false : true, // QR starts unpaid until webhook
    );

    final result = await repository.createSale(sale);

    await result.fold(
      (failure) async => emit(
        state.copyWith(status: PosStatus.error, errorMessage: failure.message),
      ),
      (saleId) async {
        emit(
          state.copyWith(
            status: PosStatus.success,
            lastSaleId: saleId,
            lastConfirmedCustomer: state.selectedCustomer,
            lastConfirmedSale: sale,
            cartItems: [],
            selectedCustomer: null,
            clearCustomer: true,
          ),
        );
        add(LoadPosData(userName: _lastUserName));
      },
    );
  }

  void _onClearPos(ClearPos event, Emitter<PosState> emit) {
    emit(
      state.copyWith(
        cartItems: [],
        selectedCustomer: null,
        clearCustomer: true,
        status: PosStatus.loaded,
      ),
    );
  }

  void _onSelectCategory(SelectCategory event, Emitter<PosState> emit) {
    final filtered = event.category == 'Todos'
        ? state.products
        : state.products.where((p) => p.category == event.category).toList();

    emit(
      state.copyWith(
        selectedCategory: event.category,
        filteredProducts: filtered,
      ),
    );
  }
}
