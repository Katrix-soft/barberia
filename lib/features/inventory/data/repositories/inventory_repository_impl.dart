import 'package:dartz/dartz.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../models/product_model.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final DatabaseHelper databaseHelper;

  InventoryRepositoryImpl({required this.databaseHelper});

  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        orderBy: 'name ASC',
      );
      return Right(maps.map((m) => ProductModel.fromMap(m)).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveProduct(Product product) async {
    try {
      final db = await databaseHelper.database;
      final productModel = ProductModel(
        id: product.id,
        name: product.name,
        barcode: product.barcode,
        price: product.price,
        stock: product.stock,
        stockMin: product.stockMin,
        category: product.category,
        isService: product.isService,
        imageUrl: product.imageUrl,
      );

      final map = productModel.toMap();
      if (product.id == null) {
        map.remove('id');
        await db.insert('products', map);
      } else {
        map.remove('id');
        await db.update(
          'products',
          map,
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(int id) async {
    try {
      final db = await databaseHelper.database;
      await db.delete('products', where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
