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
      // PATCH /api/business-days/close
      final api = ref.read(apiServiceProvider);
      await api.closeBusinessDay();
    } on DioException catch (e) {
      final msg =
          e.response?.data?['error'] ?? '締め処理に失敗しました（${e.message}）';
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
    final productSales = ref.read(productSalesProvider);
    final totalSold = ref.read(totalSoldProvider);
    final completedOrders = orders.where((o) => o.isCompleted).toList();
    final totalAmount = completedOrders.fold(0, (s, o) => s + o.totalAmount);
    final totalDiscount = completedOrders.fold(0, (s, o) => s + o.discountAmount);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('締め完了レポート', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 売上サマリー
            _ReportRow('注文件数', '${orders.length}件'),
            _ReportRow('販売総数', '$totalSold点', bold: true),
            _ReportRow('割引合計', '-¥$totalDiscount',
                color: totalDiscount > 0 ? Colors.red : null),
            const Divider(),
            _ReportRow('売上合計', '¥$totalAmount', bold: true, fontSize: 20),
            _ReportRow('レジ内金（締め）', '¥${_cashCtrl.text}'),
            const SizedBox(height: 16),

            // 商品別販売数
            if (productSales.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('商品別販売数',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
              ),
              const SizedBox(height: 6),
              ...(productSales.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .map((e) => _ReportRow(e.key, '${e.value}点')),
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
    final totalDiscount = completedOrders.fold(0, (s, o) => s + o.discountAmount);
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
                // 売上サマリー
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      const Text('本日の売上サマリー',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 16),
                      _ReportRow('注文件数', '${orders.length}件'),
                      _ReportRow('販売総数', '$totalSold点', bold: true),
                      if (totalDiscount > 0)
                        _ReportRow('割引合計', '-¥$totalDiscount',
                            color: Colors.red),
                      const Divider(),
                      _ReportRow('売上合計', '¥$totalAmount',
                          bold: true, fontSize: 22),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // 商品別販売数
                if (totalSold > 0)
                  Card(
                    child: ExpansionTile(
                      title: Text('商品別販売数（合計$totalSold点）',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: (ref
                                    .watch(productSalesProvider)
                                    .entries
                                    .toList()
                                  ..sort((a, b) => b.value.compareTo(a.value)))
                                .map((e) => _ReportRow(e.key, '${e.value}点'))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // レジ内金入力
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
