import 'package:flutter/material.dart';

class AppTheme {
  // Eco-friendly, vibrant yet balanced core palette
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryMint = Color(0xFF10B981);
  static const Color oceanBlue = Color(0xFF0284C7);
  static const Color solarAmber = Color(0xFFF59E0B);
  static const Color sunsetCoral = Color(0xFFF97316);
  static const Color berryRose = Color(0xFFF43F5E);
  static const Color royalPurple = Color(0xFF8B5CF6);
  static const Color deepForest = Color(0xFF065F46);

  // Modern Eco Gradients
  static const List<Color> ecoTealGradient = [Color(0xFF0F766E), Color(0xFF14B8A6)];
  static const List<Color> oceanGradient = [Color(0xFF0369A1), Color(0xFF38BDF8)];
  static const List<Color> solarGradient = [Color(0xFFB45309), Color(0xFFFBBF24)];
  static const List<Color> mintGradient = [Color(0xFF047857), Color(0xFF34D399)];
  static const List<Color> purpleGradient = [Color(0xFF6D28D9), Color(0xFFA78BFA)];
  static const List<Color> coralGradient = [Color(0xFFC2410C), Color(0xFFFB923C)];
  static const List<Color> darkEmeraldHero = [Color(0xFF064E3B), Color(0xFF0D9488)];
  static const List<Color> darkNavyHero = [Color(0xFF0F172A), Color(0xFF1E3A8A)];

  // Light Theme with an airy, eco-friendly sage-tinted background and crisp surfaces
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryTeal,
      primary: primaryTeal,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFCCFBF1),
      onPrimaryContainer: const Color(0xFF115E59),
      secondary: oceanBlue,
      secondaryContainer: const Color(0xFFE0F2FE),
      onSecondaryContainer: const Color(0xFF075985),
      tertiary: solarAmber,
      tertiaryContainer: const Color(0xFFFEF3C7),
      onTertiaryContainer: const Color(0xFF92400E),
      surface: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF4F8F6),
      surfaceContainer: const Color(0xFFEBF2EF),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF3F7F5),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2EBE6), width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF4F8F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE7E1), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE7E1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryTeal, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: const Color(0xFFCCFBF1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryTeal);
        }
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B));
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryTeal, size: 24);
        }
        return const IconThemeData(color: Color(0xFF64748B), size: 24);
      }),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryTeal,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
  );

  // Dark Theme with rich eco-slate midnight background and subtle radiant surfaces
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF14B8A6),
      primary: const Color(0xFF14B8A6),
      onPrimary: const Color(0xFF042F2C),
      primaryContainer: const Color(0xFF134E48),
      onPrimaryContainer: const Color(0xFF99F6E4),
      secondary: const Color(0xFF38BDF8),
      secondaryContainer: const Color(0xFF0369A1),
      onSecondaryContainer: const Color(0xFFBAE6FD),
      tertiary: const Color(0xFFFBBF24),
      tertiaryContainer: const Color(0xFF78350F),
      onTertiaryContainer: const Color(0xFFFEF3C7),
      surface: const Color(0xFF122228),
      surfaceContainerLowest: const Color(0xFF0B1417),
      surfaceContainerLow: const Color(0xFF0F1B20),
      surfaceContainer: const Color(0xFF162930),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0A1317),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: const Color(0xFF122228),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E353E), width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: const Color(0xFF042F2C),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF162930),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E353E), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E353E), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0D181D),
      elevation: 0,
      indicatorColor: const Color(0xFF134E48),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2DD4BF));
        }
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8));
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF2DD4BF), size: 24);
        }
        return const IconThemeData(color: Color(0xFF94A3B8), size: 24);
      }),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF14B8A6),
      foregroundColor: Color(0xFF042F2C),
      elevation: 2,
    ),
  );

  // Category and resource color mappings for delightful harmonious visuals
  static Color categoryColor(String category) => switch (category.toLowerCase()) {
    'electricity' => const Color(0xFFF59E0B), // Solar Amber
    'water' => const Color(0xFF0284C7), // Ocean Blue
    'gas' || 'lpg' => const Color(0xFFF97316), // Sunset Coral
    'groceries' => const Color(0xFF10B981), // Fresh Mint
    'cleaning' => const Color(0xFF06B6D4), // Clean Cyan
    'kitchen' => const Color(0xFFEAB308), // Warm Gold
    'bathroom' => const Color(0xFF3B82F6), // Sky Blue
    'electronics' => const Color(0xFF8B5CF6), // Royal Purple
    'fuel' => const Color(0xFFEF4444), // Energy Red
    'internet' || 'wifi' => const Color(0xFF6366F1), // Indigo
    'maintenance' => const Color(0xFF0D9488), // Eco Teal
    'rent' => const Color(0xFFEC4899), // Pink / Housing
    _ => const Color(0xFF14B8A6),
  };

  static Color categoryBackground(String category, bool isDark) {
    final color = categoryColor(category);
    return isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.12);
  }
}
