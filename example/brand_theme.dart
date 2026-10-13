// Brand System v2 — Flutter M3 theme.
// Seeds: primary #002C6D (navy), secondary #4FD166 (green).
// Copy into your app: `import 'brand_theme.dart';`
// Requires: flutter/material.dart (no extra deps).

// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

/// Seed colors as [Color]s.
class NepalBrandSeeds {
  static const navy = Color(0xFF002C6D);
  static const green = Color(0xFF4FD166);
}

/// Premium dual-seed schemes.
///
/// Verified on Flutter 3.47: `secondary:` sets the secondary *color*
/// directly (raw #4FD166, white text fails contrast), it does NOT build
/// green tonal roles. So we build from navy seed, then `copyWith` the
/// verified green tones (via material_color_utilities tonalSpot):
///
/// - light: secondary g40 #006E27, container g90 #7CFD8C,
///   onContainer g10 #002107, fixed g90/g10/g80/g30.
/// - dark: secondary g80 #5EE072, onSecondary g20 #003910,
///   container g30 #00531B, onContainer g90 #7CFD8C.
/// - Tertiary/neutral/error/surfaces come from the navy seed.
class NepalBrandScheme {
  static final _baseLight = ColorScheme.fromSeed(
    seedColor: NepalBrandSeeds.navy,
    brightness: Brightness.light,
  );
  static final _baseDark = ColorScheme.fromSeed(
    seedColor: NepalBrandSeeds.navy,
    brightness: Brightness.dark,
  );

  static final light = _baseLight.copyWith(
    secondary: const Color(0xFF006E27),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFF7CFD8C),
    onSecondaryContainer: const Color(0xFF002107),
    secondaryFixed: const Color(0xFF7CFD8C),
    onSecondaryFixed: const Color(0xFF002107),
    secondaryFixedDim: const Color(0xFF5EE072),
    onSecondaryFixedVariant: const Color(0xFF00531B),
  );

  static final dark = _baseDark.copyWith(
    secondary: const Color(0xFF5EE072),
    onSecondary: const Color(0xFF003910),
    secondaryContainer: const Color(0xFF00531B),
    onSecondaryContainer: const Color(0xFF7CFD8C),
    secondaryFixed: const Color(0xFF7CFD8C),
    onSecondaryFixed: const Color(0xFF002107),
    secondaryFixedDim: const Color(0xFF5EE072),
    onSecondaryFixedVariant: const Color(0xFF00531B),
  );
}

/// Full premium [ThemeData] with component themes.
///
/// M3 role guide:
/// - primary/onPrimary/container → nav CTA, FAB, links, focus.
/// - secondary/* → verified badges, filters, progress, rural markers.
/// - tertiary/* → illustrations, map overlays (plum balances blue+green).
/// - surfaceContainer* → card layering (lowest→highest).
/// - outline/outlineVariant → borders. inverse* → snackbars/tooltips.
class NepalBrandTheme {
  static ThemeData light() => _build(NepalBrandScheme.light, Brightness.light);

  static ThemeData dark() => _build(NepalBrandScheme.dark, Brightness.dark);

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
      ),
      // Primary CTA = navy; secondary CTA = green container + dark text
      // (green container #7CFD8C must never use white text).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer,
        labelStyle: TextStyle(
            color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: scheme.onSecondaryContainer),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      cardTheme: CardThemeData(
        color: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
        shadowColor: scheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        elevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.surfaceContainerHighest,
        color: scheme.secondary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onSecondary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.surfaceContainerHighest,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.secondary,
        textColor: scheme.onSecondary,
      ),
      dividerTheme:
          DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    );
  }

  /// Hero gradient (marketing only, never for text containers).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF002C6D), Color(0xFF004616), Color(0xFF15A742)],
    stops: [0.0, 0.55, 1.0],
  );
}
