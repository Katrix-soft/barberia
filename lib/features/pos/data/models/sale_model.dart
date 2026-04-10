import '../../domain/entities/sale.dart';

class SaleModel extends Sale {
  const SaleModel({
    super.id,
    super.customerId,
    super.customerName,
    required super.date,
    required super.total,
    required super.paymentMethod,
    required super.userName,
    required super.items,
    super.isSynced = false,
    super.externalReference,
    super.isPaid = false,
  });

  factory SaleModel.fromMap(
    Map<String, dynamic> map,
    List<SaleItemModel> items,
  ) {
    return SaleModel(
      id: map['id'],
      customerId: map['customer_id'],
      customerName: map['customer_name'],
      date: DateTime.parse(map['date']),
      total: (map['total'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['payment_method'],
        orElse: () => PaymentMethod.cash,
      ),
      userName: map['user_name'],
      items: items,
      isSynced: (map['is_synced'] ?? 0) == 1,
      externalReference: map['external_reference'],
      isPaid: (map['is_paid'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'date': date.toIso8601String(),
      'total': total,
      'payment_method': paymentMethod.name,
      'user_name': userName,
      'is_synced': isSynced ? 1 : 0,
      'external_reference': externalReference,
      'is_paid': isPaid ? 1 : 0,
    };
  }
}

class SaleItemModel extends SaleItem {
  const SaleItemModel({
    super.id,
    super.saleId,
    required super.productId,
    required super.productName,
    required super.quantity,
    required super.price,
    required super.total,
    super.isService = false,
  });

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      id: map['id'],
      saleId: map['sale_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      quantity: map['quantity'],
      price: (map['price'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      isService: (map['is_service'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'total': total,
      'is_service': isService ? 1 : 0,
    };
  }
}
