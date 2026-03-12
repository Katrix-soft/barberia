import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/database_helper.dart';
import 'core/theme/bloc/theme_bloc.dart';
import 'core/services/sync_service.dart';

import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/user_bloc.dart';

import 'features/customers/presentation/bloc/customer_bloc.dart';
import 'features/customers/domain/repositories/customer_repository.dart';
import 'features/customers/data/repositories/customer_repository_impl.dart';

import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/inventory/domain/repositories/inventory_repository.dart';
import 'features/inventory/data/repositories/inventory_repository_impl.dart';

import 'features/pos/presentation/bloc/pos_bloc.dart';
import 'features/pos/domain/repositories/pos_repository.dart';
import 'features/pos/data/repositories/pos_repository_impl.dart';

import 'features/booking/presentation/bloc/booking_bloc.dart';
import 'features/booking/domain/repositories/booking_repository.dart';
import 'features/booking/data/repositories/booking_repository_impl.dart';

import 'features/expenses/presentation/bloc/expense_bloc.dart';
import 'features/expenses/domain/repositories/expense_repository.dart';
import 'features/expenses/data/repositories/expense_repository_impl.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Features

  // Auth & Personnel (Multi-role)
  sl.registerFactory(() => AuthBloc(loginUseCase: sl(), repository: sl()));
  sl.registerFactory(() => UserBloc(repository: sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(databaseHelper: sl(), sharedPreferences: sl()),
  );

  // POS
  sl.registerFactory(() => PosBloc(repository: sl(), expenseRepository: sl()));
  sl.registerLazySingleton<PosRepository>(
    () => PosRepositoryImpl(databaseHelper: sl()),
  );

  // Inventory
  sl.registerFactory(() => InventoryBloc(repository: sl()));
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(databaseHelper: sl()),
  );

  // Customers (CRM)
  sl.registerFactory(() => CustomerBloc(repository: sl()));
  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(databaseHelper: sl()),
  );

  // Booking (Scheduling)
  sl.registerFactory(() => BookingBloc(repository: sl()));
  sl.registerLazySingleton<BookingRepository>(
    () => BookingRepositoryImpl(dbHelper: sl()),
  );

  // Expenses (Financial Tracker)
  sl.registerFactory(() => ExpenseBloc(repository: sl()));
  sl.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(dbHelper: sl()),
  );

  //! Core
  sl.registerLazySingleton(() => DatabaseHelper());
  sl.registerLazySingleton(() => SyncService(databaseHelper: sl()));
  
  // Theme
  sl.registerFactory(() => ThemeBloc(sharedPreferences: sl()));

  //! External
  final sharedPrefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPrefs);
}
