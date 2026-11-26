import 'package:flutter/material.dart';

/// Colours for the tab pages, resolved for the current brightness.
@immutable
class AppPalette {
  const AppPalette._({
    required this.text,
    required this.muted,
    required this.card,
    required this.border,
    required this.bar,
    required this.accent,
    required this.missed,
    required this.incoming,
    required this.outgoing,
    required this.declined,
  });

  static const AppPalette light = AppPalette._(
    text: Color(0xFF14212E),
    muted: Color(0xFF5F6B7A),
    card: Colors.white,
    border: Color(0x1F0A1929),
    bar: Colors.white,
    accent: Color(0xFF1E6FD9),
    missed: Color(0xFFD93025),
    incoming: Color(0xFF257DE0),
    outgoing: Color(0xFF00B894),
    declined: Color(0xFFF2A600),
  );

  static const AppPalette dark = AppPalette._(
    text: Colors.white,
    muted: Color(0xFF90B0CB),
    card: Color(0x14FFFFFF),
    border: Color(0x1AFFFFFF),
    bar: Color(0xFF0F2236),
    accent: Color(0xFF42A5F5),
    missed: Color(0xFFEB6263),
    incoming: Color(0xFF338CED),
    outgoing: Color(0xFF00A888),
    declined: Color(0xFFD28E05),
  );

  static AppPalette of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;

  final Color text;
  final Color muted;
  final Color card;
  final Color border;
  final Color bar;
  final Color accent;

  /// Call-type colours, shared by recents icons and the stats chart. In the order
  /// incoming, missed, outgoing, declined they pass the colour-blind checks on both surfaces;
  /// charts must still add gaps and labelled legends.
  final Color missed;
  final Color incoming;
  final Color outgoing;
  final Color declined;
}

class AppTheme {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF1E6FD9);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFB00020);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF000000);
  static const Color onSurface = Color(0xFF000000);

  static const Color darkPrimaryColor = Color(0xFF42A5F5);
  static const Color darkBackgroundColor = Color(0xFF0A1929);
  static const Color darkSurfaceColor = Color(0xFF1C3A5E);
  static const Color darkOnSurface = Color(0xFFFFFFFF);

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1929), Color(0xFF1C3A5E)],
  );

  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
  );

  static LinearGradient getBackgroundGradient(bool isDark) {
    return isDark ? darkGradient : lightGradient;
  }

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      secondaryContainer: Color(0xFFD6E6FB),
      onSecondaryContainer: Color(0xFF0B2A55),
      surface: surfaceColor,
      error: errorColor,
      onPrimary: onPrimary,
      onSecondary: onPrimary,
      onSurface: onSurface,
      onError: onPrimary,
    ),
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: primaryColor,
      foregroundColor: onPrimary,
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimaryColor,
      secondary: darkPrimaryColor,
      onSecondary: darkBackgroundColor,
      secondaryContainer: Color(0xFF1E4A7A),
      onSecondaryContainer: Colors.white,
      surface: darkSurfaceColor,
      onSurface: darkOnSurface,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: darkBackgroundColor,
      foregroundColor: darkOnSurface,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(color: Color(0xFF90B0CB)),
      titleMedium: TextStyle(color: Colors.white),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
  );
}

