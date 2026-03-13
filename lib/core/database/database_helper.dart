import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'dart:io' show Platform;
import '../utils/version_info.dart';

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
    debugPrint('[DB] Initializing database...');
    Database db;
    if (kIsWeb) {
      debugPrint('[DB] Platform: Web');
      databaseFactory = databaseFactoryFfiWeb;
      db = await openDatabase(
        'pos_barber.db',
        version: VersionInfo.dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        debugPrint('[DB] Platform: Desktop (${Platform.operatingSystem})');
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } else {
        debugPrint('[DB] Platform: Mobile (${Platform.isAndroid ? 'Android' : 'iOS'})');
      }

      String dbPath = join(await getDatabasesPath(), 'pos_barber.db');
      debugPrint('[DB] Database path: $dbPath');

      try {
        db = await openDatabase(
          dbPath,
          version: VersionInfo.dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      } catch (e) {
        debugPrint('[DB] Error during primary open: $e');
        db = await openDatabase(
          dbPath,
          version: VersionInfo.dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      }
    }

    debugPrint('[DB] Database opened successfully');
    
    // ESSENTIAL: These tasks must run on ALL platforms after open
    await _ensureInitialUsers(db);
    await _ensureInitialInventory(db);
    await _updateServicePrices(db);
    await _repairHistoricalServiceFlags(db);
    await _cleanupTestUsers(db);
    
    return db;
  }

  Future<void> _cleanupTestUsers(Database db) async {
    // 1. Delete generic 'Admin' users that are NOT 'nacho'
    await db.delete('users', where: "name IN ('Admin', 'Administrador', 'admin') AND username NOT IN ('nacho', 'franco')");
    await db.delete('users', where: "username IN ('admin', 'Administrador', 'Admin') AND username NOT IN ('nacho', 'franco')");

    // 2. Explicitly fix Franco's name if it was set to 'admin'
    await db.update('users', {'name': 'Franco'}, where: "username = 'franco' AND name IN ('admin', 'Admin', 'Administrador')");

    // 3. Re-attribute sales from generic 'Admin' to 'Franco'
    await db.update('sales', {'user_name': 'Franco'}, where: "user_name IN ('Admin', 'Administrador', 'admin', 'Empleado') AND user_name != 'Nacho'");
    
    // 4. Re-attribute expenses
    await db.update('expenses', {'user_name': 'Franco'}, where: "user_name IN ('Admin', 'Administrador', 'admin', 'Empleado') AND user_name != 'Nacho'");
  }

  Future<void> _repairHistoricalServiceFlags(Database db) async {
    // This updates existing sale_items that were created before the is_service column existed
    // or before it was properly populated in the POS flow.
    await db.execute('''
      UPDATE sale_items 
      SET is_service = 1 
      WHERE product_id IN (SELECT id FROM products WHERE is_service = 1)
      OR product_name IN ('Corte Clásico', 'Corte + Barba', 'Barba', 'Color', 'Corte')
      OR product_name LIKE '%Corte%' 
      OR product_name LIKE '%Barba%'
      OR product_name LIKE '%Servicio%'
    ''');
  }

  Future<void> _ensureInitialUsers(Database db) async {
    final users = [
      {'name': 'Enzo', 'username': 'enzo', 'email': 'enzo@barberia.com', 'password': 'enzo', 'role': 'employee', 'daily_rate': 0.0},
      {'name': 'Mauro', 'username': 'mauro', 'email': 'mauro@barberia.com', 'password': 'mauro', 'role': 'employee', 'daily_rate': 0.0},
      {'name': 'Franco', 'username': 'franco', 'email': 'franco@barberia.com', 'password': 'franco', 'role': 'headBarber', 'daily_rate': 0.0},
      {'name': 'Nacho', 'username': 'nacho', 'email': 'nacho@barberia.com', 'password': 'nacho', 'role': 'admin', 'daily_rate': 0.0},
    ];

    for (var user in users) {
      final exists = await db.query('users', where: 'username = ?', whereArgs: [user['username']]);
      if (exists.isEmpty) {
        await db.insert('users', user);
        debugPrint('[DB] User created: ${user['username']}');
      } else {
        // IMPROVEMENT: For 'nacho', ensure the password is 'nacho' effectively as requested
        if (user['username'] == 'nacho') {
           await db.update('users', user, where: 'username = ?', whereArgs: ['nacho']);
           debugPrint('[DB] User updated/ensured: nacho');
        }
      }
    }
  }

  Future<void> _updateServicePrices(Database db) async {
    final updates = {
      'Corte Clásico': 12000.0,
      'Corte + Barba': 15000.0,
      'Barba': 7000.0,
      'Color Mechitas': 40000.0,
      'Color Global': 60000.0,
    };

    for (var entry in updates.entries) {
      await db.update(
        'products',
        {'price': entry.value},
        where: 'name = ? AND is_service = 1',
        whereArgs: [entry.key],
      );
    }
  }

  Future<void> _ensureInitialInventory(Database db) async {
    final products = [
      {'name': 'Gaseosa 7up', 'barcode': 'B001', 'price': 1800.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Cerveza Quilmes', 'barcode': 'B002', 'price': 2500.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Agua Eco', 'barcode': 'B003', 'price': 1500.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Power', 'barcode': 'B004', 'price': 2800.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Baggio Cajita', 'barcode': 'B005', 'price': 1000.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Fresh Pomelo', 'barcode': 'B006', 'price': 1500.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Monster', 'barcode': 'B007', 'price': 3500.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Gatorade', 'barcode': 'B008', 'price': 2800.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Speed', 'barcode': 'B009', 'price': 2300.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Coca Lata', 'barcode': 'B010', 'price': 2000.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Alfajor Chico', 'barcode': 'S001', 'price': 700.0, 'stock': 20, 'category': 'Snacks', 'is_service': 0},
      {'name': 'Alfajor Grande', 'barcode': 'S002', 'price': 1000.0, 'stock': 20, 'category': 'Snacks', 'is_service': 0},
      {'name': 'Fanta Zero Lata', 'barcode': 'B011', 'price': 1500.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Sprite Lata', 'barcode': 'B012', 'price': 2000.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Pepsi Lata', 'barcode': 'B013', 'price': 2000.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
    ];

    for (var p in products) {
      final exists = await db.query('products', where: 'name = ?', whereArgs: [p['name']]);
      if (exists.isEmpty) {
        await db.insert('products', p);
      } else {
        await db.update('products', {'price': p['price']}, where: 'name = ?', whereArgs: [p['name']]);
      }
    }
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
      } catch (e) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN stock_min INTEGER DEFAULT 5'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN category TEXT'); } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN daily_rate REAL DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE payroll (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          user_name TEXT NOT NULL,
          date TEXT NOT NULL,
          amount REAL NOT NULL,
          payment_method TEXT NOT NULL,
          notes TEXT,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN staff_user_id INTEGER');
      } catch (e) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE sale_items ADD COLUMN is_service INTEGER DEFAULT 0');
        await _repairHistoricalServiceFlags(db);
      } catch (e) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute('DELETE FROM sale_items');
        await db.execute('DELETE FROM sales');
      } catch (e) {}
    }
    if (oldVersion < 13) {
      try {
        await db.execute('DELETE FROM sales');
        await db.execute('DELETE FROM sale_items');
        await db.execute('DELETE FROM expenses');
        await db.execute('DELETE FROM payroll');
        await db.execute('DELETE FROM appointments');
        debugPrint('[DB] FULL RESET PERFORMED for version 13');
      } catch (e) {}
    }
    if (oldVersion < 17) {
      try {
        await db.execute('DELETE FROM users');
        await _ensureInitialUsers(db);
        debugPrint('[DB] CRITICAL: USERS RE-SEEDED FOR v17');
      } catch (e) {
        debugPrint('[DB] Error in v17 migration: $e');
      }
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
        role TEXT NOT NULL,
        daily_rate REAL DEFAULT 0
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
        is_service INTEGER DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Initial user 'Franco' as Head Barber is handled in _ensureInitialUsers

    await db.insert('users', {
      'name': 'Barbero Juan',
      'username': 'juan',
      'email': 'juan@barberia.com',
      'password': 'juan',
      'role': 'employee',
      'daily_rate': 0.0,
    });

    await db.insert('users', {
      'name': 'Enzo',
      'username': 'enzo',
      'email': 'enzo@barberia.com',
      'password': 'enzo',
      'role': 'employee',
      'daily_rate': 0.0,
    });

    await db.insert('users', {
      'name': 'Mauro',
      'username': 'mauro',
      'email': 'mauro@barberia.com',
      'password': 'mauro',
      'role': 'employee',
      'daily_rate': 0.0,
    });

    await db.insert('users', {
      'name': 'Franco',
      'username': 'franco',
      'email': 'franco@barberia.com',
      'password': 'franco',
      'role': 'headBarber',
      'daily_rate': 0.0,
    });

    // Seed Products (Services)
    final initialServices = [
      {'name': 'Corte Clásico', 'barcode': 'C001', 'price': 12000.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/corte.png'},
      {'name': 'Corte + Barba', 'barcode': 'C002', 'price': 15000.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/corte+barba.png'},
      {'name': 'Barba', 'barcode': 'C003', 'price': 7000.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/barba.png'},
      {'name': 'Color Mechitas', 'barcode': 'C004', 'price': 40000.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/color.png'},
      {'name': 'Color Global', 'barcode': 'C005', 'price': 60000.00, 'category': 'Cortes', 'is_service': 1, 'image_url': 'assets/images/color.png'},
    ];

    for (var s in initialServices) {
      await db.insert('products', s);
    }

    // Seed Products (Physical Goods)
    final initialProducts = [
      {'name': 'Gaseosa 7up', 'barcode': 'B001', 'price': 1800.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Cerveza Quilmes', 'barcode': 'B002', 'price': 2500.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Agua Eco', 'barcode': 'B003', 'price': 1500.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Power', 'barcode': 'B004', 'price': 2800.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Baggio Cajita', 'barcode': 'B005', 'price': 1000.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Fresh Pomelo', 'barcode': 'B006', 'price': 1500.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Monster', 'barcode': 'B007', 'price': 3500.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Gatorade', 'barcode': 'B008', 'price': 2800.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Speed', 'barcode': 'B009', 'price': 2300.0, 'stock': 12, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Coca Lata', 'barcode': 'B010', 'price': 2000.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Alfajor Chico', 'barcode': 'S001', 'price': 700.0, 'stock': 20, 'category': 'Snacks', 'is_service': 0},
      {'name': 'Alfajor Grande', 'barcode': 'S002', 'price': 1000.0, 'stock': 20, 'category': 'Snacks', 'is_service': 0},
      {'name': 'Fanta Zero Lata', 'barcode': 'B011', 'price': 1500.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Sprite Lata', 'barcode': 'B012', 'price': 2000.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
      {'name': 'Pepsi Lata', 'barcode': 'B013', 'price': 2000.0, 'stock': 24, 'category': 'Bebidas', 'is_service': 0},
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
          staff_user_id INTEGER,
          type TEXT DEFAULT 'general',
          is_synced INTEGER DEFAULT 0
        )
      ''');
    }

    if (version >= 8) {
      await db.execute('''
        CREATE TABLE payroll (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          user_name TEXT NOT NULL,
          date TEXT NOT NULL,
          amount REAL NOT NULL,
          payment_method TEXT NOT NULL,
          notes TEXT,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
    }
  }

  Future<Map<String, dynamic>?> getUserByEmailOrUsername(String identifier) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'LOWER(email) = LOWER(?) OR LOWER(username) = LOWER(?)',
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
