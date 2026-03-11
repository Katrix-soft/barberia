import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login(String email, String password);
  Future<void> logout();
  Future<Either<Failure, User?>> getCheckAuth();

  // User Management (Multi-role)
  Future<Either<Failure, List<User>>> getUsers();
  Future<Either<Failure, void>> saveUser(User user, String password);
  Future<Either<Failure, void>> deleteUser(int id);
}
