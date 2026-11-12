// KM1 をこのアプリで使うための入口。
// - AppTheme: km1_theme.dart（自動生成・編集しない）の上に、上部バー・チップなど
//   km1_theme.dart にない部品の見た目と、Noto Sans JP の読み込みを足す。
// - context.km1: 意味づけトークン（Km1Colors）を取り出す。
// - Km1Icons: Fluent System Icons への対応表。Icons.*（Material）は使わない。
// - Km1Field / StoreBand / Km1Notice: 画面で繰り返し使う KM1 の組み立て。
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'km1_theme.dart';

export 'km1_theme.dart';

extension Km1Context on BuildContext {
  /// 意味づけトークン / Semantic color tokens
  Km1Colors get km1 => Theme.of(this).extension<Km1Colors>()!;

  /// 部品の高さ（スマホ 44・PC 32） / Control height (44 touch, 32 PC)
  double get km1Target => Km1Theme.isTouch ? kKm1Target : kKm1TargetCompact;
}

abstract final class AppTheme {
  static ThemeData light() =>
      _extend(Km1Theme.light(), Km1Colors.light, Brightness.light);
  static ThemeData dark() =>
      _extend(Km1Theme.dark(), Km1Colors.dark, Brightness.dark);

  static ThemeData _extend(ThemeData base, Km1Colors c, Brightness b) {
    final isDark = b == Brightness.dark;
    // 上部バー: ライトは brand の塗り + on-brand、ダークは surface-sunken + ink
    final barBg = isDark ? c.surfaceSunken : c.brand;
    final barFg = isDark ? c.ink : c.onBrand;
    final rMd = BorderRadius.circular(Km1Radius.md);
    final rLg = BorderRadius.circular(Km1Radius.lg);

    return base.copyWith(
      textTheme: GoogleFonts.notoSansJpTextTheme(base.textTheme),
      scaffoldBackgroundColor: c.surfaceSubtle,
      iconTheme: IconThemeData(color: c.ink, size: Km1Size.iconMd),
      appBarTheme: AppBarTheme(
        backgroundColor: barBg,
        foregroundColor: barFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle:
            GoogleFonts.notoSansJp(textStyle: Km1Text.subtitle1.copyWith(color: barFg)),
        iconTheme: IconThemeData(color: barFg, size: Km1Size.iconLg),
        actionsIconTheme: IconThemeData(color: barFg, size: Km1Size.iconLg),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.brandTint,
        disabledColor: c.surfaceMuted,
        checkmarkColor: c.brandInk,
        labelStyle: Km1Text.body1.copyWith(color: c.ink),
        secondaryLabelStyle: Km1Text.body1Strong.copyWith(color: c.ink),
        side: WidgetStateBorderSide.resolveWith((s) => BorderSide(
              color: s.contains(WidgetState.selected)
                  ? c.brandStroke
                  : (s.contains(WidgetState.disabled) ? c.stroke : c.strokeStrong),
            )),
        shape: RoundedRectangleBorder(borderRadius: rMd),
        padding: const EdgeInsets.symmetric(horizontal: Km1Space.sm),
        elevation: 0,
        pressElevation: 0,
        showCheckmark: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: rMd)),
          side: WidgetStateProperty.resolveWith((s) => BorderSide(
              color: s.contains(WidgetState.selected) ? c.brandStroke : c.strokeStrong)),
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? c.brandTint : c.surface),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? c.brandInk : c.ink),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand,
        linearTrackColor: c.strokeSubtle,
        circularTrackColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 8,
        shape: RoundedRectangleBorder(
            borderRadius: rLg, side: BorderSide(color: c.stroke)),
        textStyle: Km1Text.body1.copyWith(color: c.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Km1Radius.xl)),
          side: BorderSide(color: c.stroke),
        ),
        showDragHandle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Km1Text.caption1.copyWith(color: c.brandInk, fontWeight: FontWeight.w600)
                : Km1Text.caption1.copyWith(color: c.inkSecondary)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: Km1Size.iconLg,
            color: s.contains(WidgetState.selected) ? c.brandInk : c.inkSecondary)),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: c.ink,
        collapsedIconColor: c.inkSecondary,
        textColor: c.ink,
        collapsedTextColor: c.ink,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: rLg, side: BorderSide(color: c.stroke))),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: rMd,
            border: Border.all(color: c.stroke)),
        textStyle: Km1Text.caption1.copyWith(color: c.ink),
      ),
    );
  }
}

