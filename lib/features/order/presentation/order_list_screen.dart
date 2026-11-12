import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/order_provider.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../../core/theme/km1.dart';

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
    final c = context.km1;
    final orders = ref.watch(orderListProvider);
    final productSales = ref.watch(productSalesProvider);
    final totalSold = ref.watch(totalSoldProvider);
    final storeColor = ref.watch(authStateProvider.select((s) => s.themeColor));
    final totalAmount = orders
        .where((o) => o.isCompleted)
        .fold(0, (s, o) => s + o.totalAmount);

    Widget amountRow(String label, String value,
            {Color? color, bool strong = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Km1Space.xxs),
          child: Row(children: [
            Text(label,
                style: (strong ? Km1Text.body1Strong : Km1Text.body1)
                    .copyWith(color: color ?? c.ink)),
            const Spacer(),
            Text(value,
                style: (strong ? Km1Text.body1Strong : Km1Text.body1)
                    .copyWith(
                        color: color ?? c.ink,
                        fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('注文一覧'),
        bottom: storeBand(storeColor),
        leading: IconButton(
          icon: const Icon(Km1Icons.back),
          tooltip: '戻る',
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: Column(
        children: [
          // ─── 本日のサマリー ───
          Container(
            color: c.surface,
            padding: const EdgeInsets.all(Km1Space.lg),
            child: Row(children: [
              _SummaryChip(label: '注文件数', value: '${orders.length} 件'),
              const SizedBox(width: Km1Space.sm),
              _SummaryChip(label: '販売総数', value: '$totalSold 点'),
              const SizedBox(width: Km1Space.sm),
              _SummaryChip(label: '売上合計', value: '¥$totalAmount'),
            ]),
          ),

          // ─── 商品別販売数 ───
          if (productSales.isNotEmpty)
            Container(
              color: c.surface,
              child: ExpansionTile(
                dense: true,
                title: Text('商品別販売数',
                    style: Km1Text.body1Strong.copyWith(color: c.ink)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Km1Space.lg, 0, Km1Space.lg, Km1Space.md),
                    child: Wrap(
                      spacing: Km1Space.sm,
                      runSpacing: Km1Space.sm,
                      children: (productSales.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value)))
                          .map((e) => Chip(
                                label: Text('${e.key}　${e.value} 点'),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),

          Divider(height: 1, color: c.strokeSubtle),

          // ─── 注文リスト ───
          Expanded(
            child: orders.isEmpty
                ? const Km1Empty(
                    icon: Km1Icons.order,
                    title: 'まだ注文がありません',
                    body: '注文が入ると、ここに新しい順に表示されます。',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(Km1Space.lg),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Km1Space.sm),
                    itemBuilder: (_, i) {
                      final order = orders[orders.length - 1 - i];
                      return Container(
                        decoration: km1CardDecoration(context),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          leading: Container(
                            constraints: const BoxConstraints(minWidth: 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: Km1Space.sm,
                                vertical: Km1Space.xs),
                            decoration: BoxDecoration(
                              color: c.brandTint,
                              borderRadius:
                                  BorderRadius.circular(Km1Radius.md),
                            ),
                            child: Text(order.orderNumber,
                                textAlign: TextAlign.center,
                                style: Km1Text.body1Strong
                                    .copyWith(color: c.brandInk)),
                          ),
                          title: Text('整理番号 ${order.orderNumber}',
                              style:
                                  Km1Text.body1Strong.copyWith(color: c.ink)),
                          subtitle: Text(
                            '${km1Time(order.orderedAt)}　合計 ¥${order.totalAmount}'
                            '${order.discountAmount > 0 ? '（割引 -¥${order.discountAmount}）' : ''}',
                            style: Km1Text.caption1
                                .copyWith(color: c.inkSecondary),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Km1Icons.print),
                              tooltip: '再印字',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            '整理番号 ${order.orderNumber} の再印字は、プリンターの対応後に使えます。')));
                              },
                            ),
                          ]),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  Km1Space.lg, 0, Km1Space.lg, Km1Space.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...order.items.map((item) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: Km1Space.xxs),
                                        child: Row(children: [
                                          Expanded(
                                              child: Text(item.productName,
                                                  style: Km1Text.body1
                                                      .copyWith(
                                                          color: c.ink))),
                                          Text('× ${item.quantity}',
                                              style: Km1Text.body1.copyWith(
                                                  color: c.inkSecondary)),
                                          const SizedBox(width: Km1Space.md),
                                          Text('¥${item.subtotal}',
                                              style: Km1Text.body1
                                                  .copyWith(color: c.ink)),
                                        ]),
                                      )),
                                  if (order.discountAmount > 0) ...[
                                    Divider(color: c.strokeSubtle),
                                    amountRow('小計', '¥${order.subtotal}'),
                                    amountRow(
                                        '割引', '-¥${order.discountAmount}',
                                        color: c.dangerInk),
                                  ],
                                  Divider(color: c.strokeSubtle),
                                  amountRow('合計', '¥${order.totalAmount}',
                                      strong: true),
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
  Widget build(BuildContext context) {
    final c = context.km1;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: Km1Space.sm, horizontal: Km1Space.md),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(Km1Radius.lg),
          border: Border.all(color: c.strokeSubtle),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Km1Text.caption1.copyWith(color: c.inkSecondary)),
          const SizedBox(height: Km1Space.xxs),
          Text(value, style: Km1Text.subtitle2.copyWith(color: c.ink)),
        ]),
      ),
    );
  }
}
