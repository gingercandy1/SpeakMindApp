/// F0: SpeakMind visual theme, from the final planning doc (p.11).
///
/// Travel-journal game style. Light theme only; dark mode is deferred
/// to F4 by the doc, so no darkTheme is built here.
library;

import 'package:material_ui/material_ui.dart';

/// Fixed palette from the final planning doc.
abstract class SpeakMindColors {
  /// Cream paper background.
  static const Color cream = Color(0xFFFFF7EA);

  /// Deep teal-green, main colour.
  static const Color deepTeal = Color(0xFF173F3A);

  /// Action green.
  static const Color actionGreen = Color(0xFF1F7A6D);

  /// Reward amber.
  static const Color amber = Color(0xFFE8A33D);

  /// Accent terracotta red.
  static const Color terracotta = Color(0xFFC7502B);

  /// Body text, dark brown-black.
  static const Color ink = Color(0xFF2B2118);

  /// Gold for 3-star nodes.
  static const Color starGold = Color(0xFFFFC93C);

  /// Fog over undiscovered worlds.
  static const Color fog = Color(0xFFB9B2A4);
}

/// The app theme: cream background, deep-teal primary, fully round buttons,
/// 16dp cards (doc p.11).
ThemeData speakMindTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: SpeakMindColors.actionGreen,
    onPrimary: Colors.white,
    secondary: SpeakMindColors.amber,
    onSecondary: SpeakMindColors.ink,
    surface: SpeakMindColors.cream,
    onSurface: SpeakMindColors.ink,
    error: SpeakMindColors.terracotta,
    onError: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: SpeakMindColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: SpeakMindColors.cream,
      foregroundColor: SpeakMindColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: SpeakMindColors.cream,
      selectedItemColor: SpeakMindColors.actionGreen,
      unselectedItemColor: SpeakMindColors.fog,
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SpeakMindColors.actionGreen,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
  );
}
