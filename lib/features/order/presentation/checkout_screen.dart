import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/order_provider.dart';
import '../domain/models/order_model.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../../core/theme/km1.dart';

/// レジ精算画面
/// ─ pending 状態の注文を受け取り、支払い方法を選んで精算完了にする
/// ─ GoRouter から orderId をパスパラメータで受け取る
class CheckoutScreen extends ConsumerStatefulWidget {
  final String orderId;
  const CheckoutScreen({super.key, required this.orderId});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod? _method;
  final _receivedCtrl = TextEditingController();
  bool _processing = false;
  bool _initializing = true; // 画面初期化中フラグ（サーバーから注文を再取得するまでの待機）
  bool _submitted = false;   // 精算確定後フラグ（loadOrders競合で精算前フォームが再表示されるのを防ぐ）

  /// true = 精算＋お渡し管理モード
  /// false = 精算のみモード（デフォルト）
  bool _withHandover = false;

  @override
  void initState() {
    super.initState();
    // タイマーとの競合回避：画面を開いた瞬間にサーバーから最新注文一覧を取得する
    // addPending() の tempId→serverId 差し替えの前に loadOrders() が走ると
    // ローカル state から注文が消えてしまうため、ここで確実に再取得する
    _initialize();
  }

  Future<void> _initialize() async {
    await ref.read(orderListProvider.notifier).loadOrders();
    if (mounted) setState(() => _initializing = false);
  }

  @override
  void dispose() {
    _receivedCtrl.dispose();
    super.dispose();
  }

  // ─── お釣り計算 ───
  int get _received => int.tryParse(_receivedCtrl.text) ?? 0;
  int _change(int total) => _received - total;

