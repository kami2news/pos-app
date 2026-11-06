import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/order_provider.dart';
import '../domain/models/order_model.dart';

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
          .showSnackBar(const SnackBar(content: Text('支払い方法を選択してください')));
      return;
    }
    if (_method == PaymentMethod.cash) {
      final change = _change(order.totalAmount);
      if (_received < order.totalAmount) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('受取金額が合計金額を下回っています')));
        return;
      }
      // お釣り確認ダイアログ
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('現金精算の確認'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _ConfirmRow(
                label: '合計', value: '¥${order.totalAmount}', bold: true),
            _ConfirmRow(label: '受取', value: '¥$_received'),
            const Divider(),
            _ConfirmRow(
              label: 'お釣り',
              value: '¥$change',
              bold: true,
              color: Colors.orange[800],
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('戻る')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('精算完了')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _processing = true);

    if (_withHandover) {
      // 精算＋お渡しモード：支払済み・お渡し待ちへ
      ref.read(orderListProvider.notifier).readyOrderForPickup(
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
      builder: (ctx) => AlertDialog(
        title: Text(
          isHandoverMode ? '支払い完了' : '精算完了',
          textAlign: TextAlign.center,
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isHandoverMode ? Icons.inventory_2 : Icons.check_circle,
            color: isHandoverMode ? const Color(0xFF2563EB) : Colors.green,
            size: 48,
          ),
          const SizedBox(height: 12),

          // ─── 整理番号（大きく表示） ───
          const Text('整理番号',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            order.orderNumber,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: isHandoverMode
                  ? const Color(0xFF2563EB)
                  : Theme.of(ctx).colorScheme.primary,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 8),
          Text('¥${order.totalAmount}',
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),

          // お釣り（現金の場合）
          if (_method == PaymentMethod.cash && _change(order.totalAmount) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('お釣り',
                        style: TextStyle(color: Colors.orange, fontSize: 13)),
                    const SizedBox(width: 12),
                    Text('¥${_change(order.totalAmount)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800])),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 6),
          Text(
            _method == PaymentMethod.cash ? '現金' : 'カード',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          // お渡しモード時のガイドテキスト
          if (isHandoverMode) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: const Text(
                '注文確認画面からお渡し完了を押してください',
                style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: isHandoverMode
            // お渡しモード：注文確認画面へ誘導
            ? [
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/orders/status');
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 44),
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                  child: const Text('注文確認画面へ'),
                ),
              ]
            // 精算のみモード：次の注文 or 注文状況
            : [
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/orders/status');
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 44),
                  ),
                  child: const Text('注文状況へ'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/orders');
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 44),
                  ),
                  child: const Text('次の注文'),
                ),
              ],
      ),
    );
  }

  // ─── キャンセル ───
  void _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注文をキャンセルしますか？'),
        content: const Text('この操作は取り消せません。'),
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
    if (ok != true) return;

    ref.read(orderListProvider.notifier).cancelOrder(widget.orderId);
    if (!context.mounted) return;
    context.go('/orders/status');
  }

  @override
  Widget build(BuildContext context) {
    // サーバーからの再取得が完了するまでローディングを表示
    if (_initializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('レジ精算')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final orders = ref.watch(orderListProvider);
    final order = orders
        .cast<OrderModel?>()
        .firstWhere((o) => o?.id == widget.orderId, orElse: () => null);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('レジ精算')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('注文が見つかりません'),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => context.go('/orders/status'),
                child: const Text('注文状況に戻る')),
          ]),
        ),
      );
    }

    // 既に完了 or キャンセル済み
    if (!order.isPending) {
      return Scaffold(
        appBar: AppBar(title: const Text('レジ精算')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              order.isCompleted ? Icons.check_circle : Icons.cancel,
              size: 56,
              color: order.isCompleted ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              order.isCompleted ? 'この注文は精算済みです' : 'この注文はキャンセル済みです',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () => context.go('/orders/status'),
                child: const Text('注文状況に戻る')),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('レジ精算  #${order.orderNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/orders/status'),
        ),
        actions: [
          TextButton(
            onPressed: _processing ? null : () => _cancel(context),
            style: TextButton.styleFrom(foregroundColor: Colors.red[300]),
            child: const Text('キャンセル'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── 注文内容 ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── 精算モード切替 ───
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('精算のみ'),
                        icon: Icon(Icons.check_circle_outline),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('精算＋お渡し'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                    ],
                    selected: {_withHandover},
                    onSelectionChanged: (s) =>
                        setState(() => _withHandover = s.first),
                    style: const ButtonStyle(
                      iconSize: WidgetStatePropertyAll(16),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _withHandover ? '支払い後に注文確認画面でお渡し完了を押します' : '支払いと同時に完了になります',
                    style: TextStyle(
                        fontSize: 11,
                        color: _withHandover
                            ? const Color(0xFF2563EB)
                            : Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // 商品リスト
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('注文内容',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          ...order.items.map((item) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  Expanded(child: Text(item.productName)),
                                  Text('× ${item.quantity}',
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                  const SizedBox(width: 16),
                                  Text('¥${item.subtotal}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ]),
                              )),
                          if (order.discountAmount > 0) ...[
                            const Divider(height: 16),
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
                                  style: const TextStyle(color: Colors.red)),
                            ]),
                          ],
                          const Divider(height: 16),
                          Row(children: [
                            const Text('合計',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            Text('¥${order.totalAmount}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 22)),
                          ]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── 支払い方法 ───
                  const Text('支払い方法',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _PaymentMethodCard(
                        icon: Icons.payments_outlined,
                        label: '現金',
                        selected: _method == PaymentMethod.cash,
                        onTap: () => setState(() {
                          _method = PaymentMethod.cash;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PaymentMethodCard(
                        icon: Icons.credit_card,
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
                    const SizedBox(height: 16),
                    const Text('受取金額',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),

                    // クイック金額ボタン
                    _QuickAmountRow(
                      total: order.totalAmount,
                      onSelect: (v) => setState(() {
                        _receivedCtrl.text = v.toString();
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _receivedCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '受取金額（円）',
                        prefixText: '¥',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    // リアルタイムお釣り表示
                    if (_received > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _change(order.totalAmount) >= 0
                              ? Colors.orange[50]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _change(order.totalAmount) >= 0
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _change(order.totalAmount) >= 0 ? 'お釣り' : '不足',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _change(order.totalAmount) >= 0
                                    ? Colors.orange[800]
                                    : Colors.red,
                              ),
                            ),
                            Text(
                              '¥${_change(order.totalAmount).abs()}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _change(order.totalAmount) >= 0
                                    ? Colors.orange[800]
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 80), // FABのスペース
                ],
              ),
            ),
          ),
        ],
      ),

      // ─── 精算ボタン ───
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: (_method == null || _processing)
                ? null
                : () => _complete(context, order),
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _withHandover
                  ? (_method == PaymentMethod.card ? 'カードで支払い完了' : '現金で支払い完了')
                  : (_method == PaymentMethod.card ? 'カードで精算完了' : '現金で精算完了'),
              style: const TextStyle(fontSize: 16),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
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
  final Color? color;
  const _ConfirmRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 14,
                  color: color)),
        ]),
      );
}

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
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: selected ? color : Colors.grey[500]),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? color : Colors.grey[600])),
          ],
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
      spacing: 8,
      runSpacing: 6,
      children: _amounts
          .map((amt) => OutlinedButton(
                onPressed: () => onSelect(amt),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  amt == total ? 'ちょうど ¥$amt' : '¥$amt',
                  style: const TextStyle(fontSize: 13),
                ),
              ))
          .toList(),
    );
  }
}
