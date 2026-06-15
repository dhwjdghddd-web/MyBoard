import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kPrimaryLight = Color(0xFF1A73E8);
const kPrimaryDark = Color(0xFF82B1FF);
const kBgLight = Color(0xFFF0F2F5);
const kBgDark = Color(0xFF151524);
const kSurfaceLight = Colors.white;
const kSurfaceDark = Color(0xFF1E1E30);

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryLight,
          surface: kSurfaceLight,
        ),
        scaffoldBackgroundColor: kBgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: kSurfaceLight,
        ),
        cardTheme: const CardThemeData(
          color: kSurfaceLight,
          elevation: 1,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryDark,
          brightness: Brightness.dark,
          surface: kSurfaceDark,
        ),
        scaffoldBackgroundColor: kBgDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF151524),
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: kSurfaceDark,
        ),
        cardTheme: const CardThemeData(
          color: kSurfaceDark,
          elevation: 1,
        ),
      );
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('g-theme');
    if (saved == 'dark') {
      state = ThemeMode.dark;
    } else if (saved == 'light') {
      state = ThemeMode.light;
    }
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    if (state == ThemeMode.light) {
      state = ThemeMode.dark;
      await prefs.setString('g-theme', 'dark');
    } else if (state == ThemeMode.dark) {
      state = ThemeMode.system;
      await prefs.remove('g-theme');
    } else {
      state = ThemeMode.light;
      await prefs.setString('g-theme', 'light');
    }
  }
}
