import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../order/domain/models/order_model.dart';
import '../../order/domain/order_provider.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/km1.dart';

class ClosingScreen extends ConsumerStatefulWidget {
  const ClosingScreen({super.key});
  @override
  ConsumerState<ClosingScreen> createState() => _ClosingScreenState();
}

class _ClosingScreenState extends ConsumerState<ClosingScreen> {
  final _cashCtrl = TextEditingController();
  final _openingCashCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // 開設金をコントローラーに初期値セット（有効な値があれば）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stored = ref.read(authStateProvider).openingCash;
      if (stored != null && stored > 0) {
        setState(() {
          _openingCashCtrl.text = stored.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _openingCashCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_cashCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('実際のレジ内金を入力してください。')));
      return;
    }
    if (_openingCashCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('開設金を入力してください。')));
      return;
    }
    // 締めは取り消せないため、先に確認する
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('今日の営業を締めますか'),
        content: const Text('締めたあとは、この営業日に注文を追加できません。締めると売上の Excel ファイルがダウンロードされます。'),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: km1DangerButton(ctx),
              child: const Text('締める')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.closeBusinessDay();
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? '締めることができませんでした。通信状態を確認してもう一度お試しください（${e.message}）';
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg.toString())));
      setState(() => _loading = false);
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('締めることができませんでした。もう一度お試しください（$e）')));
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = false);
    if (!mounted) return;
    // 締め完了後、開設金を localStorage から削除
    try { html.window.localStorage.remove('pos_opening_cash'); } catch (_) {}
    _exportExcel(); // 締め完了後 Excel ダウンロード
    await _showClosingReport();
  }

  // ─── Excel エクスポート ───────────────────────────────────────
  void _exportExcel() {
    final orders = ref.read(orderListProvider);
    final completedOrders = orders.where((o) => o.isCompleted).toList();
    final details = ref.read(productSaleDetailsProvider);
    final storeName = ref.read(authStateProvider).storeName ?? 'store';
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final excel = Excel.createExcel();

    // ── Sheet 1: 商品別売上 ──────────────────────────────────────
    final s1 = excel['商品別売上'];

    // ヘッダー
    s1.appendRow([
      TextCellValue('商品名'),
      TextCellValue('単価'),
      TextCellValue('値引き'),
      TextCellValue('個数'),
      TextCellValue('合計'),
    ]);

    for (final d in details) {
      s1.appendRow([
        TextCellValue(d.name),
        IntCellValue(d.unitPrice),
        TextCellValue(d.discountPerItem > 0 ? '${d.discountPerItem}円引き' : ''),
        IntCellValue(d.quantity),
        IntCellValue(d.amount),
      ]);
    }

    // 合計行
    final totalQty = details.fold(0, (s, d) => s + d.quantity);
    final totalAmt = completedOrders.fold(0, (s, o) => s + o.totalAmount);
    s1.appendRow([
      TextCellValue('合計'),
      TextCellValue(''),
      TextCellValue(''),
      IntCellValue(totalQty),
      IntCellValue(totalAmt),
    ]);

    // ── Sheet 2: タイムログ ──────────────────────────────────────
    final s2 = excel['タイムログ'];

    s2.appendRow([
      TextCellValue('時刻'),
      TextCellValue('注文番号'),
      TextCellValue('商品名'),
      TextCellValue('単価'),
      TextCellValue('個数'),
      TextCellValue('小計'),
      TextCellValue('割引'),
      TextCellValue('合計'),
      TextCellValue('支払方法'),
    ]);

    final sortedOrders = completedOrders.toList()
      ..sort((a, b) => a.orderedAt.compareTo(b.orderedAt));

    for (final order in sortedOrders) {
      final t = order.orderedAt;
      final timeStr =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
      final payment =
          order.paymentMethod == PaymentMethod.cash ? '現金' : 'カード';

      for (int i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        final itemTotal = item.unitPrice * item.quantity;
        s2.appendRow([
          TextCellValue(i == 0 ? timeStr : ''),
          TextCellValue(i == 0 ? order.orderNumber : ''),
          TextCellValue(item.productName),
          IntCellValue(item.unitPrice),
          IntCellValue(item.quantity),
          IntCellValue(itemTotal),
          i == 0 ? IntCellValue(order.discountAmount) : TextCellValue(''),
          i == 0 ? IntCellValue(order.totalAmount) : TextCellValue(''),
          TextCellValue(i == 0 ? payment : ''),
        ]);
      }
    }

    // デフォルトシート削除
    excel.delete('Sheet1');

    // ダウンロード
    final bytes = excel.save();
    if (bytes == null) return;
    final blob = html.Blob(
      [Uint8List.fromList(bytes)],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'kami2pos_${storeName}_$dateStr.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _showClosingReport() async {
    final orders = ref.read(orderListProvider);
    final completedOrders = orders.where((o) => o.isCompleted).toList();
    final totalAmount = completedOrders.fold(0, (s, o) => s + o.totalAmount);
    final cashSalesTotal = completedOrders
        .where((o) => o.paymentMethod == PaymentMethod.cash)
        .fold(0, (s, o) => s + o.totalAmount);
    final discountSummary = ref.read(discountSummaryProvider);
    final details = ref.read(productSaleDetailsProvider);
    final openingCash = int.tryParse(_openingCashCtrl.text) ?? ref.read(authStateProvider).openingCash ?? 0;
    final actualCash = int.tryParse(_cashCtrl.text) ?? 0;
    final theoreticalCash = openingCash + cashSalesTotal;
    final cashDiff = actualCash - theoreticalCash;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = ctx.km1;
        return AlertDialog(
          title: const Text('締めのレポート'),
          content: SizedBox(
            width: Km1Size.dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Km1Notice(
                        status: Km1Status.success,
                        title: '締めが完了しました',
                        body: '売上の Excel ファイルをダウンロードしました。'),
                    const SizedBox(height: Km1Space.lg),
                    _ReportRow('注文件数', '${completedOrders.length} 件'),
                    _ReportRow('販売総数',
                        '${details.fold(0, (s, d) => s + d.quantity)} 点',
                        bold: true),
                    if (discountSummary.autoDiscount > 0)
                      _ReportRow('セット割', '-¥${discountSummary.autoDiscount}'),
                    if (discountSummary.manualDiscount > 0)
                      _ReportRow(
                          '手動割引', '-¥${discountSummary.manualDiscount}'),
                    Divider(color: c.strokeSubtle),
                    _ReportRow('売上合計', '¥$totalAmount', bold: true, large: true),
                    Divider(color: c.strokeSubtle),
                    _ReportRow('開設金', '¥$openingCash'),
                    _ReportRow('現金売上', '+¥$cashSalesTotal'),
                    _ReportRow('理論上のレジ内金', '¥$theoreticalCash', bold: true),
                    _ReportRow('実際のレジ内金', '¥${_cashCtrl.text}'),
                    const SizedBox(height: Km1Space.sm),
                    _CashDiff(diff: cashDiff),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: Km1Space.lg),
                      Text('商品別売上',
                          style: Km1Text.body1Strong.copyWith(color: c.ink)),
                      const SizedBox(height: Km1Space.xs),
                      ...details.map((d) => _ProductDetailRow(d)),
                    ],
                  ]),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(authStateProvider.notifier).state = const AuthState();
                context.go('/login');
              },
              child: const Text('ログアウト'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final orders = ref.watch(orderListProvider);
    final completedOrders = orders.where((o) => o.isCompleted).toList();
    final totalSold = ref.watch(totalSoldProvider);
    final totalAmount = completedOrders.fold(0, (s, o) => s + o.totalAmount);
    final cashSalesTotal = completedOrders
        .where((o) => o.paymentMethod == PaymentMethod.cash)
        .fold(0, (s, o) => s + o.totalAmount);
    final discountSummary = ref.watch(discountSummaryProvider);
    final details = ref.watch(productSaleDetailsProvider);
    final authState = ref.watch(authStateProvider);
    final storeName = authState.storeName ?? '';
    final openingCash = int.tryParse(_openingCashCtrl.text) ?? authState.openingCash ?? 0;
    final theoreticalCash = openingCash + cashSalesTotal;
    final actualCash = int.tryParse(_cashCtrl.text) ?? 0;
    final cashDiff = actualCash - theoreticalCash;
    final titleStyle = Theme.of(context).textTheme.titleSmall;

    Widget card(List<Widget> children) => Container(
          decoration: km1CardDecoration(context),
          padding: const EdgeInsets.all(Km1Space.lg),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        );

    Widget headCell(String t, {double? width, bool end = true}) {
      final text = Text(t,
          textAlign: end ? TextAlign.right : TextAlign.left,
          style: Km1Text.caption1.copyWith(color: c.inkSecondary));
      return width == null ? Expanded(child: text) : SizedBox(width: width, child: text);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('締め - $storeName'),
        bottom: storeBand(authState.themeColor),
        leading: IconButton(
          icon: const Icon(Km1Icons.back),
          tooltip: '戻る',
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Km1Size.dialogWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Km1Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── 売上サマリー ───
                card([
                  Text('今日の売上', style: titleStyle),
                  const SizedBox(height: Km1Space.md),
                  _ReportRow('注文件数', '${completedOrders.length} 件'),
                  _ReportRow('販売総数', '$totalSold 点', bold: true),
                  if (discountSummary.autoDiscount > 0)
                    _ReportRow('セット割', '-¥${discountSummary.autoDiscount}'),
                  if (discountSummary.manualDiscount > 0)
                    _ReportRow('手動割引', '-¥${discountSummary.manualDiscount}'),
                  Divider(color: c.strokeSubtle),
                  _ReportRow('売上合計', '¥$totalAmount', bold: true, large: true),
                ]),
                const SizedBox(height: Km1Space.lg),

                // ─── 商品別売上 ───
                if (details.isNotEmpty) ...[
                  Container(
                    decoration: km1CardDecoration(context),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text('商品別売上（合計 $totalSold 点）',
                          style: Km1Text.body1Strong.copyWith(color: c.ink)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Km1Space.lg, 0, Km1Space.lg, Km1Space.lg),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: Km1Space.xs),
                                child: Row(children: [
                                  headCell('商品', end: false),
                                  headCell('単価', width: 72),
                                  headCell('数量', width: 48),
                                  headCell('金額', width: 72),
                                ]),
                              ),
                              Divider(height: Km1Space.sm, color: c.strokeSubtle),
                              ...details.map((d) => _ProductDetailRow(d)),
                              Divider(height: Km1Space.sm, color: c.strokeSubtle),
                              _ProductTotalRow(
                                  quantity: totalSold,
                                  amount: details.fold(0, (s, d) => s + d.amount)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Km1Space.lg),
                ],

                // ─── 開設金・レジ内金の入力 ───
                card([
                  Text('レジ内金', style: titleStyle),
                  const SizedBox(height: Km1Space.md),
                  if (_openingCashCtrl.text.isEmpty) ...[
                    const Km1Notice(
                      status: Km1Status.warning,
                      title: '開設金が入っていません',
                      body: '今日の開設時に入力した金額を入れてください。',
                    ),
                    const SizedBox(height: Km1Space.md),
                  ],
                  Km1Field(
                    label: '開設金（開始時のレジ内金、円）',
                    child: TextField(
                      controller: _openingCashCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          prefixText: '¥ ', hintText: '50000'),
                    ),
                  ),
                  const SizedBox(height: Km1Space.lg),
                  Km1Field(
                    label: '実際のレジ内金（締め時、円）',
                    child: TextField(
                      controller: _cashCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(prefixText: '¥ '),
                    ),
                  ),
                ]),
                const SizedBox(height: Km1Space.lg),

                // ─── 理論締め金・差額 ───
                card([
                  Text('レジの過不足', style: titleStyle),
                  const SizedBox(height: Km1Space.md),
                  _ReportRow('開設金', '¥$openingCash'),
                  _ReportRow('現金売上', '+¥$cashSalesTotal'),
                  Divider(color: c.strokeSubtle),
                  _ReportRow('理論上のレジ内金', '¥$theoreticalCash', bold: true),
                  if (_cashCtrl.text.isNotEmpty) ...[
                    _ReportRow('実際のレジ内金', '¥${_cashCtrl.text}'),
                    const SizedBox(height: Km1Space.sm),
                    _CashDiff(diff: cashDiff),
                  ],
                ]),
                const SizedBox(height: Km1Space.xxl),

                FilledButton.icon(
                  style: km1DangerButton(context),
                  onPressed: _loading ? null : _close,
                  icon: const Icon(Km1Icons.lock, size: Km1Size.iconMd),
                  label: Text(_loading ? '締めています' : '締める'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── レジの差額（一致 = 成功、過剰 = 注意、不足 = エラー。文言でも示す） ───
class _CashDiff extends StatelessWidget {
  final int diff;
  const _CashDiff({required this.diff});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final (Color ink, Color tint, IconData icon, String label, String value) =
        diff == 0
            ? (c.successInk, c.successTint, Km1Icons.checkCircle, '差額（一致）', '±¥0')
            : diff > 0
                ? (c.warningInk, c.warningTint, Km1Icons.warning, '差額（多い）', '+¥$diff')
                : (c.dangerInk, c.dangerTint, Km1Icons.error, '差額（足りない）', '-¥${diff.abs()}');
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: Km1Space.md, horizontal: Km1Space.lg),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(Km1Radius.lg),
        border: Border.all(color: ink),
      ),
      child: Row(
        children: [
          Icon(icon, color: ink, size: Km1Size.iconMd),
          const SizedBox(width: Km1Space.sm),
          Text(label, style: Km1Text.body1Strong.copyWith(color: c.ink)),
          const Spacer(),
          Text(value,
              style: Km1Text.subtitle1.copyWith(
                  color: c.ink,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

// ─── 商品別売上行 ────────────────────────────────────────────
class _ProductDetailRow extends StatelessWidget {
  final ProductSaleDetail detail;
  const _ProductDetailRow(this.detail);

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    const tabular = [FontFeature.tabularFigures()];
    final numStyle = Km1Text.body1.copyWith(color: c.ink, fontFeatures: tabular);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Km1Space.xs),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(detail.name,
                  style: Km1Text.body1.copyWith(color: c.ink),
                  overflow: TextOverflow.ellipsis),
              if (detail.discountPerItem > 0)
                Text('1 つあたり ${detail.discountPerItem} 円引き',
                    style: Km1Text.caption1.copyWith(color: c.successInk)),
            ],
          ),
        ),
        SizedBox(
            width: 72,
            child: Text('¥${detail.unitPrice}',
                textAlign: TextAlign.right,
                style: numStyle.copyWith(color: c.inkSecondary))),
        SizedBox(
            width: 48,
            child: Text('${detail.quantity}',
                textAlign: TextAlign.right, style: numStyle)),
        SizedBox(
            width: 72,
            child: Text('¥${detail.amount}',
                textAlign: TextAlign.right, style: numStyle)),
      ]),
    );
  }
}

class _ProductTotalRow extends StatelessWidget {
  final int quantity, amount;
  const _ProductTotalRow({required this.quantity, required this.amount});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final style = Km1Text.body1Strong.copyWith(
        color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]);
    return Row(children: [
      Expanded(child: Text('合計', style: style)),
      const SizedBox(width: 72),
      SizedBox(
          width: 48,
          child: Text('$quantity', textAlign: TextAlign.right, style: style)),
      SizedBox(
          width: 72,
          child: Text('¥$amount', textAlign: TextAlign.right, style: style)),
    ]);
  }
}

// ─── サマリー行 ──────────────────────────────────────────────
class _ReportRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final bool large;
  const _ReportRow(this.label, this.value,
      {this.bold = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final valueStyle = (large
            ? Km1Text.title3
            : bold
                ? Km1Text.body1Strong
                : Km1Text.body1)
        .copyWith(
            color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Km1Space.xxs),
      child: Row(children: [
        Text(label,
            style: (bold ? Km1Text.body1Strong : Km1Text.body1)
                .copyWith(color: bold ? c.ink : c.inkSecondary)),
        const Spacer(),
        Text(value, style: valueStyle),
      ]),
    );
  }
}
