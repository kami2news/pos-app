import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../products/domain/products_provider.dart';
import '../domain/order_provider.dart';
import '../../../core/theme/km1.dart';
import 'widgets/product_tile.dart';

/// 注文受付画面（お客様操作 / セルフオーダー）
/// ─ お客様が商品を選んで「注文する」ボタンを押すと pending 注文が作られる
/// ─ スタッフ向け操作（手動割引・商品管理・セット割設定）は非表示
/// ─ 大きなタップターゲットでキオスク利用を想定
class OrderRegistrationScreen extends ConsumerWidget {
  const OrderRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.km1;
    final products = ref.watch(productListProvider);
    final cartItems = ref.watch(currentOrderProvider);
    final autoResult = ref.watch(autoDiscountProvider);
    final auth = ref.watch(authStateProvider);
    final storeName = auth.storeName ?? '';
    final subtotal = ref.read(currentOrderProvider.notifier).subtotal;
    final totalDiscount = autoResult.totalDiscount.clamp(0, subtotal);
    final finalTotal = max(0, subtotal - totalDiscount);
    const tabular = [FontFeature.tabularFigures()];

    return Scaffold(
      // ─── お客様向けのシンプルなヘッダー ───
      appBar: AppBar(
        title: Text(storeName.isNotEmpty ? storeName : 'ご注文'),
        automaticallyImplyLeading: false, // 戻るボタン非表示
        bottom: storeBand(auth.themeColor),
      ),

      body: Column(
        children: [
          // ─── セット割バナー（自動適用のみ・読み取り専用） ───
          if (autoResult.applied.isNotEmpty)
            Container(
              width: double.infinity,
              color: c.successTint,
              padding: const EdgeInsets.symmetric(
                  horizontal: Km1Space.lg, vertical: Km1Space.sm),
              child: Wrap(
                spacing: Km1Space.sm,
                runSpacing: Km1Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Km1Icons.discount,
                      size: Km1Size.iconSm, color: c.successInk),
                  Text('セット割が適用されています',
                      style: Km1Text.body1Strong.copyWith(color: c.ink)),
                  ...autoResult.applied.map((a) => Text(
                      '${a.rule.name} -¥${a.amount}',
                      style: Km1Text.body1.copyWith(color: c.ink))),
                ],
              ),
            ),

          // ─── 商品グリッド ───
          Expanded(
            flex: 3,
            child: products.isEmpty
                ? const Km1Empty(
                    icon: Km1Icons.store,
                    title: 'ただいま商品を準備しています',
                    body: 'しばらくお待ちください。',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(Km1Space.lg),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200, // 少し大きめ
                      childAspectRatio: 1.2,
                      crossAxisSpacing: Km1Space.md,
                      mainAxisSpacing: Km1Space.md,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];
                      final inCart = cartItems
                          .where((it) => it.productId == p.id)
                          .fold(0, (s, it) => s + it.quantity);
                      return ProductTile(
                        name: p.name,
                        price: p.price,
                        count: inCart,
                        large: true,
                        onTap: () =>
                            ref.read(currentOrderProvider.notifier).addProduct(
                                  productId: p.id,
                                  productName: p.name,
                                  unitPrice: p.price,
                                ),
                      );
                    },
                  ),
          ),

          Divider(height: 1, color: c.strokeSubtle),

          // ─── カート ───
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            color: c.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // カートが空の場合
                if (cartItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Km1Space.lg),
                    child: Text('商品を選んでください',
                        style: Km1Text.body1.copyWith(color: c.inkSecondary)),
                  ),

                // カートアイテム一覧
                if (cartItems.isNotEmpty)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(
                          Km1Space.lg, Km1Space.sm, Km1Space.lg, 0),
                      children: cartItems
                          .map((item) => CartRow(
                                name: item.productName,
                                quantity: item.quantity,
                                subtotal: item.subtotal,
                                onDecrease: () => ref
                                    .read(currentOrderProvider.notifier)
                                    .decreaseProduct(item.productId),
                                onIncrease: () => ref
                                    .read(currentOrderProvider.notifier)
                                    .addProduct(
                                      productId: item.productId,
                                      productName: item.productName,
                                      unitPrice: item.unitPrice,
                                    ),
                              ))
                          .toList(),
                    ),
                  ),

                // 割引の内訳（セット割のみ）
                if (totalDiscount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Km1Space.lg, Km1Space.xs, Km1Space.lg, 0),
                    child: Column(children: [
                      Row(children: [
                        Text('小計',
                            style: Km1Text.body1
                                .copyWith(color: c.inkSecondary)),
                        const Spacer(),
                        Text('¥$subtotal',
                            style: Km1Text.body1.copyWith(
                                color: c.ink, fontFeatures: tabular)),
                      ]),
                      Row(children: [
                        Icon(Km1Icons.discount,
                            size: Km1Size.iconSm, color: c.successInk),
                        const SizedBox(width: Km1Space.xs),
                        Text('セット割',
                            style:
                                Km1Text.body1.copyWith(color: c.successInk)),
                        const Spacer(),
                        Text('-¥$totalDiscount',
                            style: Km1Text.body1.copyWith(
                                color: c.successInk, fontFeatures: tabular)),
                      ]),
                      Divider(height: Km1Space.sm, color: c.strokeSubtle),
                    ]),
                  ),

                // 合計＋ボタン行
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Km1Space.lg, Km1Space.xs, Km1Space.lg, Km1Space.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('合計',
                                style: Km1Text.caption1
                                    .copyWith(color: c.inkSecondary)),
                            Text('¥$finalTotal',
                                style: Km1Text.title2.copyWith(
                                    color: c.ink, fontFeatures: tabular)),
                          ]),
                      const Spacer(),
                      if (cartItems.isNotEmpty)
                        TextButton(
                          onPressed: () =>
                              ref.read(currentOrderProvider.notifier).clear(),
                          child: const Text('すべて外す'),
                        ),
                      const SizedBox(width: Km1Space.sm),
                      // 注文ボタン（お客様向けは 48px の大きいボタン）
                      FilledButton(
                        onPressed: cartItems.isEmpty
                            ? null
                            : () => _confirmOrder(
                                context, ref, finalTotal, totalDiscount),
                        style: const ButtonStyle(
                          minimumSize: WidgetStatePropertyAll(
                              Size(160, Km1Size.controlLgTouch)),
                          textStyle: WidgetStatePropertyAll(Km1Text.subtitle2),
                        ),
                        child: const Text('注文する'),
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
    const tabular = [FontFeature.tabularFigures()];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = ctx.km1;
        return AlertDialog(
          title: const Text('ご注文の確認'),
          content: SizedBox(
            width: Km1Size.dialogWidthSm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...cartItems.map((item) => Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: Km1Space.xxs),
                      child: Row(children: [
                        Expanded(
                            child: Text(item.productName,
                                style: Km1Text.body2.copyWith(color: c.ink))),
                        Text('× ${item.quantity}',
                            style: Km1Text.body2
                                .copyWith(color: c.inkSecondary)),
                        const SizedBox(width: Km1Space.md),
                        Text('¥${item.subtotal}',
                            style: Km1Text.body2
                                .copyWith(color: c.ink, fontFeatures: tabular)),
                      ]),
                    )),
                if (discountAmount > 0) ...[
                  Divider(height: Km1Space.lg, color: c.strokeSubtle),
                  Row(children: [
                    Text('割引',
                        style: Km1Text.body2.copyWith(color: c.successInk)),
                    const Spacer(),
                    Text('-¥$discountAmount',
                        style: Km1Text.body2.copyWith(
                            color: c.successInk, fontFeatures: tabular)),
                  ]),
                ],
                Divider(height: Km1Space.lg, color: c.strokeSubtle),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('合計',
                        style: Km1Text.subtitle2.copyWith(color: c.ink)),
                    const Spacer(),
                    Text('¥$finalTotal',
                        style: Km1Text.title1
                            .copyWith(color: c.ink, fontFeatures: tabular)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _placeOrder(context, ref, subtotal, discountAmount, finalTotal);
              },
              child: const Text('注文する'),
            ),
          ],
        );
      },
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
      builder: (ctx) {
        final c = ctx.km1;
        return AlertDialog(
          title: const Text('ご注文ありがとうございます'),
          content: SizedBox(
            width: Km1Size.dialogWidthSm,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('整理番号',
                      textAlign: TextAlign.center,
                      style: Km1Text.body1.copyWith(color: c.inkSecondary)),
                  Text(orderNumber,
                      textAlign: TextAlign.center,
                      style: Km1Text.display.copyWith(color: c.ink)),
                  Text('合計 ¥$finalTotal',
                      textAlign: TextAlign.center,
                      style: Km1Text.title3.copyWith(color: c.ink)),
                  const SizedBox(height: Km1Space.lg),
                  const Km1Notice(
                    status: Km1Status.info,
                    title: 'この番号をスタッフにお伝えください',
                    body: 'お支払いは、番号をお呼びしてからお願いします。',
                  ),
                ]),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}
