import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final storeName = ref.watch(authStateProvider).storeName ?? '';
    final asyncDays = ref.watch(businessDaysProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('営業日履歴 - $storeName'),
      ),
      body: asyncDays.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('取得失敗: $e',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(businessDaysProvider),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
        data: (days) {
          if (days.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('営業日の記録がありません',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: days.length,
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

    final dateStr = openedAt != null
        ? '${openedAt.year}年${openedAt.month}月${openedAt.day}日'
        : '---';
    final openStr = openedAt != null
        ? '${openedAt.hour.toString().padLeft(2, '0')}:${openedAt.minute.toString().padLeft(2, '0')}'
        : '--:--';
    final closeStr = closedAt != null
        ? '${closedAt.hour.toString().padLeft(2, '0')}:${closedAt.minute.toString().padLeft(2, '0')}'
        : isActive
            ? '営業中'
            : '--:--';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(dateStr,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('営業中',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text('$openStr 開設 → $closeStr 締め',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                _Stat(label: '売上合計', value: '¥${_fmt(total)}'),
                const SizedBox(width: 16),
                _Stat(label: '現金', value: '¥${_fmt(cashAmt)}'),
                const SizedBox(width: 16),
                _Stat(label: 'カード', value: '¥${_fmt(cardAmt)}'),
                const Spacer(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
        actions: [
          asyncOrders.whenOrNull(
                data: (orders) => IconButton(
                  onPressed: () => _exportExcel(context, orders),
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Excel出力',
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: asyncOrders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('取得失敗: $e')),
        data: (orders) => _buildReport(context, orders),
      ),
    );
  }

  Widget _buildReport(BuildContext context, List<OrderModel> orders) {
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 開設・締め時刻
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.access_time, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text('$openStr 開設 → $closeStr 締め',
                  style:
                      const TextStyle(fontSize: 14, color: Colors.grey)),
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // 売上サマリー
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('売上サマリー',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _ReportRow(
                    label: '完了件数', value: '${completed.length} 件'),
                _ReportRow(
                    label: 'キャンセル件数',
                    value: '${cancelled.length} 件'),
                const Divider(height: 20),
                _ReportRow(
                    label: '現金売上',
                    value: '¥${_fmt(cashSales)}',
                    valueColor: Colors.black87),
                _ReportRow(
                    label: 'カード売上',
                    value: '¥${_fmt(cardSales)}',
                    valueColor: Colors.black87),
                if (totalDiscount > 0)
                  _ReportRow(
                      label: '割引合計',
                      value: '-¥${_fmt(totalDiscount)}',
                      valueColor: Colors.orange.shade700),
                const Divider(height: 20),
                _ReportRow(
                  label: '売上合計',
                  value: '¥${_fmt(totalSales)}',
                  bold: true,
                  valueColor: const Color(0xFF1456A0),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 商品別売上
        if (productEntries.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('商品別売上',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...productEntries.map((e) {
                    final revenue =
                        e.value * (productPriceMap[e.key] ?? 0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(
                          child: Text(e.key,
                              style: const TextStyle(fontSize: 14)),
                        ),
                        Text('${e.value} 個',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 90,
                          child: Text('¥${_fmt(revenue)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14)),
                        ),
                      ]),
                    );
                  }),
                  const Divider(height: 20),
                  Row(children: [
                    const Expanded(
                        child: Text('合計',
                            style: TextStyle(
                                fontWeight: FontWeight.bold))),
                    Text('¥${_fmt(totalSales)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1456A0))),
                  ]),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),

        // 注文詳細一覧
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('注文一覧',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('全 ${orders.length} 件',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                ...orders.map((o) => _OrderTile(order: o)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
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
        const SnackBar(content: Text('Excelをダウンロードしました')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel出力失敗: $e')),
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
  final Color? valueColor;

  const _ReportRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor)),
      ]),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final time = order.orderedAt.toLocal();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    final Color statusColor;
    final String statusLabel;
    if (order.isCompleted) {
      statusColor = Colors.green;
      statusLabel = '完了';
    } else if (order.isCancelled) {
      statusColor = Colors.red;
      statusLabel = 'キャンセル';
    } else {
      statusColor = Colors.orange;
      statusLabel = '未完了';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1456A0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(order.orderNumber,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1456A0))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(timeStr,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    order.items
                        .map((i) => '${i.productName}×${i.quantity}')
                        .join('  '),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text('¥${order.totalAmount}',
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ]),
    );
  }
}
