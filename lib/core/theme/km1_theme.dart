// KM1 km1_theme.dart — tokens.json から自動生成。直接編集しない。
// Generated from tokens.json; do not edit by hand.
//
// 使い方 / Usage:
//   MaterialApp(theme: Km1Theme.light(), darkTheme: Km1Theme.dark(), themeMode: ThemeMode.system, ...)
//   色は Theme.of(context).extension<Km1Colors>()! 経由で意味づけトークンを使う。
//   Use semantic tokens via Theme.of(context).extension<Km1Colors>()!.
//
// アイコンは fluentui_system_icons を使い、Icons.*（Material）は使わない。
// Use fluentui_system_icons; do not use Icons.* (Material).
// Material は土台として使うだけで、見た目は下のテーマで上書きする。
// Material is only the base widget layer; the look is overridden below.

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

@immutable
class Km1Colors extends ThemeExtension<Km1Colors> {
  const Km1Colors({
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceMuted,
    required this.surfaceSunken,
    required this.surfaceHover,
    required this.surfacePressed,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.inkDisabled,
    required this.stroke,
    required this.strokeSubtle,
    required this.strokeStrong,
    required this.brand,
    required this.brandHover,
    required this.brandPressed,
    required this.onBrand,
    required this.brandInk,
    required this.brandTint,
    required this.brandStroke,
    required this.focusRing,
    required this.infoInk,
    required this.infoTint,
    required this.danger,
    required this.dangerInk,
    required this.dangerTint,
    required this.successInk,
    required this.successTint,
    required this.warningInk,
    required this.warningTint,
  });

  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceMuted;
  final Color surfaceSunken;
  final Color surfaceHover;
  final Color surfacePressed;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color inkDisabled;
  final Color stroke;
  final Color strokeSubtle;
  final Color strokeStrong;
  final Color brand;
  final Color brandHover;
  final Color brandPressed;
  final Color onBrand;
  final Color brandInk;
  final Color brandTint;
  final Color brandStroke;
  final Color focusRing;
  final Color infoInk;
  final Color infoTint;
  final Color danger;
  final Color dangerInk;
  final Color dangerTint;
  final Color successInk;
  final Color successTint;
  final Color warningInk;
  final Color warningTint;

