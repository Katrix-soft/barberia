import 'dart:async';
import '../database/database_helper.dart';

/// SyncService is now a local-only service as per user request to "unify everything in this app".
/// External API dependencies (api.katrix.com.ar) have been removed.
class SyncService {
  final DatabaseHelper databaseHelper;
  
  SyncService({required this.databaseHelper});

  void startAutoSync() {
    // No-op: Everything is local now.
  }

  void stopSync() {
    // No-op
  }

  Future<void> syncPendingData() async {
    // No-op: External sync is disabled to favor local-only unification.
  }
}
