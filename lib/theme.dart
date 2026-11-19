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

  /// Chat bubble of the partner (NPC / Chispa): white card in light mode,
  /// dark card in dark mode. The old `surfaceContainerHighest` bubble was
  /// invisible on the cream page.
  static Color bubbleTheirs(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : Colors.white;

  /// Chat bubble of the user: deep teal, white text.
  static const Color bubbleMine = deepTeal;
  static const Color onBubbleMine = Colors.white;
}

/// Type scale from the final planning doc (p.11): title 22, level name 17,
/// body 15, caption 12.5. Spanish words use the same font, bold, with
/// slightly wider tracking.
abstract class SpeakMindText {
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle levelName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle body = TextStyle(fontSize: 15);

  static const TextStyle caption = TextStyle(fontSize: 12.5);

  static TextStyle spanish({required double size, Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        color: color,
      );
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
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: SpeakMindColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: SpeakMindColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: SpeakMindColors.ink),
      bodyMedium: TextStyle(fontSize: 15, color: SpeakMindColors.ink),
      bodySmall: TextStyle(fontSize: 12.5, color: SpeakMindColors.ink),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: SpeakMindColors.ink,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: SpeakMindColors.ink,
      ),
    ),
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
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFF7EA),
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFF7EA),
      ),
      bodyLarge: TextStyle(fontSize: 15, color: Color(0xFFFFF7EA)),
      bodyMedium: TextStyle(fontSize: 15, color: Color(0xFFFFF7EA)),
      bodySmall: TextStyle(fontSize: 12.5, color: Color(0xFFFFF7EA)),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFF7EA),
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFF7EA),
      ),
    ),
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