  static const Km1Colors light = Km1Colors(
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFFAFAFA),
    surfaceMuted: Color(0xFFF5F5F5),
    surfaceSunken: Color(0xFFF0F0F0),
    surfaceHover: Color(0xFFF5F5F5),
    surfacePressed: Color(0xFFE0E0E0),
    ink: Color(0xFF242424),
    inkSecondary: Color(0xFF424242),
    inkTertiary: Color(0xFF616161),
    inkDisabled: Color(0xFFBDBDBD),
    stroke: Color(0xFFD1D1D1),
    strokeSubtle: Color(0xFFE0E0E0),
    strokeStrong: Color(0xFF616161),
    brand: Color(0xFF10218B),
    brandHover: Color(0xFF0C1A6E),
    brandPressed: Color(0xFF081257),
    onBrand: Color(0xFFFFFFFF),
    brandInk: Color(0xFF10218B),
    brandTint: Color(0xFFECEFFC),
    brandStroke: Color(0xFF10218B),
    focusRing: Color(0xFF000000),
    infoInk: Color(0xFF0F6CBD),
    infoTint: Color(0xFFEBF3FC),
    danger: Color(0xFFB10E1C),
    dangerInk: Color(0xFFB10E1C),
    dangerTint: Color(0xFFFDF3F4),
    successInk: Color(0xFF107C10),
    successTint: Color(0xFFF1FAF1),
    warningInk: Color(0xFFBC4B09),
    warningTint: Color(0xFFFFF9F5),
  );

  static const Km1Colors dark = Km1Colors(
    surface: Color(0xFF292929),
    surfaceSubtle: Color(0xFF1F1F1F),
    surfaceMuted: Color(0xFF141414),
    surfaceSunken: Color(0xFF0A0A0A),
    surfaceHover: Color(0xFF383838),
    surfacePressed: Color(0xFF1F1F1F),
    ink: Color(0xFFFFFFFF),
    inkSecondary: Color(0xFFD6D6D6),
    inkTertiary: Color(0xFFADADAD),
    inkDisabled: Color(0xFF5C5C5C),
    stroke: Color(0xFF666666),
    strokeSubtle: Color(0xFF525252),
    strokeStrong: Color(0xFFD6D6D6),
    brand: Color(0xFF3A4FD1),
    brandHover: Color(0xFF4A5FE0),
    brandPressed: Color(0xFF2C3FB8),
    onBrand: Color(0xFFFFFFFF),
    brandInk: Color(0xFF99A6FF),
    brandTint: Color(0xFF0D1238),
    brandStroke: Color(0xFF7A8CF5),
    focusRing: Color(0xFFFFFFFF),
    infoInk: Color(0xFF479EF5),
    infoTint: Color(0xFF082338),
    danger: Color(0xFFC50F1F),
    dangerInk: Color(0xFFE37D80),
    dangerTint: Color(0xFF3B0509),
    successInk: Color(0xFF54B054),
    successTint: Color(0xFF052505),
    warningInk: Color(0xFFFAA06B),
    warningTint: Color(0xFF411200),
  );

  @override
  Km1Colors copyWith({
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceMuted,
    Color? surfaceSunken,
    Color? surfaceHover,
    Color? surfacePressed,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? inkDisabled,
    Color? stroke,
    Color? strokeSubtle,
    Color? strokeStrong,
    Color? brand,
    Color? brandHover,
    Color? brandPressed,
    Color? onBrand,
    Color? brandInk,
    Color? brandTint,
    Color? brandStroke,
    Color? focusRing,
    Color? infoInk,
    Color? infoTint,
    Color? danger,
    Color? dangerInk,
    Color? dangerTint,
    Color? successInk,
    Color? successTint,
    Color? warningInk,
    Color? warningTint,
  }) =>
      Km1Colors(
        surface: surface ?? this.surface,
        surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
        surfaceSunken: surfaceSunken ?? this.surfaceSunken,
        surfaceHover: surfaceHover ?? this.surfaceHover,
        surfacePressed: surfacePressed ?? this.surfacePressed,
        ink: ink ?? this.ink,
        inkSecondary: inkSecondary ?? this.inkSecondary,
        inkTertiary: inkTertiary ?? this.inkTertiary,
        inkDisabled: inkDisabled ?? this.inkDisabled,
        stroke: stroke ?? this.stroke,
        strokeSubtle: strokeSubtle ?? this.strokeSubtle,
        strokeStrong: strokeStrong ?? this.strokeStrong,
        brand: brand ?? this.brand,
        brandHover: brandHover ?? this.brandHover,
        brandPressed: brandPressed ?? this.brandPressed,
        onBrand: onBrand ?? this.onBrand,
        brandInk: brandInk ?? this.brandInk,
        brandTint: brandTint ?? this.brandTint,
        brandStroke: brandStroke ?? this.brandStroke,
        focusRing: focusRing ?? this.focusRing,
        infoInk: infoInk ?? this.infoInk,
        infoTint: infoTint ?? this.infoTint,
        danger: danger ?? this.danger,
        dangerInk: dangerInk ?? this.dangerInk,
        dangerTint: dangerTint ?? this.dangerTint,
        successInk: successInk ?? this.successInk,
        successTint: successTint ?? this.successTint,
        warningInk: warningInk ?? this.warningInk,
        warningTint: warningTint ?? this.warningTint,
      );

  @override
  Km1Colors lerp(ThemeExtension<Km1Colors>? other, double t) {
    if (other is! Km1Colors) return this;
    return Km1Colors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      inkDisabled: Color.lerp(inkDisabled, other.inkDisabled, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      strokeSubtle: Color.lerp(strokeSubtle, other.strokeSubtle, t)!,
      strokeStrong: Color.lerp(strokeStrong, other.strokeStrong, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandHover: Color.lerp(brandHover, other.brandHover, t)!,
      brandPressed: Color.lerp(brandPressed, other.brandPressed, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandInk: Color.lerp(brandInk, other.brandInk, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      brandStroke: Color.lerp(brandStroke, other.brandStroke, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      infoInk: Color.lerp(infoInk, other.infoInk, t)!,
      infoTint: Color.lerp(infoTint, other.infoTint, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerInk: Color.lerp(dangerInk, other.dangerInk, t)!,
      dangerTint: Color.lerp(dangerTint, other.dangerTint, t)!,
      successInk: Color.lerp(successInk, other.successInk, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      warningInk: Color.lerp(warningInk, other.warningInk, t)!,
      warningTint: Color.lerp(warningTint, other.warningTint, t)!,
    );
  }
}

abstract final class Km1Space {
  static const double none = 0.0;
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double smNudge = 6.0;
  static const double sm = 8.0;
  static const double mdNudge = 10.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double targetCompact = 32.0;
  static const double target = 44.0;
}

abstract final class Km1Radius {
  static const double none = 0.0;
  static const double sm = 2.0;
  static const double md = 4.0;
  static const double lg = 6.0;
  static const double xl = 8.0;
  static const double xxl = 12.0;
  static const double circular = 9999.0;
}

abstract final class Km1Shadow {
  static const List<BoxShadow> shadow2 = [
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), offset: Offset(0.0, 0.0), blurRadius: 2.0),
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.14), offset: Offset(0.0, 1.0), blurRadius: 2.0),
  ];
  static const List<BoxShadow> shadow4 = [
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), offset: Offset(0.0, 0.0), blurRadius: 2.0),
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.14), offset: Offset(0.0, 2.0), blurRadius: 4.0),
  ];
  static const List<BoxShadow> shadow8 = [
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), offset: Offset(0.0, 0.0), blurRadius: 2.0),
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.14), offset: Offset(0.0, 4.0), blurRadius: 8.0),
  ];
  static const List<BoxShadow> shadow16 = [
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), offset: Offset(0.0, 0.0), blurRadius: 2.0),
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.14), offset: Offset(0.0, 8.0), blurRadius: 16.0),
  ];
  static const List<BoxShadow> shadow28 = [
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), offset: Offset(0.0, 0.0), blurRadius: 8.0),
    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.24), offset: Offset(0.0, 14.0), blurRadius: 28.0),
  ];
}

