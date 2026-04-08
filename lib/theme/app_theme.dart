import 'package:flutter/material.dart';

extension AppThemeColors on BuildContext {
  AppPalette get appPalette => AppPalette.of(this);
}

class AppPalette {
  AppPalette._(this.isDark);

  factory AppPalette.light() => AppPalette._(false);
  factory AppPalette.dark() => AppPalette._(true);

  factory AppPalette.of(BuildContext context) {
    return AppPalette._(Theme.of(context).brightness == Brightness.dark);
  }

  final bool isDark;

  Color get background => isDark
      ? const Color(0xFF07111F)
      : const Color(0xFFF5F7FB);
  Color get backgroundSoft => isDark
      ? const Color(0xFF0D1726)
      : const Color(0xFFF7F9FF);
  Color get surface => isDark ? const Color(0xFF101C2C) : Colors.white;
  Color get surfaceRaised => isDark
      ? const Color(0xFF162334)
      : const Color(0xFFFFFFFF);
  Color get surfaceMuted => isDark
      ? const Color(0xFF19283A)
      : const Color(0xFFF3F6FC);
  Color get surfaceAccent => isDark
      ? const Color(0xFF112847)
      : const Color(0xFFEAF2FF);
  Color get textPrimary => isDark
      ? const Color(0xFFF4F8FF)
      : const Color(0xFF20232B);
  Color get textSecondary => isDark
      ? const Color(0xFFA8B6C9)
      : const Color(0xFF8A92A6);
  Color get textMuted => isDark
      ? const Color(0xFF7E8DA3)
      : const Color(0xFF9AA2BA);
  Color get border => isDark
      ? const Color(0xFF233248)
      : const Color(0xFFE2E8F4);
  Color get shadow => Colors.black.withValues(alpha: isDark ? 0.28 : 0.05);
  Color get primary => const Color(0xFF2E7BEF);
  Color get primaryStrong => isDark
      ? const Color(0xFF60A5FA)
      : const Color(0xFF1F5FD4);
  Color get success => const Color(0xFF2FA95E);
  Color get successSurface => isDark
      ? const Color(0xFF11281C)
      : const Color(0xFFEAF8F0);
  Color get warning => const Color(0xFFE98942);
  Color get warningSurface => isDark
      ? const Color(0xFF2A1D13)
      : const Color(0xFFFFF4ED);
  Color get danger => const Color(0xFFE0675F);
  Color get dangerSurface => isDark
      ? const Color(0xFF2C1817)
      : const Color(0xFFFFF1EE);
  Color get activeSurface => isDark
      ? const Color(0xFF142C4C)
      : const Color(0xFFF1F6FF);
  Color get overlay => Colors.black.withValues(alpha: isDark ? 0.34 : 0.18);
}
