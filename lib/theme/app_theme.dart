import 'package:flutter/material.dart';

import 'app_dimens.dart';
import 'app_semantic_colors.dart';

/// M3 Expressive theme built from docs/design/02-v1-design.md §7's token
/// block. The light scheme's role values are taken verbatim from the
/// mockups' `:root` CSS custom properties (identical across every mockup
/// file). The dark scheme is design doc §7a's full, resolved token table
/// (`docs/design/mockups/08-dark-theme.html` §5) — every role hand-retoned
/// against this app's actual seed (not `ColorScheme.fromSeed`'s generic
/// derivation), with the two extra semantic roles + category tints
/// supplied by [AppSemanticColors.dark]/`kCategoryTintsDark` (see those
/// files' doc comments for what changed from the earlier rough guess).
class AppTheme {
  const AppTheme._();

  static const _fontFamilyFallback = [
    'Google Sans',
    'Roboto',
    'Segoe UI',
  ];

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF4256E5),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFDEE1FF),
      onPrimaryContainer: Color(0xFF00135A),
      secondary: Color(0xFF5C5D72),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE1E0F9),
      onSecondaryContainer: Color(0xFF191A2C),
      tertiary: Color(0xFF5C5D72),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFE1E0F9),
      onTertiaryContainer: Color(0xFF191A2C),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFBF8FF),
      onSurface: Color(0xFF1B1B23),
      onSurfaceVariant: Color(0xFF46464F),
      outline: Color(0xFF777680),
      outlineVariant: Color(0xFFC7C5D0),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF5F2FA),
      surfaceContainer: Color(0xFFEFEDF6),
      surfaceContainerHigh: Color(0xFFE9E7F1),
      surfaceContainerHighest: Color(0xFFE3E1EC),
      surfaceDim: Color(0xFFDBD9E3),
      surfaceTint: Color(0xFF4256E5),
      inverseSurface: Color(0xFF303036),
      onInverseSurface: Color(0xFFF3F0F9),
      inversePrimary: Color(0xFFBAC3FF),
      scrim: Color(0xFF000000),
      shadow: Color(0xFF000000),
    );

    return _themeFrom(colorScheme, AppSemanticColors.light);
  }

  /// Design doc §7a's full, resolved dark `ColorScheme` — every role
  /// hand-retoned in CIELAB against this app's actual light-mode seed and
  /// M3's standard dark tonal targets, per `08-dark-theme.html` §5's
  /// token table. Values are a direct transcription, not a re-derivation.
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFBAC3FF),
      onPrimary: Color(0xFF002E6F),
      primaryContainer: Color(0xFF00439E),
      onPrimaryContainer: Color(0xFFDEE1FF),
      secondary: Color(0xFFC5C4DD),
      onSecondary: Color(0xFF2D2F45),
      secondaryContainer: Color(0xFF44455C),
      onSecondaryContainer: Color(0xFFE1E0F9),
      tertiary: Color(0xFFC5C4DD),
      onTertiary: Color(0xFF2D2F45),
      tertiaryContainer: Color(0xFF44455C),
      onTertiaryContainer: Color(0xFFE1E0F9),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF141318),
      onSurface: Color(0xFFE3E1EA),
      onSurfaceVariant: Color(0xFFC7C5D0),
      outline: Color(0xFF919099),
      outlineVariant: Color(0xFF47464E),
      surfaceContainerLowest: Color(0xFF0E0D14),
      surfaceContainerLow: Color(0xFF1C1B21),
      surfaceContainer: Color(0xFF201F26),
      surfaceContainerHigh: Color(0xFF2A2932),
      surfaceContainerHighest: Color(0xFF35343D),
      surfaceDim: Color(0xFF141318),
      surfaceTint: Color(0xFFBAC3FF),
      inverseSurface: Color(0xFFE3E2E9),
      onInverseSurface: Color(0xFF303036),
      inversePrimary: Color(0xFF4256E5),
      scrim: Color(0xFF000000),
      shadow: Color(0xFF000000),
    );

    return _themeFrom(colorScheme, AppSemanticColors.dark);
  }

  static ThemeData _themeFrom(ColorScheme colorScheme, AppSemanticColors semantic) {
    final isDark = colorScheme.brightness == Brightness.dark;
    // Design doc §7a "Elevation and shadow" — dark mode conveys elevation
    // with the tonal surface ladder, not shadow (a shadow is always
    // literally black, which is nearly invisible on a near-black
    // scaffold). `surfaceContainerLowest` (tone 4 in dark) sits *below*
    // the tone-6 scaffold, so a card resting there would render as a
    // recessed hole instead of an elevated surface — bug #1 named in the
    // design doc's dark-theme pass. Fix: cards rest on `surfaceContainer`
    // (tone 12, lighter than the scaffold) in dark; light is unchanged.
    final cardRestColor = isDark ? colorScheme.surfaceContainer : colorScheme.surfaceContainerLowest;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'Roboto',
      fontFamilyFallback: _fontFamilyFallback,
      extensions: [semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardRestColor,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.lg)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 11.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.xl)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.full)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.full)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.sm),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.sm),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.sm),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.sm),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      // Bug #2 named in design doc §7a: this used to hardcode the literal
      // `#2B2B33` in both schemes. In light that's a deliberate fixed dark
      // neutral that pops against a light page — it works *because* it's
      // the opposite brightness of the scaffold. In dark, that same hex
      // sits almost exactly inside the surfaceContainerHigh/Highest tone
      // range, so the toast nearly vanishes into the page it's supposed
      // to float above — and this is the undo toast (REQ-10), so it
      // disappears exactly when it's needed. Fix: use the M3 role built
      // for exactly this ("the opposite scheme's surface," by
      // construction) — `inverseSurface`/`onInverseSurface` — instead of
      // a fixed literal.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppShapes.md))),
      ),
    );
  }
}