abstract final class Km1Text {
  static const String fontFamily = 'Noto Sans JP';
  static const List<String> fontFamilyFallback = ['Yu Gothic UI', 'Meiryo UI', 'Hiragino Sans'];
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 68.0,
    height: 92.0/68.0,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle largeTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 40.0,
    height: 52.0/40.0,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle title1 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 32.0,
    height: 40.0/32.0,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle title2 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 28.0,
    height: 36.0/28.0,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle title3 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24.0,
    height: 32.0/24.0,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle subtitle1 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 20.0,
    height: 28.0/20.0,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle subtitle2 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16.0,
    height: 22.0/16.0,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body2 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16.0,
    height: 22.0/16.0,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle body1 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14.0,
    height: 20.0/14.0,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle body1Strong = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14.0,
    height: 20.0/14.0,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle caption1 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12.0,
    height: 16.0/12.0,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle caption2 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 10.0,
    height: 14.0/10.0,
    fontWeight: FontWeight.w400,
  );
}

/// アイコン・線・幅 / Icon sizes, stroke widths, widths
abstract final class Km1Size {
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double strokeThin = 1.0;
  static const double strokeThick = 2.0;
  static const double strokeAccent = 4.0;
  static const double controlSm = 24.0;
  static const double controlLg = 40.0;
  static const double controlLgTouch = 48.0;
  static const double dialogWidth = 480.0;
  static const double dialogWidthSm = 420.0;
  static const double contentWidth = 720.0;
}

