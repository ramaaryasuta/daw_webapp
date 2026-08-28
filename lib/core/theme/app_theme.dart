import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF111318),

      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C5CFC),
        brightness: Brightness.dark,
      ),

      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
        ),
      ),
    );
  }
}