  // ─── 精算実行 ───
  void _complete(BuildContext context, OrderModel order) async {
    if (_method == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('支払い方法を選んでください。')));
      return;
    }
    if (_method == PaymentMethod.cash) {
      final change = _change(order.totalAmount);
      if (_received < order.totalAmount) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('受取金額が合計に足りません。受取金額を確認してください。')));
        return;
      }
      // お釣り確認ダイアログ
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('現金精算の確認'),
          content: SizedBox(
            width: Km1Size.dialogWidthSm,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _ConfirmRow(
                  label: '合計', value: '¥${order.totalAmount}', bold: true),
              _ConfirmRow(label: '受取', value: '¥$_received'),
              Divider(color: ctx.km1.strokeSubtle),
              _ConfirmRow(label: 'お釣り', value: '¥$change', bold: true),
            ]),
          ),
          actions: [
            OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('キャンセル')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('精算を完了')),
          ],
        ),
      );
      if (ok != true) return;
    }

    // _submitted = true にしてからUIをロック
    // → in-flight の loadOrders() がサーバーの pending 状態を返しても
    //   精算前フォームが再表示されるのを防ぐ（race condition 対策）
    setState(() {
      _processing = true;
      _submitted = true;
    });

    if (_withHandover) {
      // 精算＋お渡しモード：支払済み・お渡し待ちへ
      // awaitしてサーバー更新完了後にナビゲートする（race condition対策）
      await ref.read(orderListProvider.notifier).readyOrderForPickup(
            widget.orderId,
            _method!,
            receivedAmount: _method == PaymentMethod.cash ? _received : null,
          );
    } else {
      // 精算のみモード：即完了
      ref.read(orderListProvider.notifier).completeOrder(
            widget.orderId,
            _method!,
            receivedAmount: _method == PaymentMethod.cash ? _received : null,
          );
    }

    if (!context.mounted) return;
    setState(() => _processing = false);

    _showCompletionDialog(context, order);
  }

  void _showCompletionDialog(BuildContext context, OrderModel order) {
    final isHandoverMode = _withHandover;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = ctx.km1;
        final change = _change(order.totalAmount);
        return AlertDialog(
          title: Text(isHandoverMode ? '支払いが完了しました' : '精算が完了しました'),
          content: SizedBox(
            width: Km1Size.dialogWidthSm,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Km1Notice(
                    status: Km1Status.success,
                    title: isHandoverMode ? '支払い済み・お渡し待ち' : '精算済み',
                    body: isHandoverMode
                        ? '商品を渡したら、注文状況の画面で「お渡し完了」を押してください。'
                        : null,
                  ),
                  const SizedBox(height: Km1Space.lg),
                  // ─── 整理番号（大きく表示） ───
                  Text('整理番号',
                      textAlign: TextAlign.center,
                      style: Km1Text.body1.copyWith(color: c.inkSecondary)),
                  Text(order.orderNumber,
                      textAlign: TextAlign.center,
                      style: Km1Text.display.copyWith(color: c.ink)),
                  Text(
                      '¥${order.totalAmount}（${_method == PaymentMethod.cash ? '現金' : 'カード'}）',
                      textAlign: TextAlign.center,
                      style: Km1Text.subtitle1.copyWith(color: c.ink)),
                  // お釣り（現金の場合）
                  if (_method == PaymentMethod.cash && change > 0) ...[
                    const SizedBox(height: Km1Space.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Km1Space.lg, vertical: Km1Space.sm),
                      decoration: BoxDecoration(
                        color: c.infoTint,
                        borderRadius: BorderRadius.circular(Km1Radius.lg),
                        border: Border.all(color: c.infoInk),
                      ),
                      child: Row(children: [
                        Text('お釣り',
                            style: Km1Text.body1Strong.copyWith(color: c.ink)),
                        const Spacer(),
                        Text('¥$change',
                            style: Km1Text.title3.copyWith(color: c.ink)),
                      ]),
                    ),
                  ],
                ]),
          ),
          actions: isHandoverMode
              // お渡しモード：注文状況の画面へ誘導
              ? [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go('/orders/status');
                    },
                    child: const Text('注文状況へ'),
                  ),
                ]
              // 精算のみモード：次の注文 or 注文状況
              : [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go('/orders/status');
                    },
                    child: const Text('注文状況へ'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go('/orders');
                    },
                    child: const Text('次の注文へ'),
                  ),
                ],
        );
      },
    );
  }

  // ─── 注文の取り消し ───
  void _cancel(BuildContext context, String orderNumber) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('整理番号 $orderNumber の注文を取り消しますか'),
        content: const Text('取り消した注文は元に戻せません。'),
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
    if (ok != true) return;

    ref.read(orderListProvider.notifier).cancelOrder(widget.orderId);
    if (!context.mounted) return;
    context.go('/orders/status');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final storeColor = ref.watch(authStateProvider.select((s) => s.themeColor));

    Scaffold simple(Widget body) => Scaffold(
          appBar: AppBar(
              title: const Text('レジ精算'), bottom: storeBand(storeColor)),
          body: body,
        );

    // サーバーからの再取得が完了するまでローディングを表示
    if (_initializing) {
      return simple(const Center(child: CircularProgressIndicator()));
    }

    // 精算確定後は loadOrders() の race condition でフォームが再表示されないようスピナーを表示
    // （5秒タイマーの in-flight loadOrders() がサーバーの pending 状態を返してもUIに影響させない）
    if (_submitted) {
      return simple(const Center(child: CircularProgressIndicator()));
    }

    final orders = ref.watch(orderListProvider);
    final order = orders
        .cast<OrderModel?>()
        .firstWhere((o) => o?.id == widget.orderId, orElse: () => null);

    if (order == null) {
      return simple(Km1Empty(
        icon: Km1Icons.error,
        title: '注文が見つかりません',
        body: 'すでに精算されたか、取り消された可能性があります。',
        action: OutlinedButton(
            onPressed: () => context.go('/orders/status'),
            child: const Text('注文状況に戻る')),
      ));
    }

    // 既に完了 or キャンセル済み or お渡し待ち
    if (!order.isPending) {
      final Km1Status status;
      final String message;
      if (order.isCompleted) {
        status = Km1Status.success;
        message = 'この注文は精算済みです';
      } else if (order.isReadyForPickup) {
        status = Km1Status.info;
        message = '支払い済みで、お渡し待ちです';
      } else {
        status = Km1Status.warning;
        message = 'この注文は取り消されています';
      }
      return simple(Center(
        child: Padding(
          padding: const EdgeInsets.all(Km1Space.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Km1Size.dialogWidthSm),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Km1Notice(status: status, title: message),
                  const SizedBox(height: Km1Space.lg),
                  OutlinedButton(
                      onPressed: () => context.go('/orders/status'),
                      child: const Text('注文状況に戻る')),
                ]),
          ),
        ),
      ));
    }

    const tabular = [FontFeature.tabularFigures()];
    final change = _change(order.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text('レジ精算  整理番号 ${order.orderNumber}'),
        bottom: storeBand(storeColor),
        leading: IconButton(
          icon: const Icon(Km1Icons.back),
          tooltip: '戻る',
          onPressed: () => context.go('/orders/status'),
        ),
        actions: [
          Km1BarAction(
            icon: Km1Icons.dismissCircle,
            label: '注文を取り消す',
            onPressed: () {
              if (!_processing) _cancel(context, order.orderNumber);
            },
          ),
          const SizedBox(width: Km1Space.xs),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Km1Size.contentWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Km1Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── 精算モード切替 ───
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('精算のみ'),
                      icon: Icon(Km1Icons.checkCircle),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('精算＋お渡し'),
                      icon: Icon(Km1Icons.product),
                    ),
                  ],
                  selected: {_withHandover},
                  onSelectionChanged: (s) =>
                      setState(() => _withHandover = s.first),
                  style: const ButtonStyle(
                    iconSize: WidgetStatePropertyAll(Km1Size.iconSm),
                  ),
                ),
                const SizedBox(height: Km1Space.xs),
                Text(
                  _withHandover
                      ? '支払いのあと、注文状況の画面で「お渡し完了」を押します。'
                      : '支払いと同時に完了になります。',
                  style: Km1Text.caption1.copyWith(color: c.inkSecondary),
                ),
                const SizedBox(height: Km1Space.lg),

                // 商品リスト
                Container(
                  decoration: km1CardDecoration(context),
                  padding: const EdgeInsets.all(Km1Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('注文内容',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: Km1Space.md),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: Km1Space.xs),
                            child: Row(children: [
                              Expanded(
                                  child: Text(item.productName,
                                      style: Km1Text.body1
                                          .copyWith(color: c.ink))),
                              Text('× ${item.quantity}',
                                  style: Km1Text.body1
                                      .copyWith(color: c.inkSecondary)),
                              const SizedBox(width: Km1Space.lg),
                              Text('¥${item.subtotal}',
                                  style: Km1Text.body1.copyWith(
                                      color: c.ink, fontFeatures: tabular)),
                            ]),
                          )),
                      if (order.discountAmount > 0) ...[
                        Divider(height: Km1Space.lg, color: c.strokeSubtle),
                        Row(children: [
                          Text('小計',
                              style: Km1Text.body1
                                  .copyWith(color: c.inkSecondary)),
                          const Spacer(),
                          Text('¥${order.subtotal}',
                              style: Km1Text.body1.copyWith(
                                  color: c.ink, fontFeatures: tabular)),
                        ]),
                        Row(children: [
                          Text('割引',
                              style: Km1Text.body1
                                  .copyWith(color: c.successInk)),
                          const Spacer(),
                          Text('-¥${order.discountAmount}',
                              style: Km1Text.body1.copyWith(
                                  color: c.successInk, fontFeatures: tabular)),
                        ]),
                      ],
                      Divider(height: Km1Space.lg, color: c.strokeSubtle),
                      Row(children: [
                        Text('合計',
                            style: Km1Text.subtitle2.copyWith(color: c.ink)),
                        const Spacer(),
                        Text('¥${order.totalAmount}',
                            style: Km1Text.title3.copyWith(
                                color: c.ink, fontFeatures: tabular)),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: Km1Space.xxl),

                // ─── 支払い方法 ───
                Text('支払い方法', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Km1Space.sm),
                Row(children: [
                  Expanded(
                    child: _PaymentMethodCard(
                      icon: Km1Icons.cash,
                      label: '現金',
                      selected: _method == PaymentMethod.cash,
                      onTap: () => setState(() {
                        _method = PaymentMethod.cash;
                      }),
                    ),
                  ),
                  const SizedBox(width: Km1Space.sm),
                  Expanded(
                    child: _PaymentMethodCard(
                      icon: Km1Icons.card,
                      label: 'カード',
                      selected: _method == PaymentMethod.card,
                      onTap: () => setState(() {
                        _method = PaymentMethod.card;
                        _receivedCtrl.clear();
                      }),
                    ),
                  ),
                ]),

                // ─── 現金入力 ───
                if (_method == PaymentMethod.cash) ...[
                  const SizedBox(height: Km1Space.xxl),
                  Km1Field(
                    label: '受取金額（円）',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _receivedCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(prefixText: '¥ '),
                        ),
                        const SizedBox(height: Km1Space.sm),
                        // クイック金額ボタン
                        _QuickAmountRow(
                          total: order.totalAmount,
                          onSelect: (v) => setState(() {
                            _receivedCtrl.text = v.toString();
                          }),
                        ),
                      ],
                    ),
                  ),

                  // リアルタイムお釣り表示（色だけでなく「お釣り」「不足」の文言とアイコンで示す）
                  if (_received > 0) ...[
                    const SizedBox(height: Km1Space.md),
                    Container(
                      padding: const EdgeInsets.all(Km1Space.lg),
                      decoration: BoxDecoration(
                        color: change >= 0 ? c.infoTint : c.dangerTint,
                        borderRadius: BorderRadius.circular(Km1Radius.lg),
                        border: Border.all(
                            color: change >= 0 ? c.infoInk : c.dangerInk),
                      ),
                      child: Row(
                        children: [
                          Icon(change >= 0 ? Km1Icons.cash : Km1Icons.error,
                              color: change >= 0 ? c.infoInk : c.dangerInk),
                          const SizedBox(width: Km1Space.sm),
                          Text(change >= 0 ? 'お釣り' : '不足',
                              style: Km1Text.body1Strong
                                  .copyWith(color: c.ink)),
                          const Spacer(),
                          Text('¥${change.abs()}',
                              style: Km1Text.title3.copyWith(
                                  color: c.ink, fontFeatures: tabular)),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),

      // ─── 精算ボタン ───
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.strokeSubtle)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Km1Space.lg),
            child: FilledButton(
              onPressed: (_method == null || _processing)
                  ? null
                  : () => _complete(context, order),
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(
                    Size.fromHeight(Km1Size.controlLgTouch)),
              ),
              child: Text(
                _method == null
                    ? '支払い方法を選んでください'
                    : _withHandover
                        ? (_method == PaymentMethod.card
                            ? 'カードで支払いを完了'
                            : '現金で支払いを完了')
                        : (_method == PaymentMethod.card
                            ? 'カードで精算を完了'
                            : '現金で精算を完了'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── サブウィジェット ─────────────────────────────────────

class _ConfirmRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _ConfirmRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final style = (bold ? Km1Text.subtitle2 : Km1Text.body1).copyWith(
        color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Km1Space.xs),
      child: Row(children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ]),
    );
  }
}