/// Fluent System Icons の対応表。1 つの意味に 1 つのアイコンを割り当てる。
/// 選択中・強調は Filled、それ以外は Regular。
abstract final class Km1Icons {
  static const IconData back = FluentIcons.arrow_left_24_regular;
  static const IconData add = FluentIcons.add_24_regular;
  static const IconData addCircle = FluentIcons.add_circle_24_regular;
  static const IconData subtract = FluentIcons.subtract_24_regular;
  static const IconData subtractCircle = FluentIcons.subtract_circle_24_regular;
  static const IconData edit = FluentIcons.edit_24_regular;
  static const IconData delete = FluentIcons.delete_24_regular;
  static const IconData close = FluentIcons.dismiss_24_regular;
  static const IconData dismissCircle = FluentIcons.dismiss_circle_24_regular;
  static const IconData check = FluentIcons.checkmark_24_regular;
  static const IconData checkCircle = FluentIcons.checkmark_circle_24_regular;
  static const IconData checkCircleFilled = FluentIcons.checkmark_circle_24_filled;
  static const IconData refresh = FluentIcons.arrow_clockwise_24_regular;
  static const IconData sync = FluentIcons.arrow_sync_24_regular;
  static const IconData copy = FluentIcons.copy_24_regular;
  static const IconData download = FluentIcons.arrow_download_24_regular;
  static const IconData print = FluentIcons.print_24_regular;
  static const IconData qrCode = FluentIcons.qr_code_24_regular;
  static const IconData more = FluentIcons.more_vertical_24_regular;
  static const IconData chevronRight = FluentIcons.chevron_right_24_regular;

  static const IconData store = FluentIcons.building_shop_24_regular;
  static const IconData person = FluentIcons.person_24_regular;
  static const IconData lock = FluentIcons.lock_closed_24_regular;
  static const IconData tablet = FluentIcons.tablet_24_regular;

  static const IconData product = FluentIcons.box_24_regular;
  static const IconData productFilled = FluentIcons.box_24_filled;
  static const IconData discount = FluentIcons.tag_24_regular;
  static const IconData discountFilled = FluentIcons.tag_24_filled;
  static const IconData order = FluentIcons.receipt_24_regular;
  static const IconData orderFilled = FluentIcons.receipt_24_filled;
  static const IconData register = FluentIcons.calculator_24_regular;
  static const IconData cash = FluentIcons.money_24_regular;
  static const IconData card = FluentIcons.payment_24_regular;
  static const IconData history = FluentIcons.history_24_regular;
  static const IconData waiting = FluentIcons.clock_24_regular;
  static const IconData notify = FluentIcons.alert_24_regular;

  static const IconData info = FluentIcons.info_24_regular;
  static const IconData warning = FluentIcons.warning_24_regular;
  static const IconData error = FluentIcons.error_circle_24_regular;
  static const IconData offline = FluentIcons.wifi_off_24_regular;
}

/// 見出しを上に置いた入力欄（KM1: ヒントは上、エラーは下）。
class Km1Field extends StatelessWidget {
  const Km1Field({super.key, required this.label, required this.child, this.isRequired = false});

  final String label;
  final Widget child;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(text: label, children: [
            if (isRequired) TextSpan(text: '（必須）', style: TextStyle(color: c.dangerInk)),
          ]),
          style: Km1Text.body1Strong.copyWith(color: c.ink),
        ),
        const SizedBox(height: Km1Space.xs),
        child,
      ],
    );
  }
}

/// 店舗の分類色。上部バーの下に 4px の帯として出す（KM1 の分類色は帯と淡い塗りだけ）。
PreferredSizeWidget? storeBand(int? storeColor) {
  if (storeColor == null) return null;
  return PreferredSize(
    preferredSize: const Size.fromHeight(Km1Size.strokeAccent),
    child: Container(height: Km1Size.strokeAccent, color: Color(storeColor)),
  );
}

/// 状態のお知らせ（KM1 Alert）。色に加えて、アイコンと「情報」「成功」「注意」「エラー」の文言を必ず出す。
enum Km1Status { info, success, warning, danger }

class Km1Notice extends StatelessWidget {
  const Km1Notice({super.key, required this.status, required this.title, this.body});

