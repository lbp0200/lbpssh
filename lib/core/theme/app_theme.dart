import 'package:flutter/material.dart';

class LinearColors {
  // Background Surfaces
  static const Color background = Color(0xFF08090a);
  static const Color panel = Color(0xFF0f1011);
  static const Color surface = Color(0xFF191a1b);
  static const Color surfaceElevated = Color(0xFF28282c);

  // Text Colors
  static const Color textPrimary = Color(0xFFf7f8f8);
  static const Color textSecondary = Color(0xFFd0d6e0);
  static const Color textTertiary = Color(0xFF8a8f98);
  static const Color textQuaternary = Color(0xFF62666d);

  // Brand & Accent
  static const Color accent = Color(0xFF5e6ad2);
  static const Color accentInteractive = Color(0xFF7170ff);
  static const Color accentHover = Color(0xFF828fff);

  // Fill Colors
  static Color fillSurface = const Color(0x1afffffff); // rgba(255,255,255,0.1) - default
  static Color fillSurfaceHover = const Color(0x26ffffff); // rgba(255,255,255,0.15) - hover

  // Borders (semi-transparent)
  static Color borderSubtle = const Color(0x0Dffffff); // rgba(255,255,255,0.05)
  static Color borderStandard = const Color(0x14ffffff); // rgba(255,255,255,0.08)
  static const Color borderSolid = Color(0xFF23252a);

  // Functional Status Colors
  static const Color success = Color(0xFF27a644);
  static const Color error = Color(0xFFf85149);
  static const Color warning = Color(0xFFd29922);
}

class LinearSpacing {
  static const double spacing1 = 1.0;
  static const double spacing4 = 4.0;
  static const double spacing7 = 7.0;
  static const double spacing8 = 8.0;
  static const double spacing11 = 11.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing19 = 19.0;
  static const double spacing20 = 20.0;
  static const double spacing22 = 22.0;
  static const double spacing24 = 24.0;
  static const double spacing28 = 28.0;
  static const double spacing32 = 32.0;
  static const double spacing35 = 35.0;
}

class LinearRadius {
  static const double micro = 2.0;
  static const double small = 4.0;
  static const double standard = 6.0;
  static const double card = 8.0;
  static const double panel = 12.0;
  static const double large = 22.0;
  static const double pill = 9999.0;
}

class LinearDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
}