/// 画面幅の区切り（Fluent 2 の size class）/ Breakpoints (Fluent 2 size classes)
abstract final class Km1Breakpoint {
  static const double md = 480.0;
  static const double lg = 640.0;
  static const double xl = 1024.0;
  static const double xxl = 1366.0;

  /// 編集をダイアログで開く幅か / Wide enough to edit in a dialog
  static bool useDialog(BuildContext context) => MediaQuery.sizeOf(context).width >= lg;

  /// サイドバーを常時表示する幅か / Wide enough for a persistent sidebar
  static bool useSidebar(BuildContext context) => MediaQuery.sizeOf(context).width >= xl;
}

/// 動き / Motion（Fluent 2 の duration・curve）
abstract final class Km1Motion {
  /// hover・pressed の色の変化 / Hover and pressed color changes
  static const Duration faster = Duration(milliseconds: 100);

  /// スイッチ・下線・チェックの切り替え / Switch, underline, check toggles
  static const Duration fast = Duration(milliseconds: 150);

  /// ダイアログ・ポップオーバー・画面の出入り / Dialog, popover and screen transitions
  static const Duration normal = Duration(milliseconds: 200);

  static const Curve easyEase = Cubic(0.33, 0, 0.67, 1);

  /// 現れるとき / Entering
  static const Curve decelerate = Cubic(0, 0, 0, 1);

  /// 消えるとき / Exiting
  static const Curve accelerate = Cubic(1, 0, 1, 1);

  /// 出入りで動かしてよい距離の上限 / Max travel for enter and exit
  static const double maxShift = 8;
}

/// 分類色 / Category colors — 帯と淡い塗りだけに使い、文字には使わない。
abstract final class Km1Category {
  static const Color blue = Color(0xFF0F6CBD);
  static const Color cornflower = Color(0xFF4F6BED);
  static const Color cyan = Color(0xFF0099BC);
  static const Color teal = Color(0xFF038387);
  static const Color seafoam = Color(0xFF00B294);
  static const Color green = Color(0xFF13A10E);
  static const Color lime = Color(0xFF8BBF26);
  static const Color marigold = Color(0xFFEAA300);
  static const Color pumpkin = Color(0xFFF7630C);
  static const Color darkOrange = Color(0xFFCA5010);
  static const Color red = Color(0xFFD13438);
  static const Color cranberry = Color(0xFFC50F1F);
  static const Color pink = Color(0xFFE43BA6);
  static const Color berry = Color(0xFFC239B3);
  static const Color purple = Color(0xFF8764B8);
  static const Color grape = Color(0xFF5C2E91);
  static const Color brown = Color(0xFF8E562E);
  static const Color gray = Color(0xFF7A7574);
  static const List<Color> all = [blue, cornflower, cyan, teal, seafoam, green, lime, marigold, pumpkin, darkOrange, red, cranberry, pink, berry, purple, grape, brown, gray];

  /// 淡い塗り（ライト 14%、ダーク 32%）/ Tint fill (14% light, 32% dark)
  static Color tint(Color c, Brightness b) => c.withValues(alpha: b == Brightness.dark ? 0.32 : 0.14);
}

/// 暗幕 / Scrim
const Color kKm1Scrim = Color(0x66000000);

/// 操作領域 / Hit areas (WCAG 2.2 2.5.5 AAA = 44, 2.5.8 AA = 24)
const double kKm1Target = Km1Space.target;
const double kKm1TargetCompact = Km1Space.targetCompact;

abstract final class Km1Theme {
  /// タッチ操作が主な端末か（iOS・Android）。Web でも端末の OS で決まる。
  /// Whether touch is the main input (iOS, Android); on the web it follows the device OS.
  static bool get isTouch =>
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

  /// [touch] を省くと端末から決める。スマホは高さ 44・入力 16px、PC は高さ 32・入力 14px。
  /// Omit [touch] to decide from the device: 44 high / 16px fields on phones, 32 / 14px on PC.
  static ThemeData light({bool? touch}) => _build(Km1Colors.light, Brightness.light, touch ?? isTouch);
  static ThemeData dark({bool? touch}) => _build(Km1Colors.dark, Brightness.dark, touch ?? isTouch);

