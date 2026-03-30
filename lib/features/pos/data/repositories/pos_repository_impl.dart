import 'package:dartz/dartz.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/pos_repository.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/data/models/product_model.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/data/models/customer_model.dart';
import '../models/sale_model.dart';

class PosRepositoryImpl implements PosRepository {
  final DatabaseHelper databaseHelper;

  PosRepositoryImpl({required this.databaseHelper});

  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('products');
      return Right(maps.map((m) => ProductModel.fromMap(m)).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Customer>>> getCustomers() async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('customers');
      return Right(maps.map((m) => CustomerModel.fromMap(m)).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> createSale(Sale sale) async {
    try {
      final db = await databaseHelper.database;
      final result = await db.transaction((txn) async {
        final saleModel = SaleModel(
          customerId: sale.customerId,
          customerName: sale.customerName,
          date: sale.date,
          total: sale.total,
          paymentMethod: sale.paymentMethod,
          userName: sale.userName,
          items: sale.items,
        );

        final saleId = await txn.insert('sales', saleModel.toMap());

        // If it's a personal consumption, we MUST create an expense record
        // so it shows up in the "A Cuenta" / Debt tracking system.
        if (sale.paymentMethod == PaymentMethod.personal) {
          final itemsDescription = sale.items.map((i) => "${i.quantity}x ${i.productName}").join(", ");
          await txn.insert('expenses', {
            'description': 'Consumo POS: $itemsDescription',
            'amount': sale.total,
            'due_date': sale.date.toIso8601String(),
            'is_paid': 0,
            'category': 'Consumo Personal',
            'user_name': sale.userName,
            'type': 'personal',
            'is_synced': 0,
          });
        }

        for (var item in sale.items) {
          final itemModel = SaleItemModel(
            saleId: saleId,
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
            price: item.price,
            total: item.total,
            isService: item.isService,
          );
          await txn.insert('sale_items', itemModel.toMap());

          // Update product stock if it's not a service
          final productMap = await txn.query(
            'products',
            where: 'id = ? AND is_service = 0',
            whereArgs: [item.productId],
          );

          if (productMap.isNotEmpty) {
            final product = ProductModel.fromMap(productMap.first);
            final newStock = product.stock - item.quantity;
            await txn.update(
              'products',
              {'stock': newStock},
              where: 'id = ?',
              whereArgs: [product.id],
            );
          }
        }
        return saleId;
      });
      return Right(result);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Sale>>> getSales() async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> saleMaps = await db.query(
        'sales',
        orderBy: 'date DESC',
      );

      List<Sale> sales = [];
      for (var saleMap in saleMaps) {
        final List<Map<String, dynamic>> itemMaps = await db.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [saleMap['id']],
        );
        final items = itemMaps.map((m) => SaleItemModel.fromMap(m)).toList();
        sales.add(SaleModel.fromMap(saleMap, items));
      }
      return Right(sales);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getDailySales(DateTime date) async {
    try {
      final db = await databaseHelper.database;
      final dateStr = date.toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> maps = await db.query(
        'sales',
        where: "date LIKE ?",
        whereArgs: ['$dateStr%'],
      );
      double total = maps.fold(
        0,
        (sum, m) => sum + (m['total'] as num).toDouble(),
      );
      return Right(total);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
