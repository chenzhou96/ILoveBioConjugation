import 'package:flutter/material.dart';

/// A quiet workspace palette. Color is reserved for meaningful status.
class AppColors {
  AppColors._();

  static AppPalette of(BuildContext context) =>
      AppPalette(Theme.of(context).brightness == Brightness.dark);

  static const bg = Color(0xFFFCFCFB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF6F6F4);
  static const sidebar = Color(0xFFF3F3F1);
  static const border = Color(0xFFE5E5E1);
  static const text = Color(0xFF242523);
  static const muted = Color(0xFF6D706A);
  static const primary = Color(0xFF2C302C);
  static const primaryLight = Color(0xFFECEEEA);
  static const primaryHover = Color(0xFF111411);
  static const accent = Color(0xFF637866);
  static const success = Color(0xFF337351);
  static const successBg = Color(0xFFF0F6F1);
  static const successFg = Color(0xFF285B3F);
  static const warning = Color(0xFFA6701D);
  static const warningBg = Color(0xFFFFF8E9);
  static const warningFg = Color(0xFF805817);
  static const infoBg = Color(0xFFF3F4F1);
  static const errorFg = Color(0xFFAA3F35);
  static const mainRed = Color(0xFF3E5446);
  static const mainRedBg = Color(0xFFF0F4EF);
  static const secondaryBlue = Color(0xFF647369);
  static const secondaryBlueBg = Color(0xFFF1F4F1);
}

/// Theme-aware colors for application surfaces and semantic status.
class AppPalette {
  final bool isDark;
  const AppPalette(this.isDark);

  Color get bg => isDark ? const Color(0xFF1C1E1C) : AppColors.bg;
  Color get surface => isDark ? const Color(0xFF242724) : AppColors.surface;
  Color get surfaceSoft =>
      isDark ? const Color(0xFF2D302D) : AppColors.surfaceSoft;
  Color get sidebar => isDark ? const Color(0xFF171917) : AppColors.sidebar;
  Color get border => isDark ? const Color(0xFF3B3F3B) : AppColors.border;
  Color get text => isDark ? const Color(0xFFF0F2ED) : AppColors.text;
  Color get muted => isDark ? const Color(0xFFADB3AA) : AppColors.muted;
  Color get primary => isDark ? const Color(0xFFE4E9DF) : AppColors.primary;
  Color get primaryLight =>
      isDark ? const Color(0xFF393F37) : AppColors.primaryLight;
  Color get primaryHover => isDark ? Colors.white : AppColors.primaryHover;
  Color get accent => isDark ? const Color(0xFFB0C5AE) : AppColors.accent;
  Color get success => isDark ? const Color(0xFF8BC6A1) : AppColors.success;
  Color get successBg => isDark ? const Color(0xFF26382C) : AppColors.successBg;
  Color get successFg => isDark ? const Color(0xFFA1D7B4) : AppColors.successFg;
  Color get warning => isDark ? const Color(0xFFDFB261) : AppColors.warning;
  Color get warningBg => isDark ? const Color(0xFF3B3220) : AppColors.warningBg;
  Color get warningFg => isDark ? const Color(0xFFE4BD78) : AppColors.warningFg;
  Color get infoBg => isDark ? const Color(0xFF30352E) : AppColors.infoBg;
  Color get errorBg =>
      isDark ? const Color(0xFF412924) : const Color(0xFFFCF0ED);
  Color get errorFg => isDark ? const Color(0xFFF0A59A) : AppColors.errorFg;
  Color get mainRed => accent;
  Color get mainRedBg => successBg;
  Color get secondaryBlue => muted;
  Color get secondaryBlueBg => surfaceSoft;
}
