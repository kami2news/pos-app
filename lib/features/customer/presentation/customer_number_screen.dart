import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/km1.dart';

/// 注文者モード：整理番号ページ
/// 注文確定後 → /customer/:storeCode/number/:orderId
/// 5秒ごとにステータスをポーリングする
class CustomerNumberScreen extends StatefulWidget {
  final String storeCode;
  final String orderId;

  const CustomerNumberScreen({
    super.key,
    required this.storeCode,
    required this.orderId,
  });

  @override
  State<CustomerNumberScreen> createState() => _CustomerNumberScreenState();
}

class _CustomerNumberScreenState extends State<CustomerNumberScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _order;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchOrder();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchOrder());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrder() async {
    try {
      final data = await ApiService().getPublicOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = data;
        _loading = false;
        _error = null;
      });
      // 完了 or キャンセル → ポーリング停止
      final status = data['status'] as String? ?? '';
      if (status == 'completed' || status == 'cancelled') {
        _timer?.cancel();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error ??= '状態を確認しています';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('整理番号'),
        automaticallyImplyLeading: false,
        actions: [
          Km1BarAction(
            icon: Km1Icons.back,
            label: '注文画面に戻る',
            onPressed: () => context.go('/customer/${widget.storeCode}'),
          ),
          const SizedBox(width: Km1Space.xs),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_order == null) {
      return Km1Empty(
        icon: Km1Icons.offline,
        title: '注文の情報を取得できませんでした',
        body: '通信状態を確認して、もう一度お試しください。',
        action: FilledButton.icon(
          onPressed: () {
            setState(() => _loading = true);
            _fetchOrder();
          },
          icon: const Icon(Km1Icons.refresh, size: Km1Size.iconMd),
          label: const Text('もう一度読み込む'),
        ),
      );
    }

    final order = _order!;
    final orderNumber = order['order_number'] as String? ?? '---';
    final status = order['status'] as String? ?? 'pending';
    final items =
        List<Map<String, dynamic>>.from(order['items'] as List? ?? []);
    final totalAmount = order['total_amount'] as int? ?? 0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Km1Size.dialogWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Km1Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 整理番号 ──
              _NumberCard(orderNumber: orderNumber),
              const SizedBox(height: Km1Space.lg),

              // ── 状態 ──
              _StatusCard(status: status),
              const SizedBox(height: Km1Space.lg),

              // ── 注文内容 ──
              _OrderItemsCard(items: items, totalAmount: totalAmount),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 整理番号カード ───────────────────────────────────────────
class _NumberCard extends StatelessWidget {
  final String orderNumber;

  const _NumberCard({required this.orderNumber});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    return Container(
      decoration: km1CardDecoration(context),
      padding: const EdgeInsets.symmetric(
          vertical: Km1Space.xxl, horizontal: Km1Space.xxl),
      child: Column(
        children: [
          Text('整理番号',
              style: Km1Text.subtitle2.copyWith(color: c.inkSecondary)),
          Text(orderNumber,
              style: Km1Text.display.copyWith(color: c.brandInk)),
          Text('この番号でお呼びします',
              style: Km1Text.body1.copyWith(color: c.inkSecondary)),
        ],
      ),
    );
  }
}

// ─── 状態カード（色 + アイコン + 文言） ──────────────────────
class _StatusCard extends StatelessWidget {
  final String status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final (Color ink, Color tint, IconData icon, String label, String body) =
        switch (status) {
      'pending' => (
          c.warningInk,
          c.warningTint,
          Km1Icons.waiting,
          '準備しています',
          '店舗のスタッフが準備しています。番号をお呼びするまでお待ちください。'
        ),
      'readyForPickup' => (
          c.successInk,
          c.successTint,
          Km1Icons.notify,
          'お呼び出し中です',
          '受け取りカウンターにお越しください。'
        ),
      'completed' => (
          c.inkTertiary,
          c.surfaceMuted,
          Km1Icons.checkCircle,
          'お渡ししました',
          'ありがとうございました。'
        ),
      'cancelled' => (
          c.dangerInk,
          c.dangerTint,
          Km1Icons.dismissCircle,
          'この注文は取り消されました',
          '店舗のスタッフにお問い合わせください。'
        ),
      _ => (
          c.inkTertiary,
          c.surfaceMuted,
          Km1Icons.sync,
          '確認しています',
          '注文の状態を取得しています。'
        ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Km1Space.lg),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(Km1Radius.lg),
          border: Border.all(color: ink),
        ),
        child: Row(
          children: [
            Icon(icon, color: ink, size: Km1Size.iconLg),
            const SizedBox(width: Km1Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: Km1Text.subtitle1.copyWith(color: c.ink)),
                  const SizedBox(height: Km1Space.xxs),
                  Text(body, style: Km1Text.body1.copyWith(color: c.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 注文内容カード ──────────────────────────────────────────
class _OrderItemsCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int totalAmount;

  const _OrderItemsCard({
    required this.items,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    const tabular = [FontFeature.tabularFigures()];
    return Container(
      decoration: km1CardDecoration(context),
      padding: const EdgeInsets.all(Km1Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('注文内容', style: Km1Text.subtitle2.copyWith(color: c.ink)),
          const SizedBox(height: Km1Space.sm),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: Km1Space.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item['product_name'] as String? ?? '',
                          style: Km1Text.body2.copyWith(color: c.ink)),
                    ),
                    Text('× ${item['quantity']}',
                        style: Km1Text.body2.copyWith(color: c.inkSecondary)),
                    const SizedBox(width: Km1Space.md),
                    Text(
                        '¥${(item['unit_price'] as int? ?? 0) * (item['quantity'] as int? ?? 1)}',
                        style: Km1Text.body2
                            .copyWith(color: c.ink, fontFeatures: tabular)),
                  ],
                ),
              )),
          Divider(height: Km1Space.lg, color: c.strokeSubtle),
          Row(
            children: [
              Expanded(
                  child: Text('合計',
                      style: Km1Text.subtitle2.copyWith(color: c.ink))),
              Text('¥$totalAmount',
                  style: Km1Text.title3
                      .copyWith(color: c.ink, fontFeatures: tabular)),
            ],
          ),
        ],
      ),
    );
  }
}
