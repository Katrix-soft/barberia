import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';

class SyncService {
  final DatabaseHelper databaseHelper;
  Timer? _syncTimer;
  bool _isSyncing = false;
  
  // Real backend base URL
  static const String baseUrl = 'https://api.katrix.com.ar';

  SyncService({required this.databaseHelper});

  void startAutoSync() {
    _syncTimer?.cancel();
    // Sync every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => syncPendingData());
  }

  void stopSync() {
    _syncTimer?.cancel();
  }

  Future<void> syncPendingData() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    try {
      final db = await databaseHelper.database;

      // 1. Sync Sales
      final List<Map<String, dynamic>> unsyncedSales = await db.query(
        'sales',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      if (unsyncedSales.isNotEmpty) {
        debugPrint('[Sync] Checking ${unsyncedSales.length} pending sales...');
        for (var saleMap in unsyncedSales) {
          final List<Map<String, dynamic>> itemMaps = await db.query(
            'sale_items',
            where: 'sale_id = ?',
            whereArgs: [saleMap['id']],
          );

          final payload = {
            'sale': saleMap,
            'items': itemMaps,
          };

          try {
            final response = await http.post(
              Uri.parse('$baseUrl/api/sales/sync'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200 || response.statusCode == 201) {
              await db.update(
                'sales',
                {'is_synced': 1},
                where: 'id = ?',
                whereArgs: [saleMap['id']],
              );
              debugPrint('[Sync] Sale ${saleMap['id']} synced successfully.');
            } else {
              debugPrint('[Sync] Failed to sync sale ${saleMap['id']}: ${response.statusCode}');
            }
          } catch (e) {
            debugPrint('[Sync] Error syncing sale ${saleMap['id']}: $e');
            break; // Stop loop if network is down
          }
        }
      }

      // 2. Sync Expenses
      final List<Map<String, dynamic>> unsyncedExpenses = await db.query(
        'expenses',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      if (unsyncedExpenses.isNotEmpty) {
        debugPrint('[Sync] Checking ${unsyncedExpenses.length} pending expenses...');
        for (var expense in unsyncedExpenses) {
          try {
            final response = await http.post(
              Uri.parse('$baseUrl/api/expenses/sync'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(expense),
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200 || response.statusCode == 201) {
              await db.update(
                'expenses',
                {'is_synced': 1},
                where: 'id = ?',
                whereArgs: [expense['id']],
              );
              debugPrint('[Sync] Expense ${expense['id']} synced.');
            }
          } catch (e) {
            debugPrint('[Sync] Expense sync error: $e');
            break;
          }
        }
      }

      // 3. Sync Appointments
      final List<Map<String, dynamic>> unsyncedAppts = await db.query(
        'appointments',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      if (unsyncedAppts.isNotEmpty) {
        debugPrint('[Sync] Checking ${unsyncedAppts.length} pending appointments...');
        for (var appt in unsyncedAppts) {
          try {
            final response = await http.post(
              Uri.parse('$baseUrl/api/appointments/sync'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(appt),
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200 || response.statusCode == 201) {
              await db.update(
                'appointments',
                {'is_synced': 1},
                where: 'id = ?',
                whereArgs: [appt['id']],
              );
              debugPrint('[Sync] Appointment ${appt['id']} synced.');
            }
          } catch (e) {
            debugPrint('[Sync] Appointment sync error: $e');
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[Sync] Master loop error: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
