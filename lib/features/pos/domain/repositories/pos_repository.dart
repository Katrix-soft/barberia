import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/sale.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../customers/domain/entities/customer.dart';

abstract class PosRepository {
  Future<Either<Failure, List<Product>>> getProducts();
  Future<Either<Failure, List<Customer>>> getCustomers();
  Future<Either<Failure, int>> createSale(Sale sale);
  Future<Either<Failure, List<Sale>>> getSales();
  Future<Either<Failure, double>> getDailySales(DateTime date);
}
