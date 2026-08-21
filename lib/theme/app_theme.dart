import 'package:flutter/material.dart';

import 'app_dimens.dart';
import 'app_semantic_colors.dart';

/// M3 Expressive theme built from docs/design/02-v1-design.md §7's token
/// block. The light scheme's role values are taken verbatim from the
/// mockups' `:root` CSS custom properties (identical across every mockup
/// file). The dark scheme has no designer-specified source — no dark
/// mockup exists anywhere in docs/design/mockups/ — so it's generated
/// algorithmically from the same seed hue via [ColorScheme.fromSeed] for
/// the stock M3 roles, with [AppSemanticColors.dark] supplying the two
/// extra roles + category tints by hand (see that file's doc comment).
/// This is stated plainly rather than implied as verified: dark mode
/// should get a design pass before it's treated as shippable.
class AppTheme {
  const AppTheme._();

  static const _seedColor = Color(0xFF4256E5);

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

  static ThemeData dark() {
    final generated = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark);
    return _themeFrom(generated, AppSemanticColors.dark);
  }

  static ThemeData _themeFrom(ColorScheme colorScheme, AppSemanticColors semantic) {
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
        color: colorScheme.surfaceContainerLowest,
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
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF2B2B33),
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppShapes.md))),
      ),
    );
  }
}
