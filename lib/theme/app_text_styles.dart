import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography — Manrope for UI, JetBrains Mono for ID codes.
///
/// Sizes follow the design spec. Colors are intentionally left null so the
/// surrounding [DefaultTextStyle]/theme drives them; pass `.copyWith(color:)`
/// where an explicit color is needed.
class AppText {
  AppText._();

  static TextStyle get display => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.5,
      );

  static TextStyle get heading => GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
      );

  static TextStyle get title => GoogleFonts.manrope(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle get bodyLarge => GoogleFonts.manrope(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
      );

  static TextStyle get body => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  static TextStyle get bodyStrong => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.4,
      );

  static TextStyle get caption => GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get small => GoogleFonts.manrope(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.2,
      );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      );

  /// Builds a Manrope-based [TextTheme] for [ThemeData].
  static TextTheme textTheme(Color color) {
    final base = GoogleFonts.manropeTextTheme();
    return base.apply(bodyColor: color, displayColor: color);
  }
}
