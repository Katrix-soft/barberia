import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'dart:io' show Platform;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        'pos_barber.db',
        version: 6,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath = join(await getDatabasesPath(), 'pos_barber.db');

    return await openDatabase(
      dbPath,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS sale_items');
      await db.execute('DROP TABLE IF EXISTS sales');
      await db.execute('DROP TABLE IF EXISTS customers');
      await db.execute('DROP TABLE IF EXISTS products');
      await db.execute('DROP TABLE IF EXISTS users');
      await _onCreate(db, newVersion);
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE appointments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER,
          customer_name TEXT NOT NULL,
          service_id INTEGER,
          service_name TEXT NOT NULL,
          date_time TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          notes TEXT,
          FOREIGN KEY (customer_id) REFERENCES customers (id),
          FOREIGN KEY (service_id) REFERENCES products (id)
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          due_date TEXT NOT NULL,
          is_paid INTEGER DEFAULT 0,
          category TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE sales ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE customers ADD COLUMN is_synced INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE products ADD COLUMN is_synced INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE expenses ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE appointments ADD COLUMN is_synced INTEGER DEFAULT 0');
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN user_name TEXT DEFAULT "admin"');
      } catch (e) {
        // Ignored if already exists
      }
      // Ensure products columns exist (legacy safety)
      try { await db.execute('ALTER TABLE products ADD COLUMN stock_min INTEGER DEFAULT 5'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN category TEXT'); } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        price REAL NOT NULL,
        stock INTEGER DEFAULT 0,
        stock_min INTEGER DEFAULT 5,
        category TEXT,
        is_service INTEGER DEFAULT 0,
        image_url TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        points INTEGER DEFAULT 0,
        notes TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        customer_name TEXT,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        payment_method TEXT NOT NULL,
        user_name TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.insert('users', {
      'name': 'Administrador',
      'username': 'admin',
      'email': 'admin@barberia.com',
      'password': 'admin',
      'role': 'admin',
    });

    await db.insert('users', {
      'name': 'Barbero Juan',
      'username': 'juan',
      'email': 'juan@barberia.com',
      'password': 'juan',
      'role': 'employee',
    });

    // Seed Products (Services)
    final initialServices = [
      {'name': 'Corte Clásico', 'barcode': 'C001', 'price': 15.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/corte.png'},
      {'name': 'Corte + Barba', 'barcode': 'C002', 'price': 25.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/corte+barba.png'},
      {'name': 'Barba', 'barcode': 'C003', 'price': 15.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/barba.png'},
      {'name': 'Color Mechitas', 'barcode': 'C004', 'price': 40.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/color.png'},
      {'name': 'Color Global', 'barcode': 'C005', 'price': 60.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/color.png'},
    ];

    for (var s in initialServices) {
      await db.insert('products', s);
    }

    // Seed Products (Physical Goods)
    final initialProducts = [
      {'name': 'Cerveza Corona', 'barcode': 'B001', 'price': 4.50, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Agua Mineral', 'barcode': 'B002', 'price': 2.00, 'stock': 50, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Perfume Dior Sauvage (Muestra)', 'barcode': 'P001', 'price': 85.00, 'stock': 5, 'category': 'Perfumes', 'is_service': 0},
      {'name': 'Remera Katrix Black', 'barcode': 'R001', 'price': 30.00, 'stock': 10, 'category': 'Ropa', 'is_service': 0},
    ];

    for (var p in initialProducts) {
      await db.insert('products', p);
    }

    if (version >= 3) {
      await db.execute('''
        CREATE TABLE appointments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER,
          customer_name TEXT NOT NULL,
          service_id INTEGER,
          service_name TEXT NOT NULL,
          date_time TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          notes TEXT,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (customer_id) REFERENCES customers (id),
          FOREIGN KEY (service_id) REFERENCES products (id)
        )
      ''');
    }

    if (version >= 4) {
      await db.execute('''
        CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          due_date TEXT NOT NULL,
          is_paid INTEGER DEFAULT 0,
          category TEXT NOT NULL,
          user_name TEXT DEFAULT 'admin',
          is_synced INTEGER DEFAULT 0
        )
      ''');
    }
  }

  Future<Map<String, dynamic>?> getUserByEmailOrUsername(String identifier) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'email = ? OR username = ?',
      whereArgs: [identifier, identifier],
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> resetDatabase() async {
    if (kIsWeb) {
      await databaseFactoryFfiWeb.deleteDatabase('pos_barber.db');
    } else {
      String dbPath = join(await getDatabasesPath(), 'pos_barber.db');
      await databaseFactory.deleteDatabase(dbPath);
    }
    _database = null;
    await database;
  }
}
