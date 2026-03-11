import 'package:equatable/equatable.dart';
import '../../domain/entities/sale.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../customers/domain/entities/customer.dart';

enum PosStatus { initial, loading, loaded, success, error }

class PosState extends Equatable {
  final PosStatus status;
  final List<Product> products;
  final List<Customer> customers;
  final List<SaleItem> cartItems;
  final Customer? selectedCustomer;
  final Customer? lastConfirmedCustomer;
  final Sale? lastConfirmedSale;
  final String? errorMessage;
  final int? lastSaleId;
  final String selectedCategory;
  final double? pendingExpensesAmount;
  final String? pendingExpenseDescription;
  final double dailySalesTotal;
  final double pendingTotalExpenses;
  final List<String> availableCategories;
  final List<Product> filteredProducts;

  const PosState({
    this.status = PosStatus.initial,
    this.products = const [],
    this.customers = const [],
    this.cartItems = const [],
    this.selectedCustomer,
    this.lastConfirmedCustomer,
    this.lastConfirmedSale,
    this.errorMessage,
    this.lastSaleId,
    this.selectedCategory = 'Todos',
    this.pendingExpensesAmount,
    this.pendingExpenseDescription,
    this.dailySalesTotal = 0.0,
    this.pendingTotalExpenses = 0.0,
    this.availableCategories = const ['Todos'],
    this.filteredProducts = const [],
  });

  double get total => cartItems.fold(0, (sum, item) => sum + item.total);
  int get cartCount => cartItems.fold(0, (sum, item) => sum + item.quantity);

  PosState copyWith({
    PosStatus? status,
    List<Product>? products,
    List<Customer>? customers,
    List<SaleItem>? cartItems,
    Customer? selectedCustomer,
    Customer? lastConfirmedCustomer,
    Sale? lastConfirmedSale,
    bool clearCustomer = false,
    String? errorMessage,
    int? lastSaleId,
    String? selectedCategory,
    double? pendingExpensesAmount,
    String? pendingExpenseDescription,
    double? dailySalesTotal,
    double? pendingTotalExpenses,
    List<String>? availableCategories,
    List<Product>? filteredProducts,
  }) {
    return PosState(
      status: status ?? this.status,
      products: products ?? this.products,
      customers: customers ?? this.customers,
      cartItems: cartItems ?? this.cartItems,
      selectedCustomer: clearCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      lastConfirmedCustomer:
          lastConfirmedCustomer ?? this.lastConfirmedCustomer,
      lastConfirmedSale: lastConfirmedSale ?? this.lastConfirmedSale,
      errorMessage: errorMessage,
      lastSaleId: lastSaleId ?? this.lastSaleId,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      pendingExpensesAmount:
          pendingExpensesAmount ?? this.pendingExpensesAmount,
      pendingExpenseDescription:
          pendingExpenseDescription ?? this.pendingExpenseDescription,
      dailySalesTotal: dailySalesTotal ?? this.dailySalesTotal,
      pendingTotalExpenses: pendingTotalExpenses ?? this.pendingTotalExpenses,
      availableCategories: availableCategories ?? this.availableCategories,
      filteredProducts: filteredProducts ?? this.filteredProducts,
    );
  }

  @override
  List<Object?> get props => [
    status,
    products,
    customers,
    cartItems,
    selectedCustomer,
    lastConfirmedCustomer,
    lastConfirmedSale,
    errorMessage,
    lastSaleId,
    selectedCategory,
    pendingExpensesAmount,
    pendingExpenseDescription,
    dailySalesTotal,
    pendingTotalExpenses,
    availableCategories,
    filteredProducts,
  ];
}
