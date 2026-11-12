import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/order_provider.dart';
import '../domain/models/order_model.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../../core/theme/km1.dart';

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
    final c = context.km1;
    final orders = ref.watch(orderListProvider);
    final storeColor = ref.watch(authStateProvider.select((s) => s.themeColor));
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
        title: const Text('注文状況'),
        bottom: storeBand(storeColor),
        leading: IconButton(
          icon: const Icon(Km1Icons.back),
          tooltip: '戻る',
          onPressed: () => context.go('/orders'),
        ),
        actions: [
          // 主な追加操作は上部バーに置く（FAB は使わない）
          Km1BarAction(
            icon: Km1Icons.add,
            label: '注文受付',
            onPressed: () => context.go('/orders/register'),
          ),
          IconButton(
            icon: const Icon(Km1Icons.refresh),
            tooltip: '最新の状態に更新',
            onPressed: () =>
                ref.read(orderListProvider.notifier).loadOrders(),
          ),
          const SizedBox(width: Km1Space.xs),
        ],
      ),
      body: Column(children: [
        // ─── サマリーバー ───
        _SummaryBar(
          pendingCount: pending.length,
          readyCount: ready.length,
          completedCount: completed.length,
          totalSales: totalSales,
        ),

        // ─── タブ（同じ画面の表示の切り替え）───
        Material(
          color: c.surface,
          child: TabBar(
            controller: _tabController,
            tabs: [
              _BadgeTab(label: '精算前', count: pending.length),
              _BadgeTab(label: 'お渡し待ち', count: ready.length),
              _BadgeTab(label: '精算後', count: completed.length),
            ],
          ),
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
                emptyIcon: Km1Icons.waiting,
                itemBuilder: (o) => _OrderCard(
                  order: o,
                  onCancelRequest: () => _showCancelDialog(o),
                ),
              ),

              // ── お渡し待ちタブ ──
              _OrderTabView(
                orders: ready,
                emptyMessage: 'お渡し待ちの注文はありません',
                emptyIcon: Km1Icons.product,
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
                emptyIcon: Km1Icons.checkCircle,
                itemBuilder: (o) => _OrderCard(order: o),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  void _showCancelDialog(OrderModel order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('整理番号 ${order.orderNumber} の注文を取り消しますか'),
        content: Text(
            '${order.items.map((i) => '${i.productName} × ${i.quantity}').join('、')}\n'
            '取り消した注文は元に戻せません。'),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('戻る')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: km1DangerButton(ctx),
            child: const Text('注文を取り消す'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(orderListProvider.notifier).cancelOrder(order.id);
    }
  }
}

// ─── タブラベル（件数付き） ─────────────────────────────────
class _BadgeTab extends StatelessWidget {
  final String label;
  final int count;
  const _BadgeTab({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    return Tab(
      height: context.km1Target,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: Km1Space.smNudge),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Km1Space.smNudge),
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                borderRadius: BorderRadius.circular(Km1Radius.circular),
              ),
              child: Text('$count',
                  style: Km1Text.caption1
                      .copyWith(color: c.ink, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
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
      ? Km1Empty(icon: emptyIcon, title: emptyMessage)
      : ListView.separated(
          padding: const EdgeInsets.all(Km1Space.lg),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: Km1Space.sm),
          itemBuilder: (_, i) => itemBuilder(orders[i]),
        );
}

// ─── 注文の状態（色 + アイコン + 文言で示す） ─────────────────
class _StatusBadge extends StatelessWidget {
  final OrderModel order;
  const _StatusBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final (Color ink, Color tint, IconData icon, String word) = order.isPending
        ? (c.warningInk, c.warningTint, Km1Icons.waiting, '精算前')
        : order.isReadyForPickup
            ? (c.infoInk, c.infoTint, Km1Icons.product, 'お渡し待ち')
            : order.isCancelled
                ? (c.inkTertiary, c.surfaceMuted, Km1Icons.dismissCircle, '取り消し済み')
                : (c.successInk, c.successTint, Km1Icons.checkCircle, '精算済み');
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Km1Space.sm, vertical: Km1Space.xxs),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: ink),
        borderRadius: BorderRadius.circular(Km1Radius.md),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: Km1Size.iconSm, color: ink),
        const SizedBox(width: Km1Space.xs),
        Text(word, style: Km1Text.caption1.copyWith(color: c.ink)),
      ]),
    );
  }
}

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
        color: context.km1.surface,
        padding: const EdgeInsets.fromLTRB(
            Km1Space.lg, Km1Space.md, Km1Space.lg, Km1Space.xs),
        child: Row(children: [
          _Chip(label: '精算前', value: '$pendingCount 件'),
          const SizedBox(width: Km1Space.sm),
          _Chip(label: 'お渡し待ち', value: '$readyCount 件'),
          const SizedBox(width: Km1Space.sm),
          _Chip(label: '精算後', value: '$completedCount 件'),
          const SizedBox(width: Km1Space.sm),
          _Chip(label: '売上', value: '¥$totalSales'),
        ]),
      );
}

class _Chip extends StatelessWidget {
  final String label, value;
  const _Chip({required this.label, required this.value});

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
          Text(label,
              style: Km1Text.caption1.copyWith(color: c.inkSecondary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: Km1Space.xxs),
          Text(value,
              style: Km1Text.subtitle2.copyWith(color: c.ink),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
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
    final c = context.km1;
    final muted = order.isCancelled;
    final ink = muted ? c.inkTertiary : c.ink;
    final payText = order.paymentMethod == null
        ? null
        : order.paymentMethod == PaymentMethod.cash
            ? '現金'
            : 'カード';

    return Container(
      decoration: km1CardDecoration(context),
      padding: const EdgeInsets.all(Km1Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── ヘッダー行 ───
          Row(children: [
            Text(order.orderNumber,
                style: Km1Text.title3.copyWith(color: ink)),
            const SizedBox(width: Km1Space.md),
            _StatusBadge(order: order),
            const SizedBox(width: Km1Space.sm),
            Text(km1Time(order.orderedAt),
                style: Km1Text.body1.copyWith(color: c.inkSecondary)),
            const Spacer(),
            Text('¥${order.totalAmount}',
                style: Km1Text.subtitle2.copyWith(
                    color: ink,
                    decoration: muted ? TextDecoration.lineThrough : null)),
          ]),

          const SizedBox(height: Km1Space.sm),

          // ─── 商品リスト ───
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: Km1Space.xxs),
                child: Row(children: [
                  Expanded(
                      child: Text(item.productName,
                          style: Km1Text.body2.copyWith(color: ink))),
                  Text('× ${item.quantity}',
                      style: Km1Text.subtitle2.copyWith(color: ink)),
                ]),
              )),

          if (payText != null && !muted) ...[
            const SizedBox(height: Km1Space.xs),
            Text('$payText で支払い済み',
                style: Km1Text.caption1.copyWith(color: c.inkSecondary)),
          ],

          // ─── 精算前：取り消し ───
          if (onCancelRequest != null) ...[
            const SizedBox(height: Km1Space.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancelRequest,
                style: TextButton.styleFrom(foregroundColor: c.dangerInk),
                icon: const Icon(Km1Icons.dismissCircle, size: Km1Size.iconMd),
                label: const Text('注文を取り消す'),
              ),
            ),
          ],

          // ─── お渡し待ち：お渡し完了 ───
          if (onHandoverComplete != null) ...[
            const SizedBox(height: Km1Space.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onHandoverComplete,
                icon: const Icon(Km1Icons.check, size: Km1Size.iconMd),
                label: const Text('お渡し完了'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
