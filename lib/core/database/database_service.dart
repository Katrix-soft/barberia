import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform;

class DatabaseService {
  static Database? _database;

  static Future<void> init() async {
    if (kIsWeb) {
      // Web
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux) {
      // Desktop
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android/iOS usan sqflite normal
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
