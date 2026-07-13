import 'package:flutter/material.dart';

// ── Brand ─────────────────────────────────────────────────────────────
const kPrimary = Color(0xFF0E7A6E); // Deep teal
const kPrimary2 = Color(0xFF15A05B); // Emerald green
const kGradStart = Color(0xFF0E7A6E);
const kGradEnd = Color(0xFF1BA866);

// Dark-mode brand gradient (slightly lighter teal)
const kGradStartDark = Color(0xFF0E8C7E);
const kGradEndDark = Color(0xFF1EB873);

// ── Semantic ──────────────────────────────────────────────────────────
const kSafe = Color(0xFF15A34A);
const kDanger = Color(0xFFE5484D);
const kWarn = Color(0xFFC5821F);
const kInfo = Color(0xFF2F7FE4);

// ── Light surfaces ────────────────────────────────────────────────────
const kBgLight = Color(0xFFF3F6F4);
const kSurfaceLight = Color(0xFFFFFFFF);
const kTextLight = Color(0xFF0F201B);
const kText2Light = Color(0xFF5C6B66);
const kText3Light = Color(0xFF5C6B66);
const kBorderLight = Color(0xFFE6ECE9);
const kMintLight = Color(0xFFE4F4EC);

// ── Dark surfaces ─────────────────────────────────────────────────────
const kBgDark = Color(0xFF0B1310);
const kSurfaceDark = Color(0xFF13201B);
const kTextDark = Color(0xFFEAF3EF);
const kText2Dark = Color(0xFF9FB2AC);
const kText3Dark = Color(0xFFB6C8C1);
const kBorderDark = Color(0xFF26332E);
const kMintDark = Color(0xFF13302A);

/// Theme-aware palette exposed through [ThemeData.extensions].
/// Access with `context.c` (see extension below).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt; // subtle raised surface (e.g. input fills)
  final Color text;
  final Color text2;
  final Color text3;
  final Color border;
  final Color border2; // hairline divider between list rows
  final Color mint;
  final Color mintFg;
  final Color primary;
  final Color safe;
  final Color danger;
  final Color warn;
  final Color info;
  // Tinted "soft" backgrounds for chips / banners.
  final Color safeBg;
  final Color dangerBg;
  final Color warnBg;
  final Color infoBg;
  final Color sky; // sky = info banner background
  final Color skyFg;
  final List<Color> brandGradient;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.text2,
    required this.text3,
    required this.border,
    required this.border2,
    required this.mint,
    required this.mintFg,
    required this.primary,
    required this.safe,
    required this.danger,
    required this.warn,
    required this.info,
    required this.safeBg,
    required this.dangerBg,
    required this.warnBg,
    required this.infoBg,
    required this.sky,
    required this.skyFg,
    required this.brandGradient,
  });

  static const light = AppColors(
    bg: kBgLight,
    surface: kSurfaceLight,
    surfaceAlt: Color(0xFFF6F9F7),
    text: kTextLight,
    text2: kText2Light,
    text3: kText3Light,
    border: kBorderLight,
    border2: Color(0xFFEFF3F1),
    mint: kMintLight,
    mintFg: Color(0xFF0E7A6E),
    primary: kPrimary,
    safe: kSafe,
    danger: kDanger,
    warn: kWarn,
    info: kInfo,
    safeBg: Color(0xFFE6F6EC),
    dangerBg: Color(0xFFFCEBEC),
    warnBg: Color(0xFFFAF0DD),
    infoBg: Color(0xFFE7F1FB),
    sky: Color(0xFFE7F1FB),
    skyFg: Color(0xFF2F7FE4),
    brandGradient: [kGradStart, kGradEnd],
  );

  static const dark = AppColors(
    bg: kBgDark,
    surface: kSurfaceDark,
    surfaceAlt: Color(0xFF182823),
    text: kTextDark,
    text2: kText2Dark,
    text3: kText3Dark,
    border: kBorderDark,
    border2: Color(0xFF1D2A24),
    mint: kMintDark,
    mintFg: Color(0xFF4FD6A8),
    primary: Color(0xFF1FBE86),
    safe: Color(0xFF22B65C),
    danger: Color(0xFFFF6166),
    warn: Color(0xFFE8A23D),
    info: Color(0xFF5B9BF0),
    safeBg: Color(0xFF11291C),
    dangerBg: Color(0xFF3A1C1E),
    warnBg: Color(0xFF352A17),
    infoBg: Color(0xFF15273A),
    sky: Color(0xFF15273A),
    skyFg: Color(0xFF6FA8F0),
    brandGradient: [kGradStartDark, kGradEndDark],
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? text,
    Color? text2,
    Color? text3,
    Color? border,
    Color? border2,
    Color? mint,
    Color? mintFg,
    Color? primary,
    Color? safe,
    Color? danger,
    Color? warn,
    Color? info,
    Color? safeBg,
    Color? dangerBg,
    Color? warnBg,
    Color? infoBg,
    Color? sky,
    Color? skyFg,
    List<Color>? brandGradient,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      border: border ?? this.border,
      border2: border2 ?? this.border2,
      mint: mint ?? this.mint,
      mintFg: mintFg ?? this.mintFg,
      primary: primary ?? this.primary,
      safe: safe ?? this.safe,
      danger: danger ?? this.danger,
      warn: warn ?? this.warn,
      info: info ?? this.info,
      safeBg: safeBg ?? this.safeBg,
      dangerBg: dangerBg ?? this.dangerBg,
      warnBg: warnBg ?? this.warnBg,
      infoBg: infoBg ?? this.infoBg,
      sky: sky ?? this.sky,
      skyFg: skyFg ?? this.skyFg,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      border: Color.lerp(border, other.border, t)!,
      border2: Color.lerp(border2, other.border2, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      mintFg: Color.lerp(mintFg, other.mintFg, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      safe: Color.lerp(safe, other.safe, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      info: Color.lerp(info, other.info, t)!,
      safeBg: Color.lerp(safeBg, other.safeBg, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      warnBg: Color.lerp(warnBg, other.warnBg, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      skyFg: Color.lerp(skyFg, other.skyFg, t)!,
      brandGradient: [
        Color.lerp(brandGradient.first, other.brandGradient.first, t)!,
        Color.lerp(brandGradient.last, other.brandGradient.last, t)!,
      ],
    );
  }
}

/// Convenience accessors used throughout the app.
extension AppColorsX on BuildContext {
  AppColors get c =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Shared shadows.
class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const brandCard = [
    BoxShadow(color: Color(0x470E7A6E), blurRadius: 30, offset: Offset(0, 14)),
  ];
  static const button = [
    BoxShadow(color: Color(0x470E7A6E), blurRadius: 22, offset: Offset(0, 10)),
  ];
}

/// Standard brand gradient builder.
LinearGradient brandGradient(BuildContext context,
    {AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight}) {
  return LinearGradient(begin: begin, end: end, colors: context.c.brandGradient);
}
