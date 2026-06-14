import 'package:flutter/material.dart';

const brandColor = Color(0xFF246BFE);
const brandDarkColor = Color(0xFF1745A8);
const inkColor = Color(0xFF161B22);
const paperColor = Color(0xFFF5F7FB);
const paperTintColor = Color(0xFFFFFFFF);
const accentColor = Color(0xFFE0593E);
const amberColor = Color(0xFFE0A12B);
const mutedTextColor = Color(0xFF687385);
const lineColor = Color(0xFFE1E6EF);
const softGreenColor = Color(0xFFEAF1FF);
const radiusSmall = 8.0;
const radiusMedium = 12.0;

class QingpuPalette extends ThemeExtension<QingpuPalette> {
  const QingpuPalette({
    required this.brand,
    required this.brandDark,
    required this.paper,
    required this.paperTint,
    required this.accent,
    required this.amber,
    required this.soft,
    required this.text,
    required this.textMuted,
    required this.line,
    required this.surfaceAlt,
    required this.success,
    required this.danger,
    required this.shadow,
  });

  final Color brand;
  final Color brandDark;
  final Color paper;
  final Color paperTint;
  final Color accent;
  final Color amber;
  final Color soft;
  final Color text;
  final Color textMuted;
  final Color line;
  final Color surfaceAlt;
  final Color success;
  final Color danger;
  final Color shadow;

  @override
  QingpuPalette copyWith({
    Color? brand,
    Color? brandDark,
    Color? paper,
    Color? paperTint,
    Color? accent,
    Color? amber,
    Color? soft,
    Color? text,
    Color? textMuted,
    Color? line,
    Color? surfaceAlt,
    Color? success,
    Color? danger,
    Color? shadow,
  }) {
    return QingpuPalette(
      brand: brand ?? this.brand,
      brandDark: brandDark ?? this.brandDark,
      paper: paper ?? this.paper,
      paperTint: paperTint ?? this.paperTint,
      accent: accent ?? this.accent,
      amber: amber ?? this.amber,
      soft: soft ?? this.soft,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      line: line ?? this.line,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
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
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

QingpuPalette paletteOf(BuildContext context) =>
    Theme.of(context).extension<QingpuPalette>()!;

QingpuPalette _paletteFor(Brightness brightness) {
  return switch (brightness) {
    Brightness.light => const QingpuPalette(
      brand: Color(0xFF2E4057),
      brandDark: Color(0xFF1F2D3D),
      paper: Color(0xFFFBF9F5),
      paperTint: Color(0xFFFFFFFF),
      accent: Color(0xFFD35400),
      amber: Color(0xFFC5A059),
      soft: Color(0xFFF4EFE6),
      text: Color(0xFF1E293B),
      textMuted: Color(0xFF64748B),
      line: Color(0xFFE2E8F0),
      surfaceAlt: Color(0xFFF1F5F9),
      success: Color(0xFF10B981),
      danger: Color(0xFFEF4444),
      shadow: Color(0x0C1E293B),
    ),
    Brightness.dark => const QingpuPalette(
      brand: Color(0xFF00E5FF),
      brandDark: Color(0xFF00ACC1),
      paper: Color(0xFF0A0E17),
      paperTint: Color(0xFF151D2A),
      accent: Color(0xFFFF9500),
      amber: Color(0xFFFFCC00),
      soft: Color(0xFF1E293B),
      text: Color(0xFFE2E8F0),
      textMuted: Color(0xFF94A3B8),
      line: Color(0xFF2E3B4E),
      surfaceAlt: Color(0xFF1F2B3E),
      success: Color(0xFF05CD99),
      danger: Color(0xFFEE5D5D),
      shadow: Color(0x3F000000),
    ),
  };
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final palette = _paletteFor(brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.brand,
    brightness: brightness,
    primary: palette.brand,
    secondary: palette.accent,
    tertiary: palette.amber,
    surface: palette.paperTint,
    onSurface: palette.text,
  );
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamilyFallback: const [
      'PingFang SC',
      'Microsoft YaHei',
      'Noto Sans CJK SC',
      'Roboto',
    ],
  );

  return base.copyWith(
    extensions: [palette],
    scaffoldBackgroundColor: palette.paper,
    textTheme: base.textTheme.apply(
      bodyColor: palette.text,
      displayColor: palette.text,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: palette.paper,
      foregroundColor: palette.text,
      titleTextStyle: TextStyle(
        color: palette.text,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      backgroundColor: palette.paperTint,
      selectedItemColor: palette.brand,
      unselectedItemColor: palette.textMuted,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 66,
      backgroundColor: palette.paperTint,
      indicatorColor: palette.soft,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? palette.brand
              : palette.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? palette.brand
              : palette.textMuted,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: isDark ? 0 : 1,
      shadowColor: palette.shadow,
      color: palette.paperTint,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        side: BorderSide(color: palette.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.paperTint,
      labelStyle: TextStyle(color: palette.textMuted),
      hintStyle: TextStyle(color: palette.textMuted),
      prefixIconColor: palette.textMuted,
      suffixIconColor: palette.textMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: palette.line, width: 1.1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: palette.brand, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: palette.surfaceAlt,
      selectedColor: palette.soft,
      disabledColor: palette.surfaceAlt.withValues(alpha: 0.6),
      checkmarkColor: palette.brand,
      labelStyle: TextStyle(color: palette.text, fontWeight: FontWeight.w700),
      secondaryLabelStyle: TextStyle(
        color: palette.brandDark,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(color: palette.line),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
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
              : palette.textMuted,
        ),
        side: WidgetStateProperty.all(BorderSide(color: palette.line)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.brand,
      inactiveTrackColor: palette.line,
      thumbColor: palette.brand,
      overlayColor: palette.brand.withValues(alpha: 0.12),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.text,
        disabledForegroundColor: palette.textMuted.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.brand,
        foregroundColor: isDark ? const Color(0xFF08111F) : Colors.white,
        disabledBackgroundColor: palette.line,
        disabledForegroundColor: palette.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        side: BorderSide(color: palette.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? palette.brand : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.brand.withValues(alpha: 0.28)
            : palette.line,
      ),
    ),
  );
}
