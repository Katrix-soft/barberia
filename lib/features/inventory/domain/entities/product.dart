import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final int? id;
  final String name;
  final String? barcode;
  final double price;
  final int stock;
  final int stockMin;
  final String category;
  final bool isService;
  final String? imageUrl;

  const Product({
    this.id,
    required this.name,
    this.barcode,
    required this.price,
    this.stock = 0,
    this.stockMin = 5,
    required this.category,
    this.isService = false,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    barcode,
    price,
    stock,
    stockMin,
    category,
    isService,
    imageUrl,
  ];
}
