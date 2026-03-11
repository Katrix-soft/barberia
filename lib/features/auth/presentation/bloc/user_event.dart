import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();
  @override
  List<Object?> get props => [];
}

class LoadUsers extends UserEvent {}

class SaveUser extends UserEvent {
  final User user;
  final String password;
  const SaveUser(this.user, this.password);
  @override
  List<Object?> get props => [user, password];
}

class DeleteUser extends UserEvent {
  final int id;
  const DeleteUser(this.id);
  @override
  List<Object?> get props => [id];
}
