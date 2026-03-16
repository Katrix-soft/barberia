import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';
import 'package:flutter/material.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences sharedPreferences;

  ThemeBloc({required this.sharedPreferences})
    : super(ThemeState(_getInitialTheme(sharedPreferences))) {
    on<ToggleTheme>((event, emit) async {
      final newMode = state.themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
      await sharedPreferences.setString('theme_mode', newMode.name);
      emit(ThemeState(newMode));
    });

    on<LoadTheme>((event, emit) {
      emit(ThemeState(_getInitialTheme(sharedPreferences)));
    });
  }

  static ThemeMode _getInitialTheme(SharedPreferences prefs) {
    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme != null) {
      return ThemeMode.values.firstWhere(
        (e) => e.name == savedTheme,
        orElse: () => ThemeMode.dark,
      );
    }
    return ThemeMode.dark; // Por defecto modo oscuro predeterminado
  }
}
