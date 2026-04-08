import '../../../../core/database/database_helper.dart';

class PayrollService {
  final DatabaseHelper _dbHelper;

  PayrollService(this._dbHelper);

  Future<void> markAsPaid(String userName) async {
    final db = await _dbHelper.database;
    
    // Marcar ventas como liquidadas
    await db.update(
      'sales',
      {'is_liquidated': 1},
      where: 'LOWER(user_name) = ? AND is_liquidated = 0',
      whereArgs: [userName.trim().toLowerCase()],
    );

    // Marcar consumos como pagados
    await db.update(
      'expenses',
      {'is_paid': 1},
      where: 'LOWER(user_name) = ? AND is_paid = 0 AND category = ?',
      whereArgs: [userName.trim().toLowerCase(), 'Consumo Personal'],
    );
  }

  Future<Map<String, dynamic>> getPendingLiquidations(List<Map<String, dynamic>> users) async {
    final db = await _dbHelper.database;
    
    final sales = await db.query('sales', where: 'is_liquidated = 0 OR is_liquidated IS NULL');
    final expenses = await db.query('expenses', where: 'is_paid = 0');
    
    final Map<String, double> pendingServiceSales = {};
    final Map<String, double> pendingConsumptions = {};

    for (var sale in sales) {
      final String name = sale['user_name'].toString().trim().toLowerCase();
      // Only services are commissioned
      final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sale['id']]);
      double serviceTotal = 0;
      for (var item in items) {
        if ((item['is_service'] as int) == 1) {
          serviceTotal += (item['total'] as num).toDouble();
        }
      }
      pendingServiceSales[name] = (pendingServiceSales[name] ?? 0) + serviceTotal;
    }

    for (var expense in expenses) {
      if (expense['category'] == 'Consumo Personal') {
        final String name = expense['user_name'].toString().trim().toLowerCase();
        pendingConsumptions[name] = (pendingConsumptions[name] ?? 0) + (expense['amount'] as num).toDouble();
      }
    }

    // Now build display data
    List<Map<String, dynamic>> result = [];
    for (var user in users) {
      final role = user['role'] as String;
      final uName = user['name'] as String;
      final key = uName.toLowerCase();
      
      if (role == 'admin') continue; // Admin does not get paid commission this way

      final sTotal = pendingServiceSales[key] ?? 0.0;
      final cTotal = pendingConsumptions[key] ?? 0.0;
      
      // If there is anything to liquidate or pay, or even 0 if we want to show everyone.
      // Let's show barbers that have sales or consumptions.
      // Even if 0, they might be listed.
      
      result.add({
        'name': uName,
        'role': role,
        'service_sales': sTotal,
        'commission': sTotal * 0.5,
        'consumptions': cTotal,
        'net_payout': (sTotal * 0.5) - cTotal,
      });
    }

    return {'liquidations': result};
  }
}
