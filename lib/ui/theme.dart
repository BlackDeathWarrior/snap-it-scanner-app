import 'package:flutter/material.dart';

const kAccent = Color(0xFF1DE9B6);
const _kSurface = Color(0xFF0D0D0D);
const _kSurfaceVariant = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2A2A2A);

ThemeData _buildDarkTheme() {
  final cs = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.dark,
  ).copyWith(
    surface: _kSurface,
    onSurface: Colors.white,
    surfaceContainerHighest: _kSurfaceVariant,
    primary: kAccent,
    onPrimary: Colors.black,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: _kSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _kSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _kBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: _kSurfaceVariant,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: _kSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: _kBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(color: _kBorder),
    iconTheme: const IconThemeData(color: Colors.white70),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white60),
      labelMedium: TextStyle(color: kAccent, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccent,
        side: const BorderSide(color: kAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: Colors.black,
    ),
  );
}

// Both themes are dark — scanners always look better dark.
final appTheme = _buildDarkTheme();
final appDarkTheme = _buildDarkTheme();
