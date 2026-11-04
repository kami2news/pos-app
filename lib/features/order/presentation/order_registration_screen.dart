import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../products/domain/products_provider.dart';
import '../domain/order_provider.dart';

/// 注文受付画面（お客様操作 / セルフオーダー）
/// ─ お客様が商品を選んで「注文する」ボタンを押すと pending 注文が作られる
/// ─ スタッフ向け操作（手動割引・商品管理・セット割設定）は非表示
/// ─ 大きなタップターゲットでキオスク利用を想定
class OrderRegistrationScreen extends ConsumerWidget {
  const OrderRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListProvider);
    final cartItems = ref.watch(currentOrderProvider);
    final autoResult = ref.watch(autoDiscountProvider);
    final storeName = ref.watch(authStateProvider).storeName ?? '';
    final subtotal = ref.read(currentOrderProvider.notifier).subtotal;
    final totalDiscount = autoResult.totalDiscount.clamp(0, subtotal);
    final finalTotal = max(0, subtotal - totalDiscount);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // ─── お客様向けのシンプルなヘッダー ───
      appBar: AppBar(
        title: Text(storeName.isNotEmpty ? storeName : 'ご注文'),
        automaticallyImplyLeading: false, // 戻るボタン非表示
      ),

      body: Column(
        children: [
          // ─── セット割バナー（自動適用のみ・読み取り専用） ───
          if (autoResult.applied.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFE6F4ED),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: autoResult.applied
                    .map((a) => Chip(
                          avatar: const Icon(Icons.local_offer,
                              size: 14, color: Color(0xFF085041)),
                          label: Text('${a.rule.name}  -¥${a.amount}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF085041))),
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
                ? const Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('ただいま商品を準備中です',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200, // 少し大きめ
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];
                      final inCart = cartItems
                          .where((c) => c.productId == p.id)
                          .fold(0, (s, c) => s + c.quantity);
                      return GestureDetector(
                        onTap: () =>
                            ref.read(currentOrderProvider.notifier).addProduct(
                                  productId: p.id,
                                  productName: p.name,
                                  unitPrice: p.price,
                                ),
                        child: Card(
                          elevation: inCart > 0 ? 4 : 1,
                          color:
                              inCart > 0 ? colorScheme.primaryContainer : null,
                          child: Stack(children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 商品名（大きめ）
                                  Text(p.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: inCart > 0
                                            ? colorScheme.onPrimaryContainer
                                            : null,
                                      ),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 6),
                                  // 価格（大きめ）
                                  Text('¥${p.price}',
                                      style: TextStyle(
                                        color: inCart > 0
                                            ? colorScheme.onPrimaryContainer
                                                .withValues(alpha: 0.7)
                                            : Colors.grey[600],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      )),
                                ],
                              ),
                            ),
                            // カート数バッジ
                            if (inCart > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: colorScheme.primary,
                                  child: Text('$inCart',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // ─── カート ───
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // カートが空の場合
                if (cartItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('商品を選んでください',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),

                // カートアイテム一覧
                if (cartItems.isNotEmpty)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      children: cartItems
                          .map((item) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Row(children: [
                                  Expanded(
                                    child: Text(item.productName,
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  // ─ ボタン（大きめ）─
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 22),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => ref
                                          .read(currentOrderProvider.notifier)
                                          .decreaseProduct(item.productId),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: Text('${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ),
                                  // ＋ ボタン
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: IconButton(
                                      icon: const Icon(Icons.add_circle_outline,
                                          size: 22),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => ref
                                          .read(currentOrderProvider.notifier)
                                          .addProduct(
                                            productId: item.productId,
                                            productName: item.productName,
                                            unitPrice: item.unitPrice,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('¥${item.subtotal}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14)),
                                ]),
                              ))
                          .toList(),
                    ),
                  ),

                // 割引の内訳（セット割のみ）
                if (totalDiscount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Column(children: [
                      Row(children: [
                        const Text('小計',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const Spacer(),
                        Text('¥$subtotal',
                            style: const TextStyle(fontSize: 13)),
                      ]),
                      Row(children: [
                        const Icon(Icons.local_offer,
                            size: 12, color: Color(0xFF085041)),
                        const SizedBox(width: 4),
                        const Text('セット割',
                            style: TextStyle(
                                color: Color(0xFF085041), fontSize: 13)),
                        const Spacer(),
                        Text('-¥$totalDiscount',
                            style: const TextStyle(
                                color: Color(0xFF085041), fontSize: 13)),
                      ]),
                      const Divider(height: 8),
                    ]),
                  ),

                // 合計＋ボタン行
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 合計
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('合計',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Text('¥$finalTotal',
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.bold)),
                          ]),
                      const Spacer(),

                      // クリアボタン（小さめ・控えめ）
                      if (cartItems.isNotEmpty)
                        TextButton(
                          onPressed: () =>
                              ref.read(currentOrderProvider.notifier).clear(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                          child: const Text('クリア'),
                        ),

                      const SizedBox(width: 8),

                      // 注文ボタン（大きく・目立つ）
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: cartItems.isEmpty
                              ? null
                              : () => _confirmOrder(
                                  context, ref, finalTotal, totalDiscount),
                          icon: const Icon(Icons.check, size: 20),
                          label: const Text('注文する',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
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

  // ─── 注文確認ダイアログ ───
  void _confirmOrder(
    BuildContext context,
    WidgetRef ref,
    int finalTotal,
    int discountAmount,
  ) {
    final cartItems = ref.read(currentOrderProvider);
    final subtotal = cartItems.fold(0, (s, i) => s + i.subtotal);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('ご注文の確認',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 注文内容リスト
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

            if (discountAmount > 0) ...[
              const Divider(height: 16),
              Row(children: [
                const Text('割引',
                    style: TextStyle(color: Colors.green, fontSize: 13)),
                const Spacer(),
                Text('-¥$discountAmount',
                    style: const TextStyle(color: Colors.green, fontSize: 13)),
              ]),
            ],

            const Divider(height: 16),

            // 合計（大きく）
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
          // 戻るボタン
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(120, 44),
            ),
            child: const Text('戻る', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          // 確定ボタン
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _placeOrder(context, ref, subtotal, discountAmount, finalTotal);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 44),
            ),
            child: const Text('注文する', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // ─── 注文確定（pending 登録）→ 番号表示 ───
  void _placeOrder(
    BuildContext context,
    WidgetRef ref,
    int subtotal,
    int discountAmount,
    int finalTotal,
  ) {
    final cartItems = ref.read(currentOrderProvider);

    ref
        .read(orderListProvider.notifier)
        .addPending(cartItems, subtotal, discountAmount);
    ref.read(currentOrderProvider.notifier).clear();

    final orderNumber = ref.read(orderListProvider).last.orderNumber;

    // 整理番号を大きく表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('ご注文ありがとうございます',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // ─── 整理番号 ───
          const Text('整理番号',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            orderNumber,
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Theme.of(ctx).colorScheme.primary,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ─── 合計金額 ───
          const Text('合計金額',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '¥$finalTotal',
            style: const TextStyle(
                fontSize: 40, fontWeight: FontWeight.bold, height: 1.1),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'この番号をスタッフにお伝えください\nお支払いは番号をお呼びしてから行います',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, 48),
            ),
            child: const Text('閉じる', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
