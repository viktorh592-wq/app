import 'package:flutter/material.dart';

/// Pokatuha V2 Design Tokens
/// Source of truth: UI Kit + Figma + design_tokens.md
class DesignTokens {
  DesignTokens._();

  // === COLORS ===
  static const Color primary       = Color(0xFF9B8AFB);
  static const Color primaryDark   = Color(0xFF7C6BDD);
  static const Color primaryDeep   = Color(0xFF5E4DB2);
  static const Color cardSurface   = Color(0xFFF5F3FF);
  static const Color limeAccent    = Color(0xFFD4F291);
  static const Color yellowAccent  = Color(0xFFFFE082);
  static const Color greenAccent   = Color(0xFF81C784);
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B80);
  static const Color greenBg       = Color(0xFFE8F5E9);
  static const Color chipLavender  = Color(0xFFE8E0FF);
  static const Color badgeRed      = Color(0xFFFF5252);
  static const Color salmon        = Color(0xFFFFAB91);
  static const Color glassLime     = Color(0xFFD4F291);

  // Backgrounds (from screenshots)
  static const Color scaffoldBg     = Color(0xFF8E9A9D);
  static const Color scaffoldBgDark = Color(0xFF2D2D2D);

  // === SPACING ===
  static const double space1  = 4;
  static const double space2  = 8;
  static const double space3  = 12;
  static const double space4  = 16;
  static const double space5  = 20;
  static const double space6  = 24;
  static const double space7  = 32;
  static const double space8  = 40;
  static const double space9  = 48;
  static const double space10 = 56;
  static const double space11 = 64;
  static const double space12 = 72;
  static const double space13 = 80;

  // === RADIUS ===
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusXl   = 20;
  static const double radius2xl  = 24;
  static const double radiusFull = 9999;

  // === TYPOGRAPHY ===
  static const String fontFamily = 'Inter';

  static TextStyle display({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: color ?? textPrimary,
      );

  static TextStyle headline({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 20,
        color: color ?? textPrimary,
      );

  static TextStyle title({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 18,
        color: color ?? textPrimary,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        color: color ?? textPrimary,
      );

  static TextStyle bodyMedium({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: color ?? textPrimary,
      );

  static TextStyle caption({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: color ?? textSecondary,
      );

  static TextStyle button({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: color ?? textPrimary,
      );

  static TextStyle pin({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        color: color ?? textSecondary,
      );

  // === ANIMATION ===
  static const Duration durationFast   = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow   = Duration(milliseconds: 500);

  // === CHAT ===
  static const double bubbleMaxWidth = 0.78;
  static const double bubbleRadius   = 20;
  static const double avatarSize     = 40;
  static const double avatarSizeSm   = 32;
  static const double reactionSize   = 28;
}

/// Activity accent color swatches (user-selectable)
class ActivityColors {
  static const List<Color> swatches = [
    Color(0xFF9B8AFB), // violet (default)
    Color(0xFF64B5F6), // blue
    Color(0xFF81C784), // green
    Color(0xFFFFE082), // yellow
    Color(0xFFFFB74D), // orange
    Color(0xFFFF5252), // red
    Color(0xFFF48FB1), // pink
    Color(0xFF8D6E63), // brown
    Color(0xFFB0BEC5), // gray
  ];
}
