import 'package:flutter/material.dart';

import '../data/app_settings.dart';

const brandColor = Color(0xFF2F7D76);
const brandDarkColor = Color(0xFF1F4D4A);
const inkColor = Color(0xFF17212B);
const paperColor = Color(0xFFF7F3EA);
const paperTintColor = Color(0xFFFFFBF3);
const accentColor = Color(0xFFE36F4C);
const amberColor = Color(0xFFE2A84B);
const mutedTextColor = Color(0xFF69747C);
const lineColor = Color(0xFFE5DED1);
const softGreenColor = Color(0xFFE7F1EC);
const radiusSmall = 6.0;
const radiusMedium = 8.0;

class QingpuPalette extends ThemeExtension<QingpuPalette> {
  const QingpuPalette({
    required this.brand,
    required this.brandDark,
    required this.paper,
    required this.paperTint,
    required this.accent,
    required this.amber,
    required this.soft,
  });

  final Color brand;
  final Color brandDark;
  final Color paper;
  final Color paperTint;
  final Color accent;
  final Color amber;
  final Color soft;

  @override
  QingpuPalette copyWith({
    Color? brand,
    Color? brandDark,
    Color? paper,
    Color? paperTint,
    Color? accent,
    Color? amber,
    Color? soft,
  }) {
    return QingpuPalette(
      brand: brand ?? this.brand,
      brandDark: brandDark ?? this.brandDark,
      paper: paper ?? this.paper,
      paperTint: paperTint ?? this.paperTint,
      accent: accent ?? this.accent,
      amber: amber ?? this.amber,
      soft: soft ?? this.soft,
    );
  }

  @override
  QingpuPalette lerp(ThemeExtension<QingpuPalette>? other, double t) {
    if (other is! QingpuPalette) return this;
    return QingpuPalette(
      brand: Color.lerp(brand, other.brand, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      paperTint: Color.lerp(paperTint, other.paperTint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
    );
  }
}

QingpuPalette paletteOf(BuildContext context) =>
    Theme.of(context).extension<QingpuPalette>()!;

QingpuPalette _paletteFor(AppUiStyle style) {
  return switch (style) {
    AppUiStyle.warm => const QingpuPalette(
      brand: brandColor,
      brandDark: brandDarkColor,
      paper: paperColor,
      paperTint: paperTintColor,
      accent: accentColor,
      amber: amberColor,
      soft: softGreenColor,
    ),
    AppUiStyle.fresh => const QingpuPalette(
      brand: Color(0xFF277A8C),
      brandDark: Color(0xFF174E59),
      paper: Color(0xFFF1F7F5),
      paperTint: Color(0xFFFCFFFC),
      accent: Color(0xFFE66E52),
      amber: Color(0xFFE7B34E),
      soft: Color(0xFFE3F1F2),
    ),
    AppUiStyle.focus => const QingpuPalette(
      brand: Color(0xFF4E6570),
      brandDark: Color(0xFF24343B),
      paper: Color(0xFFF1EEE8),
      paperTint: Color(0xFFFFFCF5),
      accent: Color(0xFFC76145),
      amber: Color(0xFFD59B3E),
      soft: Color(0xFFE8ECEB),
    ),
  };
}

ThemeData buildAppTheme({AppUiStyle style = AppUiStyle.warm}) {
  final palette = _paletteFor(style);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.brand,
      primary: palette.brand,
      secondary: palette.accent,
      tertiary: palette.amber,
      surface: palette.paperTint,
      onSurface: inkColor,
    ),
    extensions: [palette],
    scaffoldBackgroundColor: palette.paper,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: palette.paperTint,
      foregroundColor: inkColor,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.paperTint,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: const BorderSide(color: lineColor),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.paperTint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: lineColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: lineColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: palette.brand, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.soft
              : palette.paperTint,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.brandDark
              : mutedTextColor,
        ),
        side: WidgetStateProperty.all(const BorderSide(color: lineColor)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.brand,
      inactiveTrackColor: lineColor,
      thumbColor: palette.brand,
      overlayColor: palette.brand.withValues(alpha: 0.12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.brand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
    ),
  );
}
