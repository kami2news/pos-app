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
import '../../../core/theme/km1.dart';

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
    final c = context.km1;
    final products = ref.watch(productListProvider);
    final cartItems = ref.watch(currentOrderProvider);
    final manualDiscount = ref.watch(manualDiscountProvider);
    final autoResult = ref.watch(autoDiscountProvider);
    final auth = ref.watch(authStateProvider);
    final storeName = auth.storeName ?? '';
    final pendingCount = ref.watch(pendingCountProvider);
    final readyCount = ref
        .watch(orderListProvider)
        .where((o) => o.isReadyForPickup)
        .length;
    final subtotal = ref.read(currentOrderProvider.notifier).subtotal;
    final totalDiscount =
        min(subtotal, autoResult.totalDiscount + manualDiscount);
    final finalTotal = max(0, subtotal - totalDiscount);
    const tabular = [FontFeature.tabularFigures()];

    return Scaffold(
      appBar: AppBar(
        title: Text('注文入力 - $storeName'),
        bottom: storeBand(auth.themeColor),
        actions: [
          // ─── 精算待ち（Flow 1：お客様自己注文の精算）───
          Km1BarAction(
            icon: Km1Icons.waiting,
            label: '精算待ち',
            count: pendingCount,
            onPressed: () => _showPendingOrdersSheet(context, ref),
          ),
          // ─── 注文状況（お渡し待ち）───
          Km1BarAction(
            icon: Km1Icons.checkCircle,
            label: 'お渡し待ち',
            count: readyCount,
            onPressed: () => context.go('/orders/status'),
          ),
          // ─── そのほかの画面（使用頻度の低いものは「⋮」にまとめる）───
          PopupMenuButton<String>(
            icon: const Icon(Km1Icons.more),
            tooltip: 'メニュー',
            onSelected: (v) {
              if (v == 'qr') {
                _showQrDialog(context, storeName);
              } else {
                context.go(v);
              }
            },
            itemBuilder: (_) => [
              _menuItem('qr', Km1Icons.qrCode, 'お客様注文の QR コード'),
              _menuItem('/orders/register', Km1Icons.tablet, 'お客様受付画面'),
              const PopupMenuDivider(),
              _menuItem('/orders/list', Km1Icons.order, '注文一覧'),
              _menuItem('/products', Km1Icons.product, '商品管理'),
              _menuItem('/discount-rules', Km1Icons.discount, 'セット割'),
              _menuItem('/history', Km1Icons.history, '営業日の履歴'),
              const PopupMenuDivider(),
              _menuItem('/closing', Km1Icons.lock, '締め'),
            ],
          ),
          const SizedBox(width: Km1Space.xs),
        ],
      ),
      body: Column(
        children: [
          // ─── セット割の適用バナー ───
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
                  Icon(Km1Icons.checkCircle,
                      size: Km1Size.iconSm, color: c.successInk),
                  Text('セット割を適用中',
                      style: Km1Text.body1Strong.copyWith(color: c.ink)),
                  ...autoResult.applied.map((a) => Text(
                        '${a.rule.name} -¥${a.amount}',
                        style: Km1Text.body1.copyWith(color: c.ink),
                      )),
                ],
              ),
            ),

          // ─── 商品グリッド ───
          Expanded(
            flex: 3,
            child: products.isEmpty
                ? Km1Empty(
                    icon: Km1Icons.product,
                    title: '商品がありません',
                    body: '商品管理で商品を登録すると、ここに表示されます。',
                    action: OutlinedButton(
                      onPressed: () => context.go('/products'),
                      child: const Text('商品を追加'),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(Km1Space.lg),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: Km1Space.sm,
                      mainAxisSpacing: Km1Space.sm,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];
                      final inCart = cartItems
                          .where((it) => it.productId == p.id)
                          .fold(0, (s, it) => s + it.quantity);
                      final selected = inCart > 0;
                      return Semantics(
                        button: true,
                        label: '${p.name}、${p.price} 円'
                            '${selected ? '、カートに $inCart 点' : ''}',
                        child: Material(
                          color: selected ? c.brandTint : c.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Km1Radius.lg),
                            side: BorderSide(
                              color: selected ? c.brandStroke : c.stroke,
                              width: selected
                                  ? Km1Size.strokeThick
                                  : Km1Size.strokeThin,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            hoverColor: c.surfaceHover,
                            onTap: () => ref
                                .read(currentOrderProvider.notifier)
                                .addProduct(
                                    productId: p.id,
                                    productName: p.name,
                                    unitPrice: p.price),
                            child: Stack(children: [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(Km1Space.sm),
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(p.name,
                                            style: Km1Text.body1Strong
                                                .copyWith(color: c.ink),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: Km1Space.xs),
                                        Text('¥${p.price}',
                                            style: Km1Text.body1.copyWith(
                                                color: c.inkSecondary)),
                                      ]),
                                ),
                              ),
                              if (selected)
                                Positioned(
                                  top: Km1Space.sm,
                                  right: Km1Space.sm,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Km1Space.smNudge),
                                    decoration: BoxDecoration(
                                      color: c.brand,
                                      borderRadius: BorderRadius.circular(
                                          Km1Radius.circular),
                                    ),
                                    child: Text('$inCart 点',
                                        style: Km1Text.caption1.copyWith(
                                            color: c.onBrand,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Divider(height: 1, color: c.strokeSubtle),

          // ─── カート＋合計 ───
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            color: c.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cartItems.isNotEmpty)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: Km1Space.lg, vertical: Km1Space.xs),
                      children: cartItems
                          .map((item) => Row(children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.productName,
                                    style: Km1Text.body1.copyWith(color: c.ink),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Km1Icons.subtractCircle),
                                  tooltip: '${item.productName}を 1 つ減らす',
                                  onPressed: () => ref
                                      .read(currentOrderProvider.notifier)
                                      .decreaseProduct(item.productId),
                                ),
                                SizedBox(
                                  width: 32,
                                  child: Text('${item.quantity}',
                                      textAlign: TextAlign.center,
                                      style: Km1Text.subtitle2.copyWith(
                                          color: c.ink, fontFeatures: tabular)),
                                ),
                                IconButton(
                                  icon: const Icon(Km1Icons.addCircle),
                                  tooltip: '${item.productName}を 1 つ増やす',
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
                                    style: Km1Text.body1.copyWith(
                                        color: c.ink, fontFeatures: tabular),
                                  ),
                                ),
                              ]))
                          .toList(),
                    ),
                  ),

                // 小計・割引の内訳
                if (totalDiscount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Km1Space.lg, vertical: Km1Space.xs),
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
                      if (autoResult.totalDiscount > 0)
                        Row(children: [
                          Icon(Km1Icons.discount,
                              size: Km1Size.iconSm, color: c.successInk),
                          const SizedBox(width: Km1Space.xs),
                          Text('セット割',
                              style: Km1Text.body1
                                  .copyWith(color: c.successInk)),
                          const Spacer(),
                          Text('-¥${autoResult.totalDiscount}',
                              style: Km1Text.body1.copyWith(
                                  color: c.successInk, fontFeatures: tabular)),
                        ]),
                      if (manualDiscount > 0)
                        Row(children: [
                          Icon(Km1Icons.discount,
                              size: Km1Size.iconSm, color: c.successInk),
                          const SizedBox(width: Km1Space.xs),
                          Text('手動割引',
                              style: Km1Text.body1
                                  .copyWith(color: c.successInk)),
                          const Spacer(),
                          Text('-¥$manualDiscount',
                              style: Km1Text.body1.copyWith(
                                  color: c.successInk, fontFeatures: tabular)),
                          IconButton(
                            icon: const Icon(Km1Icons.dismissCircle,
                                size: Km1Size.iconSm),
                            tooltip: '手動割引を解除',
                            onPressed: () => ref
                                .read(manualDiscountProvider.notifier)
                                .state = 0,
                          ),
                        ]),
                      Divider(height: Km1Space.sm, color: c.strokeSubtle),
                    ]),
                  ),

                // 合計行 + ボタン
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
                                style: Km1Text.title3.copyWith(
                                    color: c.ink, fontFeatures: tabular)),
                          ]),
                      const SizedBox(width: Km1Space.md),
                      Expanded(
                        child: OverflowBar(
                          alignment: MainAxisAlignment.end,
                          spacing: Km1Space.sm,
                          overflowSpacing: Km1Space.sm,
                          overflowAlignment: OverflowBarAlignment.end,
                          children: [
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
                                child: const Text('カートを空にする'),
                              ),
                            OutlinedButton(
                              onPressed: cartItems.isEmpty
                                  ? null
                                  : () => _showManualDiscountDialog(
                                      context, ref, subtotal),
                              child: Text(manualDiscount > 0
                                  ? '手動割引を変更'
                                  : '手動割引'),
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
                              icon: const Icon(Km1Icons.register,
                                  size: Km1Size.iconMd),
                              label: const Text('注文を確定'),
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

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(children: [
          Icon(icon, size: Km1Size.iconMd),
          const SizedBox(width: Km1Space.md),
          Text(label),
        ]),
      );

  // ─── お客様注文QRコードダイアログ ───
  void _showQrDialog(BuildContext context, String storeName) {
    final encoded = Uri.encodeComponent(storeName);
    const baseUrl = 'https://kami2pos-app.web.app';
    final url = '$baseUrl/customer/$encoded';

    showDialog(
      context: context,
      builder: (ctx) {
        final c = ctx.km1;
        return AlertDialog(
          title: const Text('お客様注文の QR コード'),
          content: SizedBox(
            width: Km1Size.dialogWidthSm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // QR は読み取りやすさを優先して白地に黒で固定する
                Container(
                  padding: const EdgeInsets.all(Km1Space.md),
                  decoration: BoxDecoration(
                    color: Km1Colors.light.surface,
                    borderRadius: BorderRadius.circular(Km1Radius.md),
                    border: Border.all(color: c.stroke),
                  ),
                  child: QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Km1Colors.light.surface,
                  ),
                ),
                const SizedBox(height: Km1Space.md),
                Text('お客様のスマートフォンで読み取ってください。',
                    style: Km1Text.body1.copyWith(color: c.inkSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: Km1Space.md),
                Container(
                  padding: const EdgeInsets.only(left: Km1Space.md),
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(Km1Radius.md),
                    border: Border.all(color: c.stroke),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(url,
                            maxLines: 1,
                            style: Km1Text.caption1.copyWith(color: c.ink)),
                      ),
                      IconButton(
                        icon: const Icon(Km1Icons.copy, size: Km1Size.iconMd),
                        tooltip: 'URL をコピー',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('URL をコピーしました。'),
                                  duration: Duration(seconds: 2)));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  // ─── 精算待ちボトムシート（Flow 1：お客様自己注文の精算）───
  void _showPendingOrdersSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PendingOrdersSheet(),
    );
  }

  void _showManualDiscountDialog(
      BuildContext context, WidgetRef ref, int subtotal) {
    final ctrl = TextEditingController();
    bool isPercent = false;
    final current = ref.read(manualDiscountProvider);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('手動割引'),
          content: SizedBox(
            width: Km1Size.dialogWidthSm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: Km1Space.sm, children: [
                  ChoiceChip(
                    label: const Text('金額（円）'),
                    selected: !isPercent,
                    onSelected: (_) => setState(() => isPercent = false),
                  ),
                  ChoiceChip(
                    label: const Text('割合（%）'),
                    selected: isPercent,
                    onSelected: (_) => setState(() => isPercent = true),
                  ),
                ]),
                const SizedBox(height: Km1Space.lg),
                Km1Field(
                  label: isPercent ? '割引率（%）' : '割引額（円）',
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(
                      hintText: isPercent ? '10' : '500',
                      prefixText: isPercent ? null : '¥ ',
                      suffixText: isPercent ? '%' : null,
                    ),
                  ),
                ),
                if (current > 0) ...[
                  const SizedBox(height: Km1Space.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        ref.read(manualDiscountProvider.notifier).state = 0;
                        Navigator.of(ctx).pop();
                      },
                      child: Text('今の割引（-¥$current）を解除'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
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
      builder: (ctx) {
        final c = ctx.km1;
        const tabular = [FontFeature.tabularFigures()];
        return AlertDialog(
          title: const Text('注文内容の確認'),
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
                                style: Km1Text.body1.copyWith(color: c.ink))),
                        Text('× ${item.quantity}',
                            style: Km1Text.body1
                                .copyWith(color: c.inkSecondary)),
                        const SizedBox(width: Km1Space.md),
                        Text('¥${item.subtotal}',
                            style: Km1Text.body1
                                .copyWith(color: c.ink, fontFeatures: tabular)),
                      ]),
                    )),
                if (totalDiscount > 0) ...[
                  Divider(height: Km1Space.lg, color: c.strokeSubtle),
                  Row(children: [
                    Text('割引',
                        style: Km1Text.body1.copyWith(color: c.successInk)),
                    const Spacer(),
                    Text('-¥$totalDiscount',
                        style: Km1Text.body1.copyWith(
                            color: c.successInk, fontFeatures: tabular)),
                  ]),
                ],
                Divider(height: Km1Space.lg, color: c.strokeSubtle),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('合計',
                        style: Km1Text.body1Strong.copyWith(color: c.ink)),
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
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                // ダイアログを先に閉じてから API 完了を待つ
                Navigator.of(ctx).pop();

                // pending 登録 → API 完了後にサーバー発行のIDが返る
                // (await することで tempId→serverId 置換後に遷移できる)
                final orderId = await ref
                    .read(orderListProvider.notifier)
                    .addPending(cartItems, subtotal, totalDiscount,
                        manualDiscountAmount: manualDiscount);
                ref.read(currentOrderProvider.notifier).clear();
                ref.read(manualDiscountProvider.notifier).state = 0;

                if (!context.mounted) return;
                context.go('/orders/checkout/$orderId');
              },
              child: const Text('精算へ進む'),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 精算待ちボトムシート（Flow 1 用：お客様自己注文の精算）
// ─────────────────────────────────────────────────────────────
class _PendingOrdersSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.km1;
    final pending = ref.watch(pendingOrdersProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, sc) => Column(children: [
        // ヘッダー
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Km1Space.lg, Km1Space.md, Km1Space.xs, Km1Space.sm),
          child: Row(children: [
            Icon(Km1Icons.waiting, color: c.warningInk),
            const SizedBox(width: Km1Space.sm),
            Expanded(
              child: Text('精算待ち ${pending.length} 件',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              icon: const Icon(Km1Icons.close),
              tooltip: '閉じる',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
        ),

        Divider(height: 1, color: c.strokeSubtle),

        // 注文リスト
        Expanded(
          child: pending.isEmpty
              ? const Km1Empty(
                  icon: Km1Icons.checkCircle,
                  title: '精算待ちの注文はありません',
                )
              : ListView.separated(
                  controller: sc,
                  padding: const EdgeInsets.all(Km1Space.lg),
                  itemCount: pending.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Km1Space.sm),
                  itemBuilder: (_, i) {
                    final order = pending[i];
                    return Container(
                      decoration: km1CardDecoration(context),
                      padding: const EdgeInsets.fromLTRB(
                          Km1Space.lg, Km1Space.md, Km1Space.md, Km1Space.md),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                // 整理番号（精算待ち = warning）
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Km1Space.sm,
                                      vertical: Km1Space.xxs),
                                  decoration: BoxDecoration(
                                    color: c.warningTint,
                                    border: Border.all(color: c.warningInk),
                                    borderRadius:
                                        BorderRadius.circular(Km1Radius.md),
                                  ),
                                  child: Text(order.orderNumber,
                                      style: Km1Text.subtitle2
                                          .copyWith(color: c.ink)),
                                ),
                                const SizedBox(width: Km1Space.sm),
                                Text(km1Time(order.orderedAt),
                                    style: Km1Text.body1
                                        .copyWith(color: c.inkSecondary)),
                                const Spacer(),
                                Text('¥${order.totalAmount}',
                                    style: Km1Text.subtitle2
                                        .copyWith(color: c.ink)),
                              ]),
                              const SizedBox(height: Km1Space.xs),
                              Text(
                                order.items
                                    .map((i) =>
                                        '${i.productName} × ${i.quantity}')
                                    .join('、'),
                                style: Km1Text.body1
                                    .copyWith(color: c.inkSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Km1Space.md),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.go('/orders/checkout/${order.id}');
                          },
                          child: const Text('精算'),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
