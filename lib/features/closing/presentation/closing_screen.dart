import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../order/domain/order_provider.dart';
import '../../../core/network/api_service.dart';

class ClosingScreen extends ConsumerStatefulWidget {
  const ClosingScreen({super.key});
  @override
  ConsumerState<ClosingScreen> createState() => _ClosingScreenState();
}

class _ClosingScreenState extends ConsumerState<ClosingScreen> {
  final _cashCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_cashCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('レジ内金を入力してください')));
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
    await _showClosingReport();
  }

  Future<void> _showClosingReport() async {
    final orders = ref.read(orderListProvider);
    final completedOrders = orders.where((o) => o.isCompleted).toList();
    final totalAmount = completedOrders.fold(0, (s, o) => s + o.totalAmount);
    final discountSummary = ref.read(discountSummaryProvider);
    final details = ref.read(productSaleDetailsProvider);
    final manualEntries = ref.read(manualDiscountEntriesProvider);

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
            if (manualEntries.isNotEmpty)
              _ReportRow('手動割引', '-¥${discountSummary.manualDiscount}',
                  color: Colors.red),
            const Divider(),
            _ReportRow('売上合計', '¥$totalAmount', bold: true, fontSize: 20),
            _ReportRow('レジ内金（締め）', '¥${_cashCtrl.text}'),
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
            if (manualEntries.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('手動割引の内訳',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
              ),
              const SizedBox(height: 6),
              ...manualEntries.map((e) => _ManualDiscountRow(e)),
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
    final discountSummary = ref.watch(discountSummaryProvider);
    final details = ref.watch(productSaleDetailsProvider);
    final manualEntries = ref.watch(manualDiscountEntriesProvider);
    final storeName = ref.watch(authStateProvider).storeName ?? '';

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
                      if (manualEntries.isNotEmpty) ...[
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

                // ─── 手動割引内訳 ───
                if (manualEntries.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('手動割引の内訳',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 10),
                          ...manualEntries.map((e) => _ManualDiscountRow(e)),
                        ],
                      ),
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
                          const Text('レジ内金（締め時）',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cashCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: '金額（円）',
                                prefixText: '¥',
                                border: OutlineInputBorder()),
                          ),
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
              child: Text(detail.name,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          SizedBox(
              width: 70,
              child: Text('¥${detail.unitPrice}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, color: Colors.grey))),
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

// ─── 手動割引行（商品名 + n円引き赤字）────────────────────────
class _ManualDiscountRow extends StatelessWidget {
  final ManualDiscountEntry entry;
  const _ManualDiscountRow(this.entry);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(entry.itemsLabel,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text('${entry.amount}円引き',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
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
