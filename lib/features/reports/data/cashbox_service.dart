import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';

class CashboxSession {
  final int? id;
  final DateTime? openedAt;
  final DateTime closedAt;
  final int? closedBy;
  final String? closedByName;
  final double expectedCash;
  final double actualCash;
  final double expectedMp;
  final double actualMp;
  final double discrepancy;
  final String? notes;

  CashboxSession({
    this.id,
    this.openedAt,
    required this.closedAt,
    this.closedBy,
    this.closedByName,
    required this.expectedCash,
    required this.actualCash,
    required this.expectedMp,
    required this.actualMp,
    required this.discrepancy,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'opened_at': openedAt?.toIso8601String(),
      'closed_at': closedAt.toIso8601String(),
      'closed_by': closedBy,
      'closed_by_name': closedByName,
      'expected_cash': expectedCash,
      'actual_cash': actualCash,
      'expected_mp': expectedMp,
      'actual_mp': actualMp,
      'discrepancy': discrepancy,
      'notes': notes,
      'is_synced': 0,
    };
  }

  factory CashboxSession.fromMap(Map<String, dynamic> map) {
    return CashboxSession(
      id: map['id'],
      openedAt: map['opened_at'] != null ? DateTime.tryParse(map['opened_at']) : null,
      closedAt: DateTime.parse(map['closed_at']),
      closedBy: map['closed_by'],
      closedByName: map['closed_by_name'],
      expectedCash: map['expected_cash'],
      actualCash: map['actual_cash'],
      expectedMp: map['expected_mp'],
      actualMp: map['actual_mp'],
      discrepancy: map['discrepancy'],
      notes: map['notes'],
    );
  }
}

class CashboxService {
  final DatabaseHelper _dbHelper;

  CashboxService(this._dbHelper);

  Future<CashboxSession?> getLastSession() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cashbox_sessions',
      orderBy: 'closed_at DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return CashboxSession.fromMap(maps.first);
    }
    return null;
  }

  Future<Map<String, double>> getExpectedTotals() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final todayStr = DateTime(now.year, now.month, now.day).toIso8601String();
    
    // Obtener VENTAS STRICTAMENTE DE HOY
    final sales = await db.query(
      'sales', 
      where: 'date >= ?', 
      whereArgs: [todayStr]
    );
    
    double expectedCash = 0;
    double expectedMp = 0;
    
    for (var sale in sales) {
      String pm = (sale['payment_method'] as String).toLowerCase();
      double total = (sale['total'] as num).toDouble();
      
      if (pm == 'cash' || pm == 'efectivo') {
        expectedCash += total;
      } else if (pm == 'qr' || pm == 'transfer' || pm == 'card' || pm == 'mercadopago' || pm == 'mercadopago_qr' || pm == 'transferencia') {
        expectedMp += total;
      }
    }
    
    // Considerar Gastos pagados HOY en efectivo (sacados de la caja)
    // Para simplificar, asumimos que todos los gastos pagados (is_paid = 1) 
    // que vencen/se registraron hoy, y que no son "Consumo Personal", salen del Efectivo.
    final expenses = await db.query(
      'expenses',
      where: 'is_paid = 1 AND category != ? AND due_date >= ?',
      whereArgs: ['Consumo Personal', todayStr]
    );

    double totalExpensesCash = 0;
    for (var exp in expenses) {
      totalExpensesCash += (exp['amount'] as num).toDouble();
    }

    // Se resta del efectivo esperado lo que se pagó de gastos
    expectedCash -= totalExpensesCash;
    if (expectedCash < 0) expectedCash = 0; // Evitar negativos ilógicos, aunque en teoría posible si hay más salida que entrada.

    return {
      'cash': expectedCash,
      'mp': expectedMp,
      'expenses_cash': totalExpensesCash, // Devolvemos también los gastos para mostrarlo en UI
    };
  }

  Future<void> saveSession(CashboxSession session) async {
    final db = await _dbHelper.database;
    await db.insert(
      'cashbox_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
