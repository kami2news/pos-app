import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/km1.dart';
import '../../../core/network/api_service.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../order/domain/models/order_model.dart';
import '../../order/domain/models/order_item.dart';

// ─── JSON → OrderModel 変換ヘルパー ─────────────────────────────
OrderModel _orderFromMap(Map<String, dynamic> m) {
  final rawItems = (m['items'] as List? ?? []);
  final items = rawItems.map<OrderItem>((i) => OrderItem(
        productId: i['product_id'] as String? ?? '',
        productName: i['product_name'] as String? ?? '',
        unitPrice: (i['unit_price'] as num).toInt(),
        quantity: (i['quantity'] as num).toInt(),
      )).toList();
  return OrderModel(
    id: m['id'] as String,
    orderNumber: m['order_number'] as String,
    items: List.unmodifiable(items),
    subtotal: (m['subtotal'] as num).toInt(),
    discountAmount: (m['discount_amount'] as num? ?? 0).toInt(),
    manualDiscountAmount: (m['manual_discount_amount'] as num? ?? 0).toInt(),
    totalAmount: (m['total_amount'] as num).toInt(),
    orderedAt: DateTime.parse(m['ordered_at'] as String).toLocal(),
    status: _statusFrom(m['status'] as String? ?? 'pending'),
    paymentMethod: _paymentFrom(m['payment_method']),
    receivedAmount: m['received_amount'] as int?,
  );
}

OrderStatus _statusFrom(String s) => switch (s) {
      'completed'      => OrderStatus.completed,
      'readyForPickup' => OrderStatus.readyForPickup,
      'cancelled'      => OrderStatus.cancelled,
      _                => OrderStatus.pending,
    };

PaymentMethod? _paymentFrom(dynamic s) => switch (s) {
      'cash' => PaymentMethod.cash,
      'card' => PaymentMethod.card,
      _      => null,
    };

// ─── Provider: 営業日一覧 ────────────────────────────────────────
final businessDaysProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getBusinessDays();
});

// ─── Provider: 特定営業日の注文一覧 ──────────────────────────────
final businessDayOrdersProvider = FutureProvider.autoDispose
    .family<List<OrderModel>, String>((ref, bdId) async {
  final api = ref.watch(apiServiceProvider);
  final raw = await api.getBusinessDayOrders(bdId);
  return raw.map(_orderFromMap).toList();
});

// ─── 営業日一覧画面 ───────────────────────────────────────────────
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final storeName = auth.storeName ?? '';
    final asyncDays = ref.watch(businessDaysProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('営業日の履歴 - $storeName'),
        bottom: storeBand(auth.themeColor),
        leading: IconButton(
          icon: const Icon(Km1Icons.back),
          tooltip: '戻る',
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: asyncDays.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Km1Empty(
          icon: Km1Icons.error,
          title: '履歴を読み込めませんでした',
          body: '通信状態を確認して、もう一度お試しください（$e）',
          action: FilledButton(
            onPressed: () => ref.invalidate(businessDaysProvider),
            child: const Text('もう一度読み込む'),
          ),
        ),
        data: (days) {
          if (days.isEmpty) {
            return const Km1Empty(
              icon: Km1Icons.history,
              title: '営業日の記録がありません',
              body: '開設して締めると、ここに記録が残ります。',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(Km1Space.lg),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(height: Km1Space.sm),
            itemBuilder: (_, i) => _BusinessDayTile(day: days[i]),
          );
        },
      ),
    );
  }
}

// ─── 営業日タイル ──────────────────────────────────────────────────
class _BusinessDayTile extends StatelessWidget {
  final Map<String, dynamic> day;
  const _BusinessDayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final openedAt =
        DateTime.tryParse(day['opened_at'] as String? ?? '')?.toLocal();
    final closedAt = day['closed_at'] != null
        ? DateTime.tryParse(day['closed_at'] as String)?.toLocal()
        : null;
    final total = day['total_amount'] as int? ?? 0;
    final cashAmt = day['cash_amount'] as int? ?? 0;
    final cardAmt = day['card_amount'] as int? ?? 0;
    final count = day['order_count'] as int? ?? 0;
    final isActive = day['is_active'] as bool? ?? false;

