import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/order_provider.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    // 画面を開いたら即時取得 + 5秒ごとに同期
    ref.read(orderListProvider.notifier).loadOrders();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.read(orderListProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderListProvider);
    final productSales = ref.watch(productSalesProvider);
    final totalSold = ref.watch(totalSoldProvider);
    final totalAmount = orders.fold(0, (s, o) => s + o.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('注文一覧'),
        backgroundColor: const Color(0xFF1456A0),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: Column(
        children: [
          // ─── 本日のサマリー ───
          Container(
            color: const Color(0xFFF0F4FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              _SummaryChip(label: '注文件数', value: '${orders.length}件'),
              const SizedBox(width: 12),
              _SummaryChip(label: '販売総数', value: '$totalSold点'),
              const SizedBox(width: 12),
              _SummaryChip(label: '売上合計', value: '¥$totalAmount'),
            ]),
          ),

          // ─── 商品別販売数 ───
          if (productSales.isNotEmpty)
            ExpansionTile(
              dense: true,
              title: const Text('商品別販売数',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: (productSales.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .map((e) => Chip(
                              label: Text('${e.key}  ${e.value}点',
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor: const Color(0xFFE3F0FC),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),

          const Divider(height: 1),

          // ─── 注文リスト ───
          Expanded(
            child: orders.isEmpty
                ? const Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('まだ注文がありません',
                            style: TextStyle(color: Colors.grey)),
                      ]))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final order = orders[orders.length - 1 - i];
                      final time = order.orderedAt;
                      return Card(
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1456A0),
                            child: Text(order.orderNumber,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text('整理番号 ${order.orderNumber}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${time.hour.toString().padLeft(2, '0')}:'
                            '${time.minute.toString().padLeft(2, '0')}'
                            '　合計 ¥${order.totalAmount}'
                            '${order.discountAmount > 0 ? '（割引 -¥${order.discountAmount}）' : ''}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.print_outlined, size: 20),
                              tooltip: '再印字',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                        'No.${order.orderNumber} を再印字（印刷機能は保留中）')));
                              },
                            ),
                          ]),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...order.items.map((item) => Row(children: [
                                        Expanded(child: Text(item.productName)),
                                        Text('× ${item.quantity}',
                                            style: const TextStyle(
                                                color: Colors.grey)),
                                        const SizedBox(width: 12),
                                        Text('¥${item.subtotal}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500)),
                                      ])),
                                  if (order.discountAmount > 0) ...[
                                    const Divider(),
                                    Row(children: [
                                      const Text('小計'),
                                      const Spacer(),
                                      Text('¥${order.subtotal}'),
                                    ]),
                                    Row(children: [
                                      const Text('割引',
                                          style: TextStyle(color: Colors.red)),
                                      const Spacer(),
                                      Text('-¥${order.discountAmount}',
                                          style: const TextStyle(
                                              color: Colors.red)),
                                    ]),
                                  ],
                                  const Divider(),
                                  Row(children: [
                                    const Text('合計',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Text('¥${order.totalAmount}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD0DCF0)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}
