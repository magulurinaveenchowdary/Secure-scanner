// lib/themes.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ SecureScan Blue/White Theme — Light + Dark Modes
///
/// This file contains:
/// - ThemeData definitions (lightTheme & darkTheme)
/// - SecureScanThemeController: a small singleton that exposes a ValueNotifier<ThemeMode>
///   and persists the user's selection to SharedPreferences.
///
/// Usage:
/// 1) Call `await SecureScanThemeController.instance.init()` before runApp (or early in main).
/// 2) Wrap MaterialApp with a ValueListenableBuilder on
///    `SecureScanThemeController.instance.themeModeNotifier` and set `themeMode`.
/// 3) From settings screen call `SecureScanThemeController.instance.setTheme('Light'|'Dark'|'System Mode')`.
///

class SecureScanTheme {
  // ---------------- PRIMARY COLORS ----------------
  static const Color brandBlue = Color(
    0xFF0D1B2A,
  ); // dark blue (used for headings in light)
  static const Color brandGray = Color(
    0xFF4F5D75,
  ); // dark gray (light-mode body)
  static const Color accentBlue = Color(0xFF006EFF); // vibrant accent
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // ---------------- TEXT STYLES ----------------

  /// Headings: Inter SemiBold, 22–24sp (fallback to system font)
  static TextStyle get headingLight => GoogleFonts.inter(
    fontWeight: FontWeight.w600,
    fontSize: 22,
    color: brandBlue,
  );

  static TextStyle get headingDark => GoogleFonts.inter(
    fontWeight: FontWeight.w600,
    fontSize: 22,
    color: white,
  );

  /// Body: Inter Regular, 14–16sp (fallback to system font)
  static TextStyle get bodyLight => GoogleFonts.inter(
    fontWeight: FontWeight.w400,
    fontSize: 15,
    color: brandGray,
  );

  // stronger contrast for dark mode body text for readability
  static TextStyle get bodyDark => GoogleFonts.inter(
    fontWeight: FontWeight.w400,
    fontSize: 15,
    color: Colors.white.withOpacity(0.92), // near-white for legibility
  );

  /// Buttons: Roboto Medium (fallback to system font)
  static TextStyle get buttonLight => GoogleFonts.roboto(
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: white,
  );

  static TextStyle get buttonDark => GoogleFonts.roboto(
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: white,
  );

  /// Onboarding Titles: Poppins SemiBold (fallback to system font)
  static TextStyle get onboardingTitleLight => GoogleFonts.poppins(
    fontWeight: FontWeight.w600,
    fontSize: 22,
    color: brandBlue,
  );

  static TextStyle get onboardingTitleDark => GoogleFonts.poppins(
    fontWeight: FontWeight.w600,
    fontSize: 22,
    color: white,
  );

  // ---------------- LIGHT THEME ----------------
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: white,
    primaryColor: accentBlue,
    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      elevation: 0,
      iconTheme: IconThemeData(color: brandBlue),
      titleTextStyle: TextStyle(
        color: brandBlue,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: accentBlue,
      onPrimary: white,
      surface: white,
      onSurface: brandBlue,
      background: white,
      onBackground: brandGray,
    ),
    textTheme: TextTheme(
      headlineLarge: headingLight.copyWith(fontSize: 24),
      headlineMedium: headingLight,
      headlineSmall: headingLight.copyWith(fontSize: 20),
      bodyLarge: bodyLight,
      bodyMedium: bodyLight.copyWith(fontSize: 14),
      labelLarge: buttonLight,
      titleLarge: onboardingTitleLight,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentBlue,
        textStyle: buttonLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentBlue,
        textStyle: buttonLight,
      ),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  // ---------------- DARK THEME ----------------
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0D1117), // near-black background
    primaryColor: accentBlue,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D1117),
      elevation: 0,
      iconTheme: IconThemeData(color: white),
      titleTextStyle: TextStyle(
        color: white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: accentBlue,
      onPrimary: Colors.white,
      surface: Color(0xFF0E1318),
      onSurface: Colors.white,
      background: Color(0xFF0D1117),
      onBackground: Colors.white,
    ),
    textTheme: TextTheme(
      headlineLarge: headingDark.copyWith(fontSize: 24),
      headlineMedium: headingDark,
      // slightly larger size for small headings for readability
      headlineSmall: headingDark.copyWith(fontSize: 20),
      // use near-white with high opacity for body text so it's readable
      bodyLarge: bodyDark,
      bodyMedium: bodyDark.copyWith(fontSize: 14),
      labelLarge: buttonDark,
      titleLarge: onboardingTitleDark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentBlue,
        textStyle: buttonDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentBlue,
        textStyle: buttonDark,
      ),
    ),
    cardColor: const Color(0xFF0F151A),
    canvasColor: const Color(0xFF0D1117),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

/// ------------------ Theme Controller (singleton) ------------------
///
/// Small controller to change ThemeMode at runtime and persist the choice
/// in SharedPreferences. This keeps the theme logic inside this file only.
class SecureScanThemeController {
  SecureScanThemeController._private();
  static final SecureScanThemeController instance =
      SecureScanThemeController._private();

  static const String _prefKey =
      'themeMode'; // stores 'Light'|'Dark'|'System Mode'

  /// Exposed notifier that you can listen to in MaterialApp
  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  /// Call once at app startup (before runApp or early) to load the persisted value.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey) ?? 'System Mode';
    themeModeNotifier.value = _stringToThemeMode(saved);
  }

  /// Set theme and persist choice (modeString: 'Light'|'Dark'|'System Mode')
  Future<void> setTheme(String modeString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, modeString);
    themeModeNotifier.value = _stringToThemeMode(modeString);
  }

  static ThemeMode _stringToThemeMode(String s) {
    switch (s) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System Mode';
    }
  }
}