    final dateStr = openedAt != null ? km1Date(openedAt) : '---';
    final openStr = openedAt != null ? km1Time(openedAt) : '--:--';
    final closeStr = closedAt != null
        ? km1Time(closedAt)
        : isActive
            ? '営業中'
            : '--:--';

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Km1Radius.lg),
        side: BorderSide(color: c.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        hoverColor: c.surfaceHover,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HistoryDetailScreen(
              businessDayId: day['id'] as String,
              dateStr: dateStr,
              openStr: openStr,
              closeStr: closeStr,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Km1Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(dateStr,
                      style: Km1Text.subtitle2.copyWith(color: c.ink)),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Km1Space.sm, vertical: Km1Space.xxs),
                    decoration: BoxDecoration(
                      color: c.successTint,
                      border: Border.all(color: c.successInk),
                      borderRadius: BorderRadius.circular(Km1Radius.md),
                    ),
                    child: Text('営業中',
                        style: Km1Text.caption1.copyWith(color: c.ink)),
                  ),
                const SizedBox(width: Km1Space.xs),
                Icon(Km1Icons.chevronRight,
                    size: Km1Size.iconSm,
                    color: c.inkTertiary),
              ]),
              const SizedBox(height: Km1Space.xs),
              Text('$openStr 開設 〜 $closeStr 締め',
                  style: Km1Text.body1.copyWith(color: c.inkSecondary)),
              const SizedBox(height: Km1Space.md),
              Wrap(spacing: Km1Space.lg, runSpacing: Km1Space.sm, children: [
                _Stat(label: '売上合計', value: '¥${_fmt(total)}'),
                _Stat(label: '現金', value: '¥${_fmt(cashAmt)}'),
                _Stat(label: 'カード', value: '¥${_fmt(cardAmt)}'),
                _Stat(label: '件数', value: '$count 件'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Km1Text.caption1.copyWith(color: c.inkSecondary)),
        Text(value, style: Km1Text.body1Strong.copyWith(color: c.ink)),
      ],
    );
  }
}

// ─── 営業日詳細画面（締め報告表示）────────────────────────────────
class HistoryDetailScreen extends ConsumerWidget {
  final String businessDayId;
  final String dateStr;
  final String openStr;
  final String closeStr;

