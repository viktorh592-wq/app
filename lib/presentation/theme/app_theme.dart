import 'package:flutter/material.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';

/// Pokatuha V2 Theme — Material 3, Light / Dark / AMOLED.
/// Follows design_tokens.md + FIGMA_IMPLEMENTATION.md
class AppTheme {
  AppTheme._();

  static ThemeData light(Color accent) => _base(accent, Brightness.light);
  static ThemeData dark(Color accent) => _base(accent, Brightness.dark);
  static ThemeData amoled(Color accent) => _base(
        accent,
        Brightness.dark,
        isAmoled: true,
      );
  static ThemeData system(Color accent, BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? dark(accent)
          : light(accent);

  static ThemeData _base(
    Color accent,
    Brightness brightness, {
    bool isAmoled = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final surfaceColor = isAmoled
        ? Colors.black
        : (isDark ? DesignTokens.scaffoldBgDark : DesignTokens.scaffoldBg);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surfaceColor,
      surfaceContainerHighest:
          isAmoled ? const Color(0xFF121212) : (isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE8E8E8)),
      surfaceContainerLow:
          isAmoled ? const Color(0xFF0A0A0A) : (isDark ? const Color(0xFF363636) : const Color(0xFFF0F0F0)),
      surfaceContainerHigh:
          isAmoled ? const Color(0xFF1A1A1A) : (isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0)),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceColor,
      brightness: brightness,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: DesignTokens.fontFamily,
      textTheme: _textTheme(colorScheme, isDark),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: surfaceColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: DesignTokens.headline(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: DesignTokens.button(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          ),
          side: BorderSide(color: accent),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHigh
            : DesignTokens.limeAccent.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: DesignTokens.body(color: DesignTokens.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: DesignTokens.chipLavender,
        selectedColor: accent.withOpacity(0.2),
        labelStyle: DesignTokens.caption(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        ),
        side: BorderSide.none,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusXl),
          ),
        ),
      ),
      // V3.0.1 bug fix — do NOT force `shape: CircleBorder()` on the global
      // FAB theme. Doing so makes `FloatingActionButton.extended` render as a
      // circle, cutting off its text label (the text background does not span
      // the whole label). Leave the default shape so extended FABs use the
      // Material 3 stadium shape, while plain round FABs (used inside
      // `MorphingFab` and the Map action sheet) keep their circular shape via
      // the explicit `shape: CircleBorder()` on the widget itself.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: DesignTokens.limeAccent,
        foregroundColor: DesignTokens.textPrimary,
        elevation: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DesignTokens.limeAccent,
        indicatorColor: accent.withOpacity(0.2),
        labelTextStyle: WidgetStatePropertyAll(
          DesignTokens.caption(color: DesignTokens.textPrimary),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: DesignTokens.textPrimary),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.3),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme, bool isDark) {
    return TextTheme(
      displayLarge: DesignTokens.display(color: scheme.onSurface),
      displayMedium: DesignTokens.headline(color: scheme.onSurface),
      titleLarge: DesignTokens.title(color: scheme.onSurface),
      bodyLarge: DesignTokens.body(color: scheme.onSurface),
      bodyMedium: DesignTokens.bodyMedium(color: scheme.onSurface),
      labelLarge: DesignTokens.button(color: scheme.onSurface),
      labelSmall: DesignTokens.caption(color: scheme.onSurface),
    );
  }
}
