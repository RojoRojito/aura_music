import 'package:flutter/material.dart';

class AuraColors {
  static const Color background  = Color(0xFF0A0A0F);
  static const Color surface     = Color(0xFF13131A);
  static const Color surfaceHigh = Color(0xFF1E1E28);
  static const Color primary     = Color(0xFF7C4DFF);
  static const Color secondary   = Color(0xFF00E5FF);
  static const Color accent      = Color(0xFFFF4081);
  static const Color text        = Color(0xFFE8E8F0);
  static const Color textMuted   = Color(0xFF8888AA);
  static const Color divider     = Color(0xFF2A2A3A);

  static const Color lightBackground  = Color(0xFFF5F5F7);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFF0F0F5);
  static const Color lightText        = Color(0xFF1A1A2E);
  static const Color lightTextMuted   = Color(0xFF6B6B80);
  static const Color lightDivider     = Color(0xFFE0E0E5);
}

class AuraTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AuraColors.primary,
        secondary: AuraColors.secondary,
        surface: AuraColors.surface,
      ),
      scaffoldBackgroundColor: AuraColors.background,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AuraColors.surface,
        indicatorColor: AuraColors.primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: AuraColors.textMuted, fontSize: 11),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AuraColors.primary,
        inactiveTrackColor: AuraColors.divider,
        thumbColor: Colors.white,
        overlayColor: AuraColors.primary.withOpacity(0.2),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AuraColors.primary,
        secondary: AuraColors.secondary,
        surface: AuraColors.lightSurface,
      ),
      scaffoldBackgroundColor: AuraColors.lightBackground,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AuraColors.lightSurface,
        indicatorColor: AuraColors.primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: AuraColors.lightTextMuted, fontSize: 11),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AuraColors.primary,
        inactiveTrackColor: AuraColors.lightDivider,
        thumbColor: Colors.white,
        overlayColor: AuraColors.primary.withOpacity(0.15),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
    );
  }
}