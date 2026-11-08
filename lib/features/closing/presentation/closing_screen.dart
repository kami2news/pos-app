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
          .showSnackBar(const SnackBar(content: Text('実際のレジ内金を入力してください')));
      return;
    }
    if (_openingCashCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('開設金を入力してください')));
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.closeBusinessDay();
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? '締め処理に失敗しました（${e.message}）';
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg.toString())));
      setState(() => _loading = false);
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('エラー: $e')));
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
      builder: (ctx) => AlertDialog(
        title: const Text('締め完了レポート', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _ReportRow('注文件数', '${completedOrders.length}件'),
            _ReportRow(
                '販売総数',
                '${details.fold(0, (s, d) => s + d.quantity)}点',
                bold: true),
            if (discountSummary.autoDiscount > 0)
              _ReportRow('自動割引', '-¥${discountSummary.autoDiscount}',
                  color: Colors.orange[700]),
            if (discountSummary.manualDiscount > 0)
              _ReportRow('手動割引', '-¥${discountSummary.manualDiscount}',
                  color: Colors.red),
            const Divider(),
            _ReportRow('売上合計', '¥$totalAmount', bold: true, fontSize: 20),
            const Divider(),
            _ReportRow('開設金', '¥$openingCash'),
            _ReportRow('現金売上', '+¥$cashSalesTotal'),
            _ReportRow('理論締め金', '¥$theoreticalCash', bold: true),
            const Divider(),
            _ReportRow('実際のレジ内金', '¥${_cashCtrl.text}'),
            _ReportRow(
              cashDiff == 0 ? '差額（一致）' : (cashDiff > 0 ? '差額（過剰）' : '差額（不足）'),
              cashDiff == 0 ? '±¥0' : (cashDiff > 0 ? '+¥$cashDiff' : '-¥${cashDiff.abs()}'),
              bold: true,
              color: cashDiff == 0 ? Colors.green : (cashDiff > 0 ? Colors.orange[800] : Colors.red),
            ),
            const SizedBox(height: 16),

            if (details.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('商品別売上',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
              ),
              const SizedBox(height: 6),
              ...details.map((d) => _ProductDetailRow(d)),
            ],
          ]),
        ),
        actionsAlignment: MainAxisAlignment.center,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text('締め作業 - $storeName'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── 売上サマリー ───
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      const Text('本日の売上サマリー',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 16),
                      _ReportRow('注文件数', '${completedOrders.length}件'),
                      _ReportRow('販売総数', '$totalSold点', bold: true),
                      if (discountSummary.autoDiscount > 0) ...[
                        const SizedBox(height: 4),
                        _ReportRow(
                            '自動割引', '-¥${discountSummary.autoDiscount}',
                            color: Colors.orange[700]),
                      ],
                      if (discountSummary.manualDiscount > 0) ...[
                        const SizedBox(height: 4),
                        _ReportRow(
                            '手動割引', '-¥${discountSummary.manualDiscount}',
                            color: Colors.red),
                      ],
                      const Divider(),
                      _ReportRow('売上合計', '¥$totalAmount',
                          bold: true, fontSize: 22),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // ─── 商品別売上 ───
                if (details.isNotEmpty)
                  Card(
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text('商品別売上（合計$totalSold点）',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              // ヘッダー行
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  const Expanded(
                                      child: Text('商品',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey))),
                                  SizedBox(
                                      width: 70,
                                      child: Text('単価',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey))),
                                  SizedBox(
                                      width: 40,
                                      child: Text('数量',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey))),
                                  SizedBox(
                                      width: 70,
                                      child: Text('金額',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey))),
                                ]),
                              ),
                              const Divider(height: 8),
                              ...details.map((d) => _ProductDetailRow(d)),
                              const Divider(height: 8),
                              Row(children: [
                                const Expanded(
                                    child: Text('合計',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold))),
                                SizedBox(
                                    width: 70,
                                    child: Text('',
                                        textAlign: TextAlign.right)),
                                SizedBox(
                                    width: 40,
                                    child: Text('$totalSold',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold))),
                                SizedBox(
                                    width: 70,
                                    child: Text(
                                        '¥${details.fold(0, (s, d) => s + d.amount)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold))),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // ─── 開設金入力 ───
                Card(
                  color: _openingCashCtrl.text.isEmpty
                      ? Colors.orange.shade50
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('開設金（開始時のレジ内金）',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                            if (_openingCashCtrl.text.isEmpty) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange, size: 18),
                            ],
                          ]),
                          if (_openingCashCtrl.text.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('今日の開設時に入力した金額を入力してください',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.orange)),
                            ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _openingCashCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: '金額（円）',
                              prefixText: '¥',
                              border: const OutlineInputBorder(),
                              hintText: '例: 50000',
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _openingCashCtrl.text.isEmpty
                                      ? Colors.orange
                                      : Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ]),
                  ),
                ),
                const SizedBox(height: 12),

                // ─── レジ内金入力 ───
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('実際のレジ内金（締め時）',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cashCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                                labelText: '金額（円）',
                                prefixText: '¥',
                                border: OutlineInputBorder()),
                          ),
                        ]),
                  ),
                ),
                const SizedBox(height: 12);

                // ─── 理論締め金・差額 ───
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      const Text('レジ過不足チェック',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 14),
                      _ReportRow('開設金', '¥$openingCash'),
                      _ReportRow('現金売上', '+¥$cashSalesTotal'),
                      const Divider(),
                      _ReportRow('理論締め金', '¥$theoreticalCash', bold: true),
                      if (_cashCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _ReportRow('実際のレジ内金', '¥${_cashCtrl.text}'),
                        const Divider(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: cashDiff == 0
                                ? Colors.green.shade50
                                : (cashDiff > 0 ? Colors.orange.shade50 : Colors.red.shade50),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: cashDiff == 0
                                  ? Colors.green
                                  : (cashDiff > 0 ? Colors.orange : Colors.red),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cashDiff == 0 ? '差額（一致）' : (cashDiff > 0 ? '差額（過剰）' : '差額（不足）'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cashDiff == 0
                                      ? Colors.green[700]
                                      : (cashDiff > 0 ? Colors.orange[800] : Colors.red[700]),
                                ),
                              ),
                              Text(
                                cashDiff == 0
                                    ? '±¥0'
                                    : (cashDiff > 0 ? '+¥$cashDiff' : '-¥${cashDiff.abs()}'),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: cashDiff == 0
                                      ? Colors.green[700]
                                      : (cashDiff > 0 ? Colors.orange[800] : Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _loading ? null : _close,
                  icon: const Icon(Icons.lock),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('締める', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 商品別売上行 ────────────────────────────────────────────
class _ProductDetailRow extends StatelessWidget {
  final ProductSaleDetail detail;
  const _ProductDetailRow(this.detail);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(detail.name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                if (detail.discountPerItem > 0)
                  Text('${detail.discountPerItem}円引き',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
              ],
            ),
          ),
          SizedBox(
              width: 70,
              child: Text('¥${detail.unitPrice}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      color: detail.discountPerItem > 0
                          ? Colors.red
                          : Colors.grey))),
          SizedBox(
              width: 40,
              child: Text('${detail.quantity}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13))),
          SizedBox(
              width: 70,
              child: Text('¥${detail.amount}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );
}

// ─── サマリー行 ──────────────────────────────────────────────
class _ReportRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final double fontSize;
  final Color? color;
  const _ReportRow(this.label, this.value,
      {this.bold = false, this.fontSize = 14, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: Colors.grey)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ]),
      );
}
