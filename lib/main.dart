import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/bloc/theme_bloc.dart';
import 'core/theme/bloc/theme_event.dart';
import 'core/theme/bloc/theme_state.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/bloc/user_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/customers/presentation/bloc/customer_event.dart';
import 'features/customers/presentation/bloc/customer_bloc.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/pos/presentation/bloc/pos_bloc.dart';
import 'features/pos/presentation/pages/pos_page.dart';
import 'features/booking/presentation/bloc/booking_bloc.dart';
import 'features/booking/presentation/bloc/booking_event.dart';
import 'features/expenses/presentation/bloc/expense_bloc.dart';
import 'features/expenses/presentation/bloc/expense_event.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/push_notification_service.dart';
import 'injection_container.dart' as di;
import 'core/widgets/force_update_guard.dart';
import 'core/database/database_helper.dart';

import 'core/database/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();
  await initializeDateFormatting('es_ES', null);
  await di.init();
  
  // CRITICAL: Guarantee database is ready and 'nacho' is seeded BEFORE UI
  try {
    debugPrint('[Main] Forcing early database initialization...');
    await di.sl<DatabaseHelper>().database;
    debugPrint('[Main] Database ready.');
  } catch (e) {
    debugPrint('[Main] Early DB init failed: $e');
  }
  
  // Initialize Push Notifications (Web)
  await PushNotificationService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ForceUpdateGuard(
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => di.sl<AuthBloc>()..add(AuthCheckRequested()),
          ),
          BlocProvider(create: (_) => di.sl<PosBloc>()),
          BlocProvider(create: (_) => di.sl<InventoryBloc>()),
          BlocProvider(
            create: (_) => di.sl<CustomerBloc>()..add(LoadCustomers()),
          ),
          BlocProvider(create: (_) => di.sl<UserBloc>()),
          BlocProvider(create: (_) => di.sl<ThemeBloc>()..add(LoadTheme())),
          BlocProvider(
            create: (_) => di.sl<BookingBloc>()..add(LoadAppointments()),
          ),
          BlocProvider(create: (_) => di.sl<ExpenseBloc>()..add(LoadExpenses())),
        ],
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp(
              title: 'Katrix Barber',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeState.themeMode,
              home: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is Authenticated) {
                    return const PosPage();
                  }
                  if (state is Unauthenticated ||
                      state is AuthError ||
                      state is AuthLoading) {
                    return const LoginScreen();
                  }
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
