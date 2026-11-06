import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../products/domain/products_provider.dart';
import '../domain/order_provider.dart';

/// レジ画面（スタッフ操作 / Flow 2：登録〜精算まで一括）
/// ─ 注文確定 → pending 登録 → すぐに精算画面へ遷移
/// ─ AppBar の「精算待ち」バッジから Flow 1 のお客様注文も処理可能
class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    // 5秒ごとに注文リストを再取得してリアルタイム同期
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.read(orderListProvider.notifier).loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productListProvider);
    final cartItems = ref.watch(currentOrderProvider);
    final manualDiscount = ref.watch(manualDiscountProvider);
    final autoResult = ref.watch(autoDiscountProvider);
    final storeName = ref.watch(authStateProvider).storeName ?? '';
    final pendingCount = ref.watch(pendingCountProvider);
    final subtotal = ref.read(currentOrderProvider.notifier).subtotal;
    final totalDiscount =
        min(subtotal, autoResult.totalDiscount + manualDiscount);
    final finalTotal = max(0, subtotal - totalDiscount);

    return Scaffold(
      appBar: AppBar(
        title: Text('注文入力 - $storeName'),
        actions: [
          // ─── 注文者QRコード ───
          IconButton(
            onPressed: () => _showQrDialog(context, storeName),
            icon: const Icon(Icons.qr_code, color: Colors.white),
            tooltip: 'お客様注文QR',
          ),
          // ─── 精算待ちバッジ（Flow 1：お客様自己注文の精算）───
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => _showPendingOrdersSheet(context, ref),
                icon: const Icon(Icons.pending_actions, color: Colors.white),
                tooltip: '精算待ち一覧',
              ),
              if (pendingCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // ─── お客様受付画面へ ───
          IconButton(
            onPressed: () => context.go('/orders/register'),
            icon: const Icon(Icons.tablet_android, color: Colors.white),
            tooltip: 'お客様受付画面',
          ),
          IconButton(
            onPressed: () => context.go('/orders/list'),
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: '注文一覧',
          ),
          IconButton(
            onPressed: () => context.go('/discount-rules'),
            icon: const Icon(Icons.local_offer, color: Colors.white),
            tooltip: 'セット割',
          ),
          IconButton(
            onPressed: () => context.go('/products'),
            icon: const Icon(Icons.inventory, color: Colors.white),
            tooltip: '商品管理',
          ),
          IconButton(
            onPressed: () => context.go('/closing'),
            icon: const Icon(Icons.lock, color: Colors.white),
            tooltip: '締め',
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── セット割の適用バナー ───
          if (autoResult.applied.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFE6F4ED),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: autoResult.applied
                    .map((a) => Chip(
                          avatar: const Icon(Icons.check_circle,
                              size: 14, color: Color(0xFF085041)),
                          label: Text('${a.rule.name}  -¥${a.amount}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF085041))),
                          backgroundColor: const Color(0xFFC8EDD9),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),

          // ─── 商品グリッド ───
          Expanded(
            flex: 3,
            child: products.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('商品がありません',
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/products'),
                          child: const Text('商品を追加する'),
                        ),
                      ]))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];
                      final inCart = cartItems
                          .where((c) => c.productId == p.id)
                          .fold(0, (s, c) => s + c.quantity);
                      return GestureDetector(
                        onTap: () => ref
                            .read(currentOrderProvider.notifier)
                            .addProduct(
                                productId: p.id,
                                productName: p.name,
                                unitPrice: p.price),
                        child: Card(
                          color: inCart > 0 ? const Color(0xFFE3F0FC) : null,
                          child: Stack(children: [
                            Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(p.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                        textAlign: TextAlign.center),
                                    const SizedBox(height: 4),
                                    Text('¥${p.price}',
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 13)),
                                  ]),
                            ),
                            if (inCart > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: const Color(0xFF1456A0),
                                  child: Text('$inCart',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ),
                              ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // ─── カート＋合計 ───
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cartItems.isNotEmpty)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      children: cartItems
                          .map((item) => Row(children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.productName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      size: 20),
                                  onPressed: () => ref
                                      .read(currentOrderProvider.notifier)
                                      .decreaseProduct(item.productId),
                                ),
                                Text('${item.quantity}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      size: 20),
                                  onPressed: () => ref
                                      .read(currentOrderProvider.notifier)
                                      .addProduct(
                                          productId: item.productId,
                                          productName: item.productName,
                                          unitPrice: item.unitPrice),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '¥${item.subtotal}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ]))
                          .toList(),
                    ),
                  ),

                // 小計・割引の内訳
                if (totalDiscount > 0)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(children: [
                      Row(children: [
                        const Text('小計',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const Spacer(),
                        Text('¥$subtotal',
                            style: const TextStyle(fontSize: 13)),
                      ]),
                      if (autoResult.totalDiscount > 0)
                        Row(children: [
                          const Icon(Icons.local_offer,
                              size: 12, color: Color(0xFF085041)),
                          const SizedBox(width: 4),
                          const Text('セット割',
                              style: TextStyle(
                                  color: Color(0xFF085041), fontSize: 13)),
                          const Spacer(),
                          Text('-¥${autoResult.totalDiscount}',
                              style: const TextStyle(
                                  color: Color(0xFF085041), fontSize: 13)),
                        ]),
                      if (manualDiscount > 0)
                        Row(children: [
                          const Text('手動割引',
                              style:
                                  TextStyle(color: Colors.red, fontSize: 13)),
                          const Spacer(),
                          Text('-¥$manualDiscount',
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => ref
                                .read(manualDiscountProvider.notifier)
                                .state = 0,
                            child: const Icon(Icons.cancel,
                                size: 15, color: Colors.red),
                          ),
                        ]),
                      const Divider(height: 8),
                    ]),
                  ),

                // 合計行 + ボタン
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 合計（左固定）
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('合計',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Text('¥$finalTotal',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                          ]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OverflowBar(
                          alignment: MainAxisAlignment.end,
                          spacing: 6,
                          overflowSpacing: 6,
                          overflowAlignment: OverflowBarAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: cartItems.isEmpty
                                  ? null
                                  : () => _showManualDiscountDialog(
                                      context, ref, subtotal),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    manualDiscount > 0 ? Colors.red : null,
                                side: manualDiscount > 0
                                    ? const BorderSide(color: Colors.red)
                                    : null,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                              child:
                                  Text(manualDiscount > 0 ? '手動割引中' : '手動割引'),
                            ),
                            if (cartItems.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(currentOrderProvider.notifier)
                                      .clear();
                                  ref
                                      .read(manualDiscountProvider.notifier)
                                      .state = 0;
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                ),
                                child: const Text('クリア',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            FilledButton.icon(
                              onPressed: cartItems.isEmpty
                                  ? null
                                  : () => _confirmOrder(
                                      context,
                                      ref,
                                      subtotal,
                                      autoResult.totalDiscount,
                                      manualDiscount,
                                      finalTotal),
                              icon: const Icon(Icons.point_of_sale, size: 16),
                              label: const Text('注文確定・精算へ'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1456A0),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── お客様注文QRコードダイアログ ───
  void _showQrDialog(BuildContext context, String storeName) {
    final encoded = Uri.encodeComponent(storeName);
    const baseUrl = 'https://kami2pos-app.web.app';
    final url = '$baseUrl/customer/$encoded';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('お客様注文QRコード',
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: url,
              version: QrVersions.auto,
              size: 220,
            ),
            const SizedBox(height: 12),
            const Text('お客様のスマホで読み取ってください',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('URLをコピーしました'),
                        duration: Duration(seconds: 2)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(url,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('閉じる'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  // ─── 精算待ちボトムシート（Flow 1：お客様自己注文の精算）───
  void _showPendingOrdersSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PendingOrdersSheet(),
    );
  }

  void _showManualDiscountDialog(
      BuildContext context, WidgetRef ref, int subtotal) {
    final ctrl = TextEditingController();
    bool isPercent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('手動割引を設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                ChoiceChip(
                  label: const Text('金額（円）'),
                  selected: !isPercent,
                  onSelected: (_) => setState(() => isPercent = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('割合（%）'),
                  selected: isPercent,
                  onSelected: (_) => setState(() => isPercent = true),
                ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isPercent ? '割引率（例: 10）' : '割引額（例: 500）',
                  prefixText: isPercent ? null : '¥',
                  suffixText: isPercent ? '%' : null,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(manualDiscountProvider.notifier).state = 0;
                Navigator.of(ctx).pop();
              },
              child: const Text('割引なし', style: TextStyle(color: Colors.red)),
            ),
            FilledButton(
              onPressed: () {
                final v = int.tryParse(ctrl.text);
                if (v == null || v <= 0) return;
                final amt = isPercent ? (subtotal * v / 100).round() : v;
                ref.read(manualDiscountProvider.notifier).state =
                    amt.clamp(0, subtotal);
                Navigator.of(ctx).pop();
              },
              child: const Text('適用'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 注文確定（Flow 2：addPending → すぐに精算画面へ）───
  void _confirmOrder(
    BuildContext context,
    WidgetRef ref,
    int subtotal,
    int autoDiscount,
    int manualDiscount,
    int finalTotal,
  ) {
    final cartItems = ref.read(currentOrderProvider);
    final totalDiscount = min(subtotal, autoDiscount + manualDiscount);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注文内容の確認', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...cartItems.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(
                        child: Text(item.productName,
                            style: const TextStyle(fontSize: 14))),
                    Text('× ${item.quantity}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(width: 12),
                    Text('¥${item.subtotal}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14)),
                  ]),
                )),
            if (totalDiscount > 0) ...[
              const Divider(height: 16),
              Row(children: [
                const Text('割引',
                    style: TextStyle(color: Colors.green, fontSize: 13)),
                const Spacer(),
                Text('-¥$totalDiscount',
                    style: const TextStyle(color: Colors.green, fontSize: 13)),
              ]),
            ],
            const Divider(height: 16),
            Center(
              child: Column(children: [
                const Text('合計金額',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text('¥$finalTotal',
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('戻る'),
          ),
          FilledButton.icon(
            onPressed: () async {
              // ダイアログを先に閉じてから API 完了を待つ
              Navigator.of(ctx).pop();

              // pending 登録 → API 完了後にサーバー発行のIDが返る
              // (await することで tempId→serverId 置換後に遷移できる)
              final orderId = await ref
                  .read(orderListProvider.notifier)
                  .addPending(cartItems, subtotal, totalDiscount);
              ref.read(currentOrderProvider.notifier).clear();
              ref.read(manualDiscountProvider.notifier).state = 0;

              if (!context.mounted) return;
              context.go('/orders/checkout/$orderId');
            },
            icon: const Icon(Icons.point_of_sale, size: 16),
            label: const Text('精算へ', style: TextStyle(fontSize: 15)),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 精算待ちボトムシート（Flow 1 用：お客様自己注文の精算）
// ─────────────────────────────────────────────────────────────
class _PendingOrdersSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingOrdersProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, sc) => Column(children: [
        // ハンドル
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(99),
          ),
        ),

        // ヘッダー
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            const Icon(Icons.pending_actions, color: Color(0xFFF97316)),
            const SizedBox(width: 8),
            Text(
              '精算待ち ${pending.length}件',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ]),
        ),

        const Divider(height: 1),

        // 注文リスト
        Expanded(
          child: pending.isEmpty
              ? const Center(
                  child: Text('精算待ちの注文はありません',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  controller: sc,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: pending.length,
                  itemBuilder: (_, i) {
                    final order = pending[i];
                    final time = order.orderedAt;
                    final timeStr = '${time.hour.toString().padLeft(2, '0')}:'
                        '${time.minute.toString().padLeft(2, '0')}';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                        title: Row(children: [
                          // 整理番号
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.orderNumber,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(timeStr,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                          const Spacer(),
                          Text('¥${order.totalAmount}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ]),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            order.items
                                .map((i) => '${i.productName}×${i.quantity}')
                                .join('　'),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ),
                        trailing: FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.go('/orders/checkout/${order.id}');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1456A0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: const Text('精算'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
