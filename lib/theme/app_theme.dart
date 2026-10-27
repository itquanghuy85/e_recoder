import 'package:flutter/material.dart';

import 'app_tokens.dart';

const _ui = 'Barlow';
const _time = 'BarlowSemiCondensed';

/// Roles follow the Material 3 type scale; sizes are sp (scale with system font).
TextTheme _textTheme(ColorScheme c) {
  TextStyle s(double size, double height, FontWeight w, [double ls = 0]) =>
      TextStyle(
        fontFamily: _ui,
        fontSize: size,
        height: height / size,
        fontWeight: w,
        letterSpacing: ls,
        color: c.onSurface,
      );
  return TextTheme(
    headlineMedium: s(28, 36, FontWeight.w600),
    headlineSmall: s(24, 32, FontWeight.w600),
    titleLarge: s(20, 28, FontWeight.w600),
    titleMedium: s(16, 24, FontWeight.w600, 0.1),
    titleSmall: s(14, 20, FontWeight.w600, 0.1),
    bodyLarge: s(16, 24, FontWeight.w400, 0.2),
    bodyMedium: s(14, 20, FontWeight.w400, 0.2),
    bodySmall: s(12, 16, FontWeight.w400, 0.3),
    labelLarge: s(14, 20, FontWeight.w600, 0.2),
    labelMedium: s(12, 16, FontWeight.w600, 0.4),
    labelSmall: s(11, 16, FontWeight.w600, 0.5),
  );
}

/// Timecode style: tabular, right-alignable, semi-condensed.
TextStyle timecodeStyle(BuildContext context, {double size = 14}) {
  return TextStyle(
    fontFamily: _time,
    fontSize: size,
    fontWeight: FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: Theme.of(context).colorScheme.onSurface,
  );
}

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? Tally.darkScheme : Tally.lightScheme;
  final text = _textTheme(c);
  const minTarget = Size(48, 48);
  return ThemeData(
    useMaterial3: true,
    colorScheme: c,
    scaffoldBackgroundColor: c.surface,
    textTheme: text,
    fontFamily: _ui,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      // Selection is key cyan; tally red is reserved for "live" and the primary record action.
      indicatorColor: c.tertiaryContainer,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? c.onTertiaryContainer
              : c.onSurfaceVariant,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        foregroundColor: c.onSurface,
        selectedBackgroundColor: c.tertiaryContainer,
        selectedForegroundColor: c.onTertiaryContainer,
        side: BorderSide(color: c.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minTarget,
        textStyle: text.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.onSurface,
        minimumSize: minTarget,
        textStyle: text.labelLarge,
        side: BorderSide(color: c.outline),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.tertiary,
        minimumSize: minTarget,
        textStyle: text.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: c.tertiaryContainer,
      checkmarkColor: c.onTertiaryContainer,
      secondaryLabelStyle: text.labelLarge?.copyWith(
        color: c.onTertiaryContainer,
      ),
      backgroundColor: c.surfaceContainerHigh,
      side: BorderSide(color: c.outlineVariant),
      labelStyle: text.labelLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: c.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: c.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.onInverseSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onTertiary : c.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? c.tertiary
            : c.surfaceContainerHighest,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.tertiary,
      thumbColor: c.tertiary,
      inactiveTrackColor: c.surfaceContainerHighest,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.tertiary,
      selectionColor: c.tertiary.withValues(alpha: 0.3),
      selectionHandleColor: c.tertiary,
    ),
    focusColor: c.tertiary.withValues(alpha: 0.2),
  );
}
