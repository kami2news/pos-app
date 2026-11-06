import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/order_provider.dart';
import '../domain/models/order_model.dart';

/// 注文確認画面（製作スタッフ向け）
/// ─ 精算前 / お渡し待ち / 精算後 の3タブ構成
class OrderStatusScreen extends ConsumerStatefulWidget {
  const OrderStatusScreen({super.key});

  @override
  ConsumerState<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends ConsumerState<OrderStatusScreen>
    with SingleTickerProviderStateMixin {
  Timer? _syncTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    ref.read(orderListProvider.notifier).loadOrders();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.read(orderListProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderListProvider);
    final pending = orders.where((o) => o.isPending).toList().reversed.toList();
    final ready =
        orders.where((o) => o.isReadyForPickup).toList().reversed.toList();
    final completed =
        orders.where((o) => o.isCompleted).toList().reversed.toList();
    final cancelled =
        orders.where((o) => o.isCancelled).toList().reversed.toList();
    final totalSales = completed.fold(0, (s, o) => s + o.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('注文確認'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/orders'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: () =>
                ref.read(orderListProvider.notifier).loadOrders(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            _BadgeTab(
              label: '精算前',
              count: pending.length,
              color: _orangeColor,
            ),
            _BadgeTab(
              label: 'お渡し待ち',
              count: ready.length,
              color: _blueColor,
            ),
            _BadgeTab(
              label: '精算後',
              count: completed.length,
              color: _greenColor,
            ),
          ],
        ),
      ),

      body: Column(children: [
        // ─── サマリーバー ───
        _SummaryBar(
          pendingCount: pending.length,
          readyCount: ready.length,
          completedCount: completed.length,
          totalSales: totalSales,
        ),

        // ─── タブビュー ───
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── 精算前タブ ──
              _OrderTabView(
                orders: pending,
                emptyMessage: '精算前の注文はありません',
                emptyIcon: Icons.hourglass_empty,
                itemBuilder: (o) => _OrderCard(
                  order: o,
                  onCancelRequest: () => _showCancelDialog(o),
                ),
              ),

              // ── お渡し待ちタブ ──
              _OrderTabView(
                orders: ready,
                emptyMessage: 'お渡し待ちの注文はありません',
                emptyIcon: Icons.inventory_2_outlined,
                itemBuilder: (o) => _OrderCard(
                  order: o,
                  onHandoverComplete: () => ref
                      .read(orderListProvider.notifier)
                      .handoverOrder(o.id),
                ),
              ),

              // ── 精算後タブ ──
              _OrderTabView(
                orders: [...completed, ...cancelled],
                emptyMessage: '精算後の注文はありません',
                emptyIcon: Icons.check_circle_outline,
                itemBuilder: (o) => o.isCancelled
                    ? Opacity(opacity: 0.5, child: _OrderCard(order: o))
                    : _OrderCard(order: o),
              ),
            ],
          ),
        ),
      ]),

      // ─── FAB：注文受付へ ───
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/orders/register'),
        icon: const Icon(Icons.add_task),
        label: const Text('注文受付'),
      ),
    );
  }

  void _showCancelDialog(OrderModel order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('No.${order.orderNumber} をキャンセルしますか？'),
        content: Text(
            order.items.map((i) => '${i.productName}×${i.quantity}').join('、'),
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('戻る')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('キャンセルする'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(orderListProvider.notifier).cancelOrder(order.id);
    }
  }
}

// ─── タブラベル（バッジ付き） ─────────────────────────────────
class _BadgeTab extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _BadgeTab({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      );
}

// ─── タブ内リスト ────────────────────────────────────────────
class _OrderTabView extends StatelessWidget {
  final List<OrderModel> orders;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget Function(OrderModel) itemBuilder;

  const _OrderTabView({
    required this.orders,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) => orders.isEmpty
      ? Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(emptyIcon, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(emptyMessage,
                style: TextStyle(color: Colors.grey[400], fontSize: 15)),
          ]),
        )
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: orders.length,
          itemBuilder: (_, i) => itemBuilder(orders[i]),
        );
}

// ─── カラー定数 ──────────────────────────────────────────────
const _orangeColor = Color(0xFFF97316);
const _blueColor = Color(0xFF2563EB);
const _greenColor = Color(0xFF16A34A);

// ─── サマリーバー ────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final int pendingCount, readyCount, completedCount, totalSales;
  const _SummaryBar({
    required this.pendingCount,
    required this.readyCount,
    required this.completedCount,
    required this.totalSales,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF8F9FA),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          _Chip(
            label: '精算前',
            value: '$pendingCount件',
            color: pendingCount > 0 ? _orangeColor : Colors.grey,
          ),
          const SizedBox(width: 6),
          _Chip(
            label: 'お渡し待ち',
            value: '$readyCount件',
            color: readyCount > 0 ? _blueColor : Colors.grey,
          ),
          const SizedBox(width: 6),
          _Chip(
            label: '精算後',
            value: '$completedCount件',
            color: _greenColor,
          ),
          const SizedBox(width: 6),
          _Chip(label: '売上', value: '¥$totalSales'),
        ]),
      );
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _Chip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      );
}

// ─── 注文カード ──────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onHandoverComplete;
  const _OrderCard({
    required this.order,
    this.onCancelRequest,
    this.onHandoverComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = order.isPending;
    final isReady = order.isReadyForPickup;
    final borderColor = isPending
        ? _orangeColor
        : isReady
            ? _blueColor
            : _greenColor;
    final bgColor = isPending
        ? const Color(0xFFFFF7ED)
        : isReady
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFF0FDF4);

    final time = order.orderedAt;
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: borderColor, width: 5),
            top: BorderSide(color: borderColor.withValues(alpha: 0.25)),
            right: BorderSide(color: borderColor.withValues(alpha: 0.25)),
            bottom: BorderSide(color: borderColor.withValues(alpha: 0.25)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── ヘッダー行 ───
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.orderNumber,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Text(timeStr,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                Text('¥${order.totalAmount}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ]),

              const SizedBox(height: 10),

              // ─── 商品リスト ───
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: borderColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(item.productName,
                              style: const TextStyle(fontSize: 14))),
                      Text('× ${item.quantity}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ]),
                  )),

              // ─── 精算前：キャンセルボタン ───
              if (onCancelRequest != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onCancelRequest,
                      icon: const Icon(Icons.cancel_outlined,
                          size: 16, color: Colors.red),
                      label: const Text('キャンセル',
                          style: TextStyle(color: Colors.red, fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],

              // ─── お渡し待ち：お渡し完了ボタン ───
              if (onHandoverComplete != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (order.paymentMethod != null) ...[
                      Icon(
                        order.paymentMethod == PaymentMethod.cash
                            ? Icons.payments_outlined
                            : Icons.credit_card,
                        size: 13,
                        color: _blueColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.paymentMethod == PaymentMethod.cash
                            ? '現金支払済み'
                            : 'カード支払済み',
                        style:
                            const TextStyle(color: _blueColor, fontSize: 12),
                      ),
                    ],
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: onHandoverComplete,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('お渡し完了',
                          style: TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blueColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],

              // ─── 精算後：支払い方法表示 ───
              if (order.isCompleted && order.paymentMethod != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(
                    order.paymentMethod == PaymentMethod.cash
                        ? Icons.payments_outlined
                        : Icons.credit_card,
                    size: 14,
                    color: _greenColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.paymentMethod == PaymentMethod.cash
                        ? '現金精算済み'
                        : 'カード精算済み',
                    style: const TextStyle(color: _greenColor, fontSize: 12),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 空表示 ──────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('注文はまだありません',
              style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        ]),
      );
}
