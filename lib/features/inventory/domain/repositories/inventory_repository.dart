import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product.dart';

abstract class InventoryRepository {
  Future<Either<Failure, List<Product>>> getProducts();
  Future<Either<Failure, void>> saveProduct(Product product);
  Future<Either<Failure, void>> deleteProduct(int id);
}