/// 支払い方法の選択肢（選択中は brandStroke の縁 + 塗りのチェックで示す）
class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentMethodCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.brandTint : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Km1Radius.lg),
          side: BorderSide(
            color: selected ? c.brandStroke : c.strokeStrong,
            width: selected ? Km1Size.strokeThick : Km1Size.strokeThin,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: c.surfaceHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Km1Space.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: Km1Size.iconLg,
                    color: selected ? c.brandInk : c.inkSecondary),
                const SizedBox(width: Km1Space.sm),
                Text(label,
                    style: (selected ? Km1Text.subtitle2 : Km1Text.body2)
                        .copyWith(color: c.ink)),
                if (selected) ...[
                  const SizedBox(width: Km1Space.sm),
                  Icon(Km1Icons.checkCircleFilled,
                      size: Km1Size.iconMd, color: c.brandInk),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAmountRow extends StatelessWidget {
  final int total;
  final void Function(int) onSelect;
  const _QuickAmountRow({required this.total, required this.onSelect});

  List<int> get _amounts {
    final result = <int>[];
    // ちょうど
    result.add(total);
    // キリの良い金額（100の倍数で繰り上げ）
    final rounded100 = ((total + 99) ~/ 100) * 100;
    if (rounded100 != total) result.add(rounded100);
    // 500の倍数
    final rounded500 = ((total + 499) ~/ 500) * 500;
    if (!result.contains(rounded500)) result.add(rounded500);
    // 1000の倍数
    final rounded1000 = ((total + 999) ~/ 1000) * 1000;
    if (!result.contains(rounded1000)) result.add(rounded1000);
    return result.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Km1Space.sm,
      runSpacing: Km1Space.sm,
      children: _amounts
          .map((amt) => OutlinedButton(
                onPressed: () => onSelect(amt),
                child: Text(amt == total ? 'ちょうど ¥$amt' : '¥$amt'),
              ))
          .toList(),
    );
  }
}
