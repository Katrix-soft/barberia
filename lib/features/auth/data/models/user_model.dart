import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    super.id,
    required super.name,
    required super.username,
    required super.email,
    required super.password,
    required super.role,
    super.dailyRate = 0.0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.employee,
      ),
      dailyRate: (map['daily_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'role': role.name,
      'daily_rate': dailyRate,
    };
  }
}
