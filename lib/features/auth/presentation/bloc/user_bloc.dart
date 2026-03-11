import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final AuthRepository repository;

  UserBloc({required this.repository}) : super(const UserState()) {
    on<LoadUsers>(_onLoadUsers);
    on<SaveUser>(_onSaveUser);
    on<DeleteUser>(_onDeleteUser);
  }

  Future<void> _onLoadUsers(LoadUsers event, Emitter<UserState> emit) async {
    emit(state.copyWith(status: UserStatus.loading));
    final result = await repository.getUsers();
    result.fold(
      (failure) => emit(
        state.copyWith(status: UserStatus.error, errorMessage: failure.message),
      ),
      (users) => emit(state.copyWith(status: UserStatus.loaded, users: users)),
    );
  }

  Future<void> _onSaveUser(SaveUser event, Emitter<UserState> emit) async {
    emit(state.copyWith(status: UserStatus.loading));
    final result = await repository.saveUser(event.user, event.password);
    result.fold(
      (failure) => emit(
        state.copyWith(status: UserStatus.error, errorMessage: failure.message),
      ),
      (_) => add(LoadUsers()), // Refresh list
    );
  }

  Future<void> _onDeleteUser(DeleteUser event, Emitter<UserState> emit) async {
    emit(state.copyWith(status: UserStatus.loading));
    final result = await repository.deleteUser(event.id);
    result.fold(
      (failure) => emit(
        state.copyWith(status: UserStatus.error, errorMessage: failure.message),
      ),
      (_) => add(LoadUsers()), // Refresh list
    );
  }
}
