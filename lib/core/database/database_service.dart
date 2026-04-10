import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'db_init_stub.dart' 
    if (dart.library.io) 'db_init_io.dart' 
    if (dart.library.js_interop) 'db_init_web.dart' as platform_db;

class DatabaseService {
  static Database? _database;

  static Future<void> init() async {
    await platform_db.initializeDatabaseFactory();
  }

  static Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String dbPathStr;
    
    if (kIsWeb) {
      dbPathStr = 'posbarber_web.db';
    } else {
      final dbPath = await getDatabasesPath();
      dbPathStr = join(dbPath, 'posbarber.db');
    }

    return await openDatabase(
      dbPathStr,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Tus tablas acá
  }
}
