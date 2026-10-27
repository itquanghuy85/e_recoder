import 'package:flutter/material.dart';

/// Design tokens for the "Cue before cut" direction (see PRODUCT.md and
/// .impeccable/surfaces). Tally red = live/primary, cue amber = paused/lead-in,
/// key cyan = selection/playhead. Surfaces are ink-blue tinted, never neutral grey.
abstract final class Tally {
  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF5A52),
    onPrimary: Color(0xFF1A0200),
    primaryContainer: Color(0xFF5C1411),
    onPrimaryContainer: Color(0xFFFFDAD6),
    secondary: Color(0xFFFFB938),
    onSecondary: Color(0xFF2B1A00),
    secondaryContainer: Color(0xFF4A3500),
    onSecondaryContainer: Color(0xFFFFE3A3),
    tertiary: Color(0xFF4DD6E8),
    onTertiary: Color(0xFF00232A),
    tertiaryContainer: Color(0xFF00444D),
    onTertiaryContainer: Color(0xFFB8F1F9),
    error: Color(0xFFFF8FA3),
    onError: Color(0xFF3D0014),
    errorContainer: Color(0xFF5A1228),
    onErrorContainer: Color(0xFFFFD9E1),
    surface: Color(0xFF0E1116),
    onSurface: Color(0xFFE8ECF3),
    onSurfaceVariant: Color(0xFFA3AEC2),
    surfaceContainerLowest: Color(0xFF0A0D11),
    surfaceContainerLow: Color(0xFF131821),
    surfaceContainer: Color(0xFF181E29),
    surfaceContainerHigh: Color(0xFF1F2633),
    surfaceContainerHighest: Color(0xFF273041),
    outline: Color(0xFF6B778E),
    outlineVariant: Color(0xFF2A3345),
    inverseSurface: Color(0xFFE8ECF3),
    onInverseSurface: Color(0xFF12161D),
    inversePrimary: Color(0xFFC4161C),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
  );

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFC4161C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFDAD6),
    onPrimaryContainer: Color(0xFF410002),
    secondary: Color(0xFF8A5A00),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFDEA6),
    onSecondaryContainer: Color(0xFF2B1A00),
    tertiary: Color(0xFF00687A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFB8EEF9),
    onTertiaryContainer: Color(0xFF001F26),
    error: Color(0xFFA3123F),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFD9E1),
    onErrorContainer: Color(0xFF40001A),
    surface: Color(0xFFF6F8FB),
    onSurface: Color(0xFF12161D),
    onSurfaceVariant: Color(0xFF48526A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF0F3F8),
    surfaceContainer: Color(0xFFEAEEF4),
    surfaceContainerHigh: Color(0xFFE3E8EF),
    surfaceContainerHighest: Color(0xFFDBE1EA),
    outline: Color(0xFF6B758C),
    outlineVariant: Color(0xFFCBD2DE),
    inverseSurface: Color(0xFF1F2633),
    onInverseSurface: Color(0xFFE8ECF3),
    inversePrimary: Color(0xFFFF5A52),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
  );
}

/// Marker palette: independent of the app theme because markers sit on top of
/// arbitrary third-party screens. Every marker is drawn with a halo of the
/// opposite luminance so it stays legible on light and dark content.
abstract final class MarkerPalette {
  static const List<Color> colors = [
    Color(0xFFFF3B30), // tally red
    Color(0xFFFFC02E), // cue amber
    Color(0xFF2BE37A), // key green
    Color(0xFF2DD4F0), // key cyan
    Color(0xFFFF4FA3), // magenta
    Color(0xFFFFFFFF), // white
    Color(0xFF111111), // black
  ];
}

/// 4 dp spacing scale.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
}

/// Material 3 standard motion. Tally pulse and cue ring are the only expressive
/// motions; both must be skipped when the system removes animations.
abstract final class Motion {
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration long = Duration(milliseconds: 400);
  static const Duration cue = Duration(milliseconds: 500);
  static const Duration tallyPulse = Duration(milliseconds: 1200);
}
