import '../../domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    super.id,
    required super.name,
    super.barcode,
    required super.price,
    super.stock,
    super.stockMin,
    required super.category,
    super.isService,
    super.imageUrl,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      price: (map['price'] as num).toDouble(),
      stock: map['stock'] ?? 0,
      stockMin: map['stock_min'] ?? 5,
      category: map['category'] ?? '',
      isService: map['is_service'] == 1,
      imageUrl: map['image_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'stock': stock,
      'stock_min': stockMin,
      'category': category,
      'is_service': isService ? 1 : 0,
      'image_url': imageUrl,
    };
  }
}