  const HistoryDetailScreen({
    super.key,
    required this.businessDayId,
    required this.dateStr,
    required this.openStr,
    required this.closeStr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrders =
        ref.watch(businessDayOrdersProvider(businessDayId));
    final storeColor = ref.watch(authStateProvider.select((s) => s.themeColor));

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
        bottom: storeBand(storeColor),
        actions: [
          asyncOrders.whenOrNull(
                data: (orders) => Km1BarAction(
                  icon: Km1Icons.download,
                  label: 'Excel に出力',
                  onPressed: () => _exportExcel(context, orders),
                ),
              ) ??
              const SizedBox.shrink(),
          const SizedBox(width: Km1Space.xs),
        ],
      ),
      body: asyncOrders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Km1Empty(
          icon: Km1Icons.error,
          title: '注文を読み込めませんでした',
          body: '通信状態を確認して、もう一度お試しください（$e）',
        ),
        data: (orders) => _buildReport(context, orders),
      ),
    );
  }

  Widget _buildReport(BuildContext context, List<OrderModel> orders) {
    final c = context.km1;
    final completed = orders.where((o) => o.isCompleted).toList();
    final cancelled = orders.where((o) => o.isCancelled).toList();

    final totalSales =
        completed.fold<int>(0, (s, o) => s + o.totalAmount);
    final cashSales = completed
        .where((o) => o.paymentMethod == PaymentMethod.cash)
        .fold<int>(0, (s, o) => s + o.totalAmount);
    final cardSales = completed
        .where((o) => o.paymentMethod == PaymentMethod.card)
        .fold<int>(0, (s, o) => s + o.totalAmount);
    final totalDiscount = completed.fold<int>(
        0, (s, o) => s + o.discountAmount + o.manualDiscountAmount);

    // 商品別集計
    final productMap = <String, int>{};
    final productPriceMap = <String, int>{};
    for (final o in completed) {
      for (final item in o.items) {
        productMap[item.productName] =
            (productMap[item.productName] ?? 0) + item.quantity;
        productPriceMap[item.productName] = item.unitPrice;
      }
    }
    final productEntries = productMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    const tabular = [FontFeature.tabularFigures()];

    Widget card(List<Widget> children) => Container(
          decoration: km1CardDecoration(context),
          padding: const EdgeInsets.all(Km1Space.lg),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Km1Size.contentWidth),
        child: ListView(
          padding: const EdgeInsets.all(Km1Space.lg),
          children: [
            Row(children: [
              Icon(Km1Icons.waiting, color: c.inkSecondary, size: Km1Size.iconMd),
              const SizedBox(width: Km1Space.sm),
              Text('$openStr 開設 〜 $closeStr 締め',
                  style: Km1Text.body1.copyWith(color: c.inkSecondary)),
            ]),
            const SizedBox(height: Km1Space.md),

            // 売上サマリー
            card([
              Text('売上', style: titleStyle),
              const SizedBox(height: Km1Space.md),
              _ReportRow(label: '完了した注文', value: '${completed.length} 件'),
              _ReportRow(label: '取り消した注文', value: '${cancelled.length} 件'),
              Divider(height: Km1Space.xl, color: c.strokeSubtle),
              _ReportRow(label: '現金売上', value: '¥${_fmt(cashSales)}'),
              _ReportRow(label: 'カード売上', value: '¥${_fmt(cardSales)}'),
              if (totalDiscount > 0)
                _ReportRow(label: '割引合計', value: '-¥${_fmt(totalDiscount)}'),
              Divider(height: Km1Space.xl, color: c.strokeSubtle),
              _ReportRow(
                  label: '売上合計', value: '¥${_fmt(totalSales)}', bold: true),
            ]),
            const SizedBox(height: Km1Space.lg),

            // 商品別売上
            if (productEntries.isNotEmpty) ...[
              card([
                Text('商品別売上', style: titleStyle),
                const SizedBox(height: Km1Space.md),
                ...productEntries.map((e) {
                  final revenue = e.value * (productPriceMap[e.key] ?? 0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: Km1Space.xs),
                    child: Row(children: [
                      Expanded(
                        child: Text(e.key,
                            style: Km1Text.body1.copyWith(color: c.ink)),
                      ),
                      Text('${e.value} 個',
                          style: Km1Text.body1.copyWith(
                              color: c.inkSecondary, fontFeatures: tabular)),
                      SizedBox(
                        width: 96,
                        child: Text('¥${_fmt(revenue)}',
                            textAlign: TextAlign.right,
                            style: Km1Text.body1
                                .copyWith(color: c.ink, fontFeatures: tabular)),
                      ),
                    ]),
                  );
                }),
                Divider(height: Km1Space.xl, color: c.strokeSubtle),
                Row(children: [
                  Expanded(
                      child: Text('合計',
                          style: Km1Text.body1Strong.copyWith(color: c.ink))),
                  Text('¥${_fmt(totalSales)}',
                      style: Km1Text.subtitle2
                          .copyWith(color: c.ink, fontFeatures: tabular)),
                ]),
              ]),
              const SizedBox(height: Km1Space.lg),
            ],

            // 注文詳細一覧
            card([
              Row(children: [
                Text('注文', style: titleStyle),
                const Spacer(),
                Text('全 ${orders.length} 件',
                    style: Km1Text.body1.copyWith(color: c.inkSecondary)),
              ]),
              const SizedBox(height: Km1Space.sm),
              ...orders.map((o) => _OrderTile(order: o)),
            ]),
            const SizedBox(height: Km1Space.xxl),
          ],
        ),
      ),
    );
  }

  // ─── Excel 出力 ───
  Future<void> _exportExcel(
      BuildContext context, List<OrderModel> orders) async {
    try {
      final completed = orders.where((o) => o.isCompleted).toList();
      final excel = Excel.createExcel();
      final sheet = excel['締め報告_$dateStr'];

      sheet.appendRow([
        TextCellValue('注文番号'),
        TextCellValue('時刻'),
        TextCellValue('商品'),
        TextCellValue('小計'),
        TextCellValue('割引'),
        TextCellValue('合計'),
        TextCellValue('支払方法'),
      ]);

      for (final o in completed) {
        final time = o.orderedAt.toLocal();
        final timeStr =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        final itemStr = o.items
            .map((i) => '${i.productName}×${i.quantity}')
            .join(' / ');
        final discount = o.discountAmount + o.manualDiscountAmount;
        sheet.appendRow([
          TextCellValue(o.orderNumber),
          TextCellValue(timeStr),
          TextCellValue(itemStr),
          IntCellValue(o.subtotal),
          IntCellValue(discount),
          IntCellValue(o.totalAmount),
          TextCellValue(
              o.paymentMethod == PaymentMethod.cash ? '現金' : 'カード'),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) return;

      final blob = html.Blob(
          [Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = '締め報告_$dateStr.xlsx'
        ..click();
      html.Url.revokeObjectUrl(url);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel ファイルをダウンロードしました。')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel ファイルを作れませんでした。もう一度お試しください（$e）')),
      );
    }
  }

  static String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ─── 小ウィジェット ────────────────────────────────────────────────
class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _ReportRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Km1Space.xxs),
      child: Row(children: [
        Text(label,
            style: (bold ? Km1Text.body1Strong : Km1Text.body1)
                .copyWith(color: bold ? c.ink : c.inkSecondary)),
        const Spacer(),
        Text(value,
            style: (bold ? Km1Text.subtitle1 : Km1Text.body1).copyWith(
                color: c.ink,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final (Color ink, Color tint, String statusLabel) = order.isCompleted
        ? (c.successInk, c.successTint, '完了')
        : order.isCancelled
            ? (c.inkTertiary, c.surfaceMuted, '取り消し')
            : (c.warningInk, c.warningTint, '未完了');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Km1Space.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 48,
          child: Text(order.orderNumber,
              style: Km1Text.body1Strong.copyWith(color: c.ink)),
        ),
        const SizedBox(width: Km1Space.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(km1Time(order.orderedAt.toLocal()),
                    style: Km1Text.caption1.copyWith(color: c.inkSecondary)),
                const SizedBox(width: Km1Space.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Km1Space.smNudge, vertical: 0),
                  decoration: BoxDecoration(
                    color: tint,
                    border: Border.all(color: ink),
                    borderRadius: BorderRadius.circular(Km1Radius.md),
                  ),
                  child: Text(statusLabel,
                      style: Km1Text.caption1.copyWith(color: c.ink)),
                ),
              ]),
              const SizedBox(height: Km1Space.xxs),
              Text(
                order.items
                    .map((i) => '${i.productName} × ${i.quantity}')
                    .join('、'),
                style: Km1Text.body1.copyWith(color: c.inkSecondary),
              ),
            ],
          ),
        ),
        Text('¥${order.totalAmount}',
            style: Km1Text.body1Strong.copyWith(
                color: c.ink,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}
