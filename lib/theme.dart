/// F0: SpeakMind visual theme, from the final planning doc (p.11).
///
/// Travel-journal game style. F4 adds the dark theme the doc deferred:
/// the journal palette goes dark-teal instead of cream, with the same
/// action green / amber / terracotta accents.
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

  /// Dark-mode page background (deep teal-black).
  static const Color darkSurface = Color(0xFF16211D);

  /// Dark-mode card surface.
  static const Color darkCard = Color(0xFF223129);

  /// Chispa's speech / challenge card: warm yellow in light mode, dark
  /// teal container in dark mode. Use with `Theme.of(context).brightness`.
  static Color chispaCard(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF2A3D33)
          : const Color(0xFFFFF3D6);

  /// "Done" card tint (warm-up word read, dialogue-complete chip).
  static Color doneCard(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF24402E)
          : const Color(0xFFDFF3DF);

  /// Fogged-world card: pale paper in light mode, dark stone in dark mode.
  static Color fogCard(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF26302B)
          : const Color(0xFFEDE7D8);
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

/// Dark theme (F4): the same journal accents on a deep teal-black page.
/// Card and text colours come from the scheme, so pages that read
/// `Theme.of(context).colorScheme` adapt automatically; pages with
/// hard-coded light colours use the [SpeakMindColors.chispaCard] /
/// [SpeakMindColors.doneCard] / [SpeakMindColors.fogCard] helpers.
ThemeData speakMindDarkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF4DB6A6),
    onPrimary: Color(0xFF0B1F1B),
    secondary: SpeakMindColors.amber,
    onSecondary: SpeakMindColors.ink,
    surface: SpeakMindColors.darkSurface,
    onSurface: Color(0xFFFFF7EA),
    surfaceContainerHighest: SpeakMindColors.darkCard,
    error: Color(0xFFE07856),
    onError: Color(0xFF2B0D05),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: SpeakMindColors.darkSurface,
    cardColor: SpeakMindColors.darkCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: SpeakMindColors.darkSurface,
      foregroundColor: Color(0xFFFFF7EA),
      elevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: SpeakMindColors.darkSurface,
      selectedItemColor: Color(0xFF4DB6A6),
      unselectedItemColor: Color(0xFF8A938C),
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2A9D8F),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
  );
}
