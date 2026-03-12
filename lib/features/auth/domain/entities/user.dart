import 'package:equatable/equatable.dart';

enum UserRole { admin, headBarber, employee }

class User extends Equatable {
  final int? id;
  final String name;
  final String username;
  final String email;
  final String? password;
  final UserRole role;
  final double dailyRate;

  const User({
    this.id,
    required this.name,
    required this.username,
    required this.email,
    this.password,
    required this.role,
    this.dailyRate = 0.0,
  });

  @override
  List<Object?> get props => [id, name, username, email, password, role, dailyRate];
}
