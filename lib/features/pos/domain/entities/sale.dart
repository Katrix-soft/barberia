import 'package:equatable/equatable.dart';

enum PaymentMethod { cash, transfer, card, personal, qr }

class Sale extends Equatable {
  final int? id;
  final int? customerId;
  final String? customerName;
  final DateTime date;
  final double total;
  final PaymentMethod paymentMethod;
  final String userName;
  final List<SaleItem> items;
  final bool isSynced;
  final String? externalReference;
  final bool isPaid;

  const Sale({
    this.id,
    this.customerId,
    this.customerName,
    required this.date,
    required this.total,
    required this.paymentMethod,
    required this.userName,
    required this.items,
    this.isSynced = false,
    this.externalReference,
    this.isPaid = false,
  });

  @override
  List<Object?> get props => [
    id,
    customerId,
    customerName,
    date,
    total,
    paymentMethod,
    userName,
    items,
    isSynced,
    externalReference,
    isPaid,
  ];
}

class SaleItem extends Equatable {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double total;
  final bool isService;

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
    this.isService = false,
  });

  @override
  List<Object?> get props => [
    id,
    saleId,
    productId,
    productName,
    quantity,
    price,
    total,
    isService,
  ];
}
