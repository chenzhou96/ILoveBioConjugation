import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colors = AppPalette(brightness == Brightness.dark);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: BorderSide(color: colors.border),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: colors.primary,
            brightness: brightness,
            surface: colors.surface,
          ).copyWith(
            primary: colors.primary,
            onPrimary: brightness == Brightness.dark
                ? Color(0xFF20231F)
                : Colors.white,
            primaryContainer: colors.primaryLight,
            secondaryContainer: colors.primaryLight,
            onSecondaryContainer: colors.text,
            onPrimaryContainer: colors.text,
            outline: colors.border,
            error: colors.errorFg,
          ),
      scaffoldBackgroundColor: colors.bg,
      dividerColor: colors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: colors.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: colors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        hintStyle: TextStyle(color: colors.muted, fontSize: 12),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(38, 36),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(38, 36),
          side: BorderSide(color: colors.border),
          shape: shape,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: Size(38, 36), shape: shape),
      ),
      textTheme: TextTheme(
        labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 14, height: 1.5, color: colors.text),
        bodyMedium: TextStyle(fontSize: 13, height: 1.45, color: colors.text),
        bodySmall: TextStyle(fontSize: 12, height: 1.45, color: colors.muted),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.text,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.text,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.text,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.text,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryLight,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: colors.text),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.primary,
        shape: shape,
      ),
    );
  }
}