  static ThemeData _build(Km1Colors c, Brightness b, bool touch) {
    final double target = touch ? kKm1Target : kKm1TargetCompact;
    final double fieldSize = touch ? 16 : 14;
    final tapSize = touch ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap;
    final scheme = ColorScheme(
      brightness: b,
      primary: c.brand,
      onPrimary: c.onBrand,
      secondary: c.brandInk,
      onSecondary: c.surface,
      error: c.danger,
      onError: c.onBrand,
      surface: c.surface,
      onSurface: c.ink,
      outline: c.strokeStrong,
      outlineVariant: c.stroke,
    );
    final minTarget = Size(target, target);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Km1Radius.md));
    final focusSide = BorderSide(color: c.focusRing, width: 2);

    OutlineInputBorder border(Color color, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Km1Radius.md),
          borderSide: BorderSide(color: color, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      fontFamily: Km1Text.fontFamily,
      fontFamilyFallback: Km1Text.fontFamilyFallback,
      // Material のスプラッシュは使わず、状態は色の変化で示す。 / No ink splash; states are shown by color.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: TextTheme(
        displayLarge: Km1Text.display.copyWith(color: c.ink),
        headlineLarge: Km1Text.largeTitle.copyWith(color: c.ink),
        headlineMedium: Km1Text.title1.copyWith(color: c.ink),
        headlineSmall: Km1Text.title2.copyWith(color: c.ink),
        titleLarge: Km1Text.title3.copyWith(color: c.ink),
        titleMedium: Km1Text.subtitle1.copyWith(color: c.ink),
        titleSmall: Km1Text.subtitle2.copyWith(color: c.ink),
        // 入力中の文字は bodyLarge。スマホ 16px、PC 14px。 / Field text: 16px on touch, 14px on PC.
        bodyLarge: (touch ? Km1Text.body2 : Km1Text.body1).copyWith(color: c.ink),
        bodyMedium: Km1Text.body1.copyWith(color: c.ink),
        bodySmall: Km1Text.caption1.copyWith(color: c.inkSecondary),
        labelLarge: Km1Text.body1Strong.copyWith(color: c.ink),
        labelMedium: Km1Text.caption1.copyWith(color: c.inkSecondary),
        labelSmall: Km1Text.caption2.copyWith(color: c.inkSecondary),
      ),
      extensions: [c],
      dividerTheme: DividerThemeData(color: c.strokeSubtle, thickness: 1, space: 1),
      materialTapTargetSize: tapSize,
      visualDensity: VisualDensity.standard,
      focusColor: c.focusRing,
      hoverColor: c.surfaceHover,

      // ボタン / Buttons — 主 = 塗り、副 = 枠、三次 = 文字のみ。画面に主は 1 つ。
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minTarget),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Km1Space.md)),
          shape: WidgetStatePropertyAll(shape),
          textStyle: const WidgetStatePropertyAll(Km1Text.body1Strong),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.inkDisabled : c.onBrand),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return c.surfaceMuted;
            if (s.contains(WidgetState.pressed)) return c.brandPressed;
            if (s.contains(WidgetState.hovered)) return c.brandHover;
            return c.brand;
          }),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.focused)) return focusSide;
            if (s.contains(WidgetState.disabled)) return BorderSide(color: c.stroke);
            return BorderSide(color: c.brandStroke);
          }),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minTarget),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Km1Space.md)),
          shape: WidgetStatePropertyAll(shape),
          textStyle: const WidgetStatePropertyAll(Km1Text.body1Strong),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.inkDisabled : c.ink),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return c.surface;
            if (s.contains(WidgetState.pressed)) return c.surfacePressed;
            if (s.contains(WidgetState.hovered)) return c.surfaceHover;
            return c.surface;
          }),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.focused)) return focusSide;
            return BorderSide(color: s.contains(WidgetState.disabled) ? c.stroke : c.strokeStrong);
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minTarget),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Km1Space.md)),
          shape: WidgetStatePropertyAll(shape),
          textStyle: const WidgetStatePropertyAll(Km1Text.body1Strong),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.inkDisabled : c.brandInk),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.pressed)) return c.surfacePressed;
            if (s.contains(WidgetState.hovered)) return c.surfaceHover;
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused) ? focusSide : BorderSide.none),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minTarget),
          fixedSize: WidgetStatePropertyAll(minTarget),
          shape: WidgetStatePropertyAll(shape),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.inkDisabled : c.ink),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.pressed)) return c.surfacePressed;
            if (s.contains(WidgetState.hovered)) return c.surfaceHover;
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused) ? focusSide : BorderSide.none),
        ),
      ),

      // 入力欄 / Inputs — 文字はスマホ 16px、PC 14px。ヒントは上、エラーは下。
      inputDecorationTheme: InputDecorationTheme(
        isDense: false,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Km1Space.mdNudge, vertical: Km1Space.mdNudge),
        constraints: BoxConstraints(minHeight: target),
        hintStyle: TextStyle(fontSize: fieldSize, height: (fieldSize + 8) / fieldSize, color: c.inkTertiary),
        labelStyle: Km1Text.body1.copyWith(color: c.inkSecondary),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        helperStyle: Km1Text.caption1.copyWith(color: c.inkSecondary),
        errorStyle: Km1Text.caption1.copyWith(color: c.dangerInk),
        border: border(c.strokeStrong),
        enabledBorder: border(c.strokeStrong),
        focusedBorder: border(c.focusRing, 2),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 2),
        disabledBorder: border(c.stroke),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.brandInk, selectionColor: c.brandTint),

      // 選択系 / Selection controls — 選択の縁は brandStroke。
      checkboxTheme: CheckboxThemeData(
        materialTapTargetSize: tapSize,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Km1Radius.sm)),
        side: WidgetStateBorderSide.resolveWith((s) => BorderSide(
              color: s.contains(WidgetState.disabled) ? c.stroke : (s.contains(WidgetState.selected) ? c.brandStroke : c.strokeStrong),
              width: 1,
            )),
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.surfaceMuted;
          return s.contains(WidgetState.selected) ? c.brand : Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(c.onBrand),
      ),
      radioTheme: RadioThemeData(
        materialTapTargetSize: tapSize,
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.inkDisabled;
          return s.contains(WidgetState.selected) ? c.brandStroke : c.strokeStrong;
        }),
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: tapSize,
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.inkDisabled;
          return s.contains(WidgetState.selected) ? c.onBrand : c.inkSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.surfaceMuted;
          return s.contains(WidgetState.selected) ? c.brand : c.surfaceMuted;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.stroke;
          return s.contains(WidgetState.selected) ? c.brandStroke : c.strokeStrong;
        }),
      ),

      // タブ / Tabs
      tabBarTheme: TabBarThemeData(
        labelColor: c.ink,
        unselectedLabelColor: c.inkSecondary,
        labelStyle: Km1Text.body1Strong,
        unselectedLabelStyle: Km1Text.body1,
        indicatorColor: c.brandStroke,
        dividerColor: c.strokeSubtle,
        indicatorSize: TabBarIndicatorSize.label,
        overlayColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.pressed) ? c.surfacePressed : (s.contains(WidgetState.hovered) ? c.surfaceHover : null)),
      ),

      // カード・ダイアログ / Cards & dialogs
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Km1Radius.lg),
          side: BorderSide(color: c.stroke),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Km1Radius.xl),
          side: BorderSide(color: c.stroke),
        ),
        titleTextStyle: Km1Text.title3.copyWith(color: c.ink),
        contentTextStyle: Km1Text.body1.copyWith(color: c.ink),
        actionsPadding: const EdgeInsets.all(Km1Space.xxl),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceSunken,
        contentTextStyle: Km1Text.body1.copyWith(color: c.ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Km1Radius.lg),
          side: BorderSide(color: c.stroke),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: target,
        textColor: c.ink,
        iconColor: c.ink,
      ),
    );
  }
}
