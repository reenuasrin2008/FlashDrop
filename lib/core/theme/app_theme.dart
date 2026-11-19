import 'package:flutter/material.dart';

class FlashDropGradients {
  FlashDropGradients._();

  static LinearGradient canvas(Brightness brightness) {
    return brightness == Brightness.dark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141414), Color(0xFF0A0A0A)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAFAFA), Color(0xFFF1F1EE)],
          );
  }

  static LinearGradient primaryTile(Brightness brightness) {
    return brightness == Brightness.dark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F4F2), Color(0xFFD6D6D2)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF262626), Color(0xFF0F0F0F)],
          );
  }

  static LinearGradient secondaryTile(Brightness brightness) {
    return brightness == Brightness.dark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF262626), Color(0xFF171717)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFEBEBE7)],
          );
  }

  static LinearGradient cardSurface(Brightness brightness) {
    return brightness == Brightness.dark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B1B1B), Color(0xFF131313)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF6F6F4)],
          );
  }
}

class FlashDropTheme {
  FlashDropTheme._();

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF171717),
      onPrimary: Color(0xFFFAFAFA),
      primaryContainer: Color(0xFFE7E7E4),
      onPrimaryContainer: Color(0xFF141414),
      secondary: Color(0xFF404040),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFEBEBE8),
      onSecondaryContainer: Color(0xFF1C1C1C),
      error: Color(0xFFB91C1C),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFF7F7F5),
      onSurface: Color(0xFF141414),
      surfaceContainerHighest: Color(0xFFE6E6E2),
      onSurfaceVariant: Color(0xFF666661),
      outline: Color(0xFF8C8C86),
      outlineVariant: Color(0xFFDFDFDA),
    );

    return _buildTheme(scheme);
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFF2F2F0),
      onPrimary: Color(0xFF0E0E0E),
      primaryContainer: Color(0xFF262626),
      onPrimaryContainer: Color(0xFFF5F5F3),
      secondary: Color(0xFFB8B8B3),
      onSecondary: Color(0xFF121212),
      secondaryContainer: Color(0xFF1E1E1E),
      onSecondaryContainer: Color(0xFFE8E8E5),
      error: Color(0xFFEF4444),
      onError: Color(0xFF141414),
      surface: Color(0xFF0D0D0D),
      onSurface: Color(0xFFF2F2F0),
      surfaceContainerHighest: Color(0xFF242424),
      onSurfaceVariant: Color(0xFF9A9A94),
      outline: Color(0xFF52524E),
      outlineVariant: Color(0xFF2B2B28),
    );

    return _buildTheme(scheme);
  }

  static ThemeData _buildTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.0,
        ),
        headlineSmall: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleMedium: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          color: scheme.onSurface,
          height: 1.45,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? const Color(0xFF161616) : const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