class AppTheme {
  // Legacy spacing (keep existing values for backward compat)
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // === Updated Themes ===

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: lightAccent,
      secondary: lightAccent,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightSurfaceRaised,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: lightSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: lightBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: lightAccent, width: 2),
      ),
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      labelStyle: const TextStyle(color: lightTextSecondary, height: 1.2),
      hintStyle: const TextStyle(color: lightTextTertiary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: lightBorderSubtle,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: lightTextSecondary),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, color: lightTextPrimary),
      titleMedium: TextStyle(fontWeight: FontWeight.w500, color: lightTextPrimary),
      titleSmall: TextStyle(fontWeight: FontWeight.w500, color: lightTextPrimary),
      bodyLarge: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextSecondary),
      bodySmall: TextStyle(color: lightTextTertiary),
      labelLarge: TextStyle(color: lightTextSecondary),
      labelMedium: TextStyle(color: lightTextTertiary),
      labelSmall: TextStyle(color: lightTextTertiary),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightTextPrimary,
      contentTextStyle: const TextStyle(color: lightBackground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: LinearColors.background,
    colorScheme: const ColorScheme.dark(
      primary: LinearColors.accentInteractive,
      secondary: LinearColors.accentInteractive,
      surface: LinearColors.panel,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: LinearColors.textPrimary,
      surfaceContainerHighest: LinearColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: LinearColors.panel,
      surfaceTintColor: Colors.transparent,
      foregroundColor: LinearColors.textPrimary,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: LinearColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadius.card),
        side: BorderSide(color: LinearColors.borderStandard),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: false,
      fillColor: const Color(0x1afffffff),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LinearRadius.standard),
        borderSide: BorderSide(color: LinearColors.borderStandard),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LinearRadius.standard),
        borderSide: BorderSide(color: LinearColors.borderStandard),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LinearRadius.standard),
        borderSide: const BorderSide(color: LinearColors.accentInteractive, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      labelStyle: const TextStyle(color: LinearColors.textSecondary, height: 1.2),
      hintStyle: const TextStyle(color: LinearColors.textQuaternary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: LinearColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadius.standard)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LinearColors.accentInteractive,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadius.standard)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LinearColors.textPrimary,
        side: const BorderSide(color: LinearColors.borderSolid),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadius.standard)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: LinearColors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadius.standard)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: LinearColors.borderSolid,
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: LinearColors.textSecondary),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w500, color: LinearColors.textPrimary, letterSpacing: -0.704),
      headlineMedium: TextStyle(fontWeight: FontWeight.w400, color: LinearColors.textPrimary, letterSpacing: -0.288),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: LinearColors.textPrimary, letterSpacing: -0.24),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, color: LinearColors.textPrimary),
      titleMedium: TextStyle(fontWeight: FontWeight.w500, color: LinearColors.textPrimary),
      titleSmall: TextStyle(fontWeight: FontWeight.w500, color: LinearColors.textPrimary),
      bodyLarge: TextStyle(color: LinearColors.textSecondary, letterSpacing: -0.165),
      bodyMedium: TextStyle(color: LinearColors.textSecondary),
      bodySmall: TextStyle(color: LinearColors.textTertiary),
      labelLarge: TextStyle(color: LinearColors.textSecondary, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: LinearColors.textTertiary, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: LinearColors.textQuaternary),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: LinearColors.textPrimary,
      iconColor: LinearColors.textSecondary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: LinearColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadius.panel),
        side: BorderSide(color: LinearColors.borderStandard),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: LinearColors.surfaceElevated,
      contentTextStyle: const TextStyle(color: LinearColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadius.standard)),
      behavior: SnackBarBehavior.floating,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: LinearColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadius.card),
        side: BorderSide(color: LinearColors.borderStandard),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: LinearColors.panel,
      selectedIconTheme: IconThemeData(color: LinearColors.accentInteractive),
      unselectedIconTheme: IconThemeData(color: LinearColors.textSecondary),
      selectedLabelTextStyle: TextStyle(color: LinearColors.accentInteractive, fontWeight: FontWeight.w500),
      unselectedLabelTextStyle: TextStyle(color: LinearColors.textSecondary),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: LinearColors.accentInteractive,
      unselectedLabelColor: LinearColors.textTertiary,
      indicatorColor: LinearColors.accentInteractive,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: LinearColors.surfaceElevated,
        borderRadius: BorderRadius.circular(LinearRadius.micro),
        border: Border.all(color: LinearColors.borderStandard),
      ),
      textStyle: const TextStyle(color: LinearColors.textPrimary, fontSize: 12),
    ),
  );

  // Backward compatibility aliases
  static const Color accentGreen = LinearColors.accent;
  static const Color primaryDark = LinearColors.background;
  static const Color secondaryDark = LinearColors.panel;
  static const Color backgroundDark = LinearColors.background;
  static const Color surfaceDark = LinearColors.surface;
  static const Color cardDark = LinearColors.surface;
  static const Color terminalBackground = Color(0xFF1E1E1E);
  static const Color terminalForeground = Color(0xFFD4D4D4);

  // === Light Mode Semantic Colors (kept for lightTheme above) ===
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF6F8FA);
  static const Color lightSurfaceRaised = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFD0D7DE);
  static const Color lightBorderSubtle = Color(0xFFEAECEF);
  static const Color lightTextPrimary = Color(0xFF1F2328);
  static const Color lightTextSecondary = Color(0xFF656D76);
  static const Color lightTextTertiary = Color(0xFF8C959F);
  static const Color lightAccent = Color(0xFF2563EB);  // Royal Blue
  static const Color lightAccentHover = Color(0xFF3B82F6);  // Bright Blue
  static const Color lightAccentMuted = Color(0x1A2563EB);  // 10% opacity blue
}
