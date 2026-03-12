import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepositoryImpl implements AuthRepository {
  final DatabaseHelper databaseHelper;
  final SharedPreferences sharedPreferences;

  AuthRepositoryImpl({
    required this.databaseHelper,
    required this.sharedPreferences,
  });

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: '(email = ? OR username = ?) AND password = ?',
        whereArgs: [email, email, password],
      );

      if (maps.isNotEmpty) {
        final userModel = UserModel.fromMap(maps.first);
        await sharedPreferences.setInt('user_id', userModel.id!);
        await sharedPreferences.setString('user_name', userModel.name);
        await sharedPreferences.setString('user_role', userModel.role.name);
        debugPrint('[Auth] Session saved for user: ${userModel.username}');

        return Right(userModel);
      } else {
        return const Left(AuthFailure('Credenciales incorrectas'));
      }
    } catch (e) {
      return Left(DatabaseFailure('Error de base de datos: ${e.toString()}'));
    }
  }

  @override
  Future<void> logout() async {
    await sharedPreferences.remove('user_id');
    await sharedPreferences.remove('user_name');
    await sharedPreferences.remove('user_role');
  }

  @override
  Future<Either<Failure, User?>> getCheckAuth() async {
    final userId = sharedPreferences.getInt('user_id');
    debugPrint('[Auth] Checking session for userId: $userId');
    if (userId == null) return const Right(null);

    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (maps.isNotEmpty) {
        final user = UserModel.fromMap(maps.first);
        debugPrint('[Auth] Session restored for: ${user.username}');
        return Right(user);
      }
      debugPrint('[Auth] No user found in DB for id: $userId');
      return const Right(null);
    } catch (e) {
      debugPrint('[Auth] Database error in checkAuth: $e');
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<User>>> getUsers() async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        orderBy: 'name ASC',
      );
      return Right(maps.map((m) => UserModel.fromMap(m)).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveUser(User user, String password) async {
    try {
      final db = await databaseHelper.database;
      final userModelMap = {
        'name': user.name,
        'username': user.username,
        'email': user.email,
        'role': user.role.name,
      };

      // Only update password if a new one is provided (not empty)
      if (password.isNotEmpty) {
        userModelMap['password'] = password;
      }

      if (user.id == null) {
        // For new users, if password is empty it will fail NOT NULL constraint
        // if not handled elsewhere, but StaffPage ensures it's set for new users.
        if (password.isEmpty) {
          return const Left(
            AuthFailure('Contraseña requerida para nuevos usuarios'),
          );
        }
        await db.insert('users', userModelMap);
      } else {
        // Exclude ID from update map to avoid issues with some SQL drivers
        userModelMap.remove('id');
        await db.update(
          'users',
          userModelMap,
          where: 'id = ?',
          whereArgs: [user.id],
        );
      }
      return const Right(null);
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('UNIQUE constraint failed')) {
        return const Left(
          AuthFailure('El nombre de usuario o email ya está registrado.'),
        );
      }
      return Left(DatabaseFailure(errorStr));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(int id) async {
    try {
      final db = await databaseHelper.database;
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
