import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static Future<void> write(String key, String value) async {
    if (kIsWeb) {
      // En web usamos SharedPreferences con hash simple
      final prefs = await SharedPreferences.getInstance();
      final hashed = sha256.convert(utf8.encode(value)).toString();
      await prefs.setString(key, hashed);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  static Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _storage.read(key: key);
    }
  }

  static Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }
}