  final Km1Status status;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final (Color ink, Color tint, IconData icon, String word) = switch (status) {
      Km1Status.info => (c.infoInk, c.infoTint, Km1Icons.info, '情報'),
      Km1Status.success => (c.successInk, c.successTint, Km1Icons.checkCircle, '成功'),
      Km1Status.warning => (c.warningInk, c.warningTint, Km1Icons.warning, '注意'),
      Km1Status.danger => (c.dangerInk, c.dangerTint, Km1Icons.error, 'エラー'),
    };
    return Semantics(
      liveRegion: status == Km1Status.danger || status == Km1Status.warning,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Km1Space.lg, vertical: Km1Space.md),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(Km1Radius.lg),
          border: Border.all(color: ink),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: Km1Size.iconMd, color: ink),
            const SizedBox(width: Km1Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$word　$title', style: Km1Text.body1Strong.copyWith(color: c.ink)),
                  if (body != null) ...[
                    const SizedBox(height: Km1Space.xxs),
                    Text(body!, style: Km1Text.body1.copyWith(color: c.ink)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一覧で使うカード面（KM1 Card: surface・radius-lg・内側 16px。ダークは影の代わりに枠）。
BoxDecoration km1CardDecoration(BuildContext context, {Color? color}) {
  final c = context.km1;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: color ?? c.surface,
    borderRadius: BorderRadius.circular(Km1Radius.lg),
    border: Border.all(color: isDark ? c.stroke : c.strokeSubtle),
    boxShadow: isDark ? null : Km1Shadow.shadow2,
  );
}

/// 日付の書き方（KM1）: 「11/12（木）」、年が要るときは「2026/11/12（木）」。
String km1Date(DateTime d, {bool withYear = true}) {
  const w = ['月', '火', '水', '木', '金', '土', '日'];
  final md = '${d.month}/${d.day}（${w[d.weekday - 1]}）';
  return withYear ? '${d.year}/$md' : md;
}

/// 時刻の書き方（KM1）: 24 時間制、時の先頭に 0 を付けない「9:05」。
String km1Time(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

/// 取り消せない操作（削除など）のボタン。塗りは danger。
ButtonStyle km1DangerButton(BuildContext context) {
  final c = context.km1;
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.disabled) ? c.surfaceMuted : c.danger),
    foregroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.disabled) ? c.inkDisabled : c.onBrand),
    side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused)
        ? BorderSide(color: c.focusRing, width: 2)
        : BorderSide(color: c.danger)),
  );
}

/// 何もないときの表示（アイコン + 見出し + 次にすること）。
class Km1Empty extends StatelessWidget {
  const Km1Empty({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Km1Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Km1Size.iconLg, color: c.inkTertiary),
            const SizedBox(height: Km1Space.md),
            Text(title, style: Km1Text.subtitle2.copyWith(color: c.ink), textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: Km1Space.xs),
              Text(body!, style: Km1Text.body1.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: Km1Space.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 上部バーの操作（アイコン + 文言 + 件数）。狭い画面では文言を省き、件数とツールチップを残す。
class Km1BarAction extends StatelessWidget {
  const Km1BarAction({super.key, required this.icon, required this.label, required this.onPressed, this.count});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).appBarTheme.foregroundColor ?? context.km1.ink;
    final narrow = MediaQuery.sizeOf(context).width < Km1Breakpoint.lg;
    final countText = (count != null && count! > 0) ? ' ${count!}' : '';
    return Tooltip(
      message: '$label$countText',
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(fg),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.pressed)) return fg.withValues(alpha: 0.20);
            if (s.contains(WidgetState.hovered)) return fg.withValues(alpha: 0.12);
            return Colors.transparent;
          }),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Km1Space.sm)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: Km1Size.iconMd, color: fg),
          if (!narrow) ...[
            const SizedBox(width: Km1Space.xs),
            Text(label),
          ],
          if (countText.isNotEmpty) ...[
            const SizedBox(width: Km1Space.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Km1Space.smNudge),
              decoration: BoxDecoration(
                color: fg,
                borderRadius: BorderRadius.circular(Km1Radius.circular),
              ),
              child: Text('${count!}',
                  style: Km1Text.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).appBarTheme.backgroundColor)),
            ),
          ],
        ]),
      ),
    );
  }
}
