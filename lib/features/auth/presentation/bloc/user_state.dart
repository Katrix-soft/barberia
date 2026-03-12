import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';

enum UserStatus { initial, loading, loaded, success, error, deleted }

class UserState extends Equatable {
  final UserStatus status;
  final List<User> users;
  final String? errorMessage;

  const UserState({
    this.status = UserStatus.initial,
    this.users = const [],
    this.errorMessage,
  });

  UserState copyWith({
    UserStatus? status,
    List<User>? users,
    String? errorMessage,
  }) {
    return UserState(
      status: status ?? this.status,
      users: users ?? this.users,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, users, errorMessage];
}
