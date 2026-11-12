import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/km1.dart';

/// 注文者モード：商品選択画面
/// QRコードから認証なしでアクセス → /customer/:storeCode
class CustomerOrderScreen extends StatefulWidget {
  final String storeCode;
  const CustomerOrderScreen({super.key, required this.storeCode});

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  bool _loading = true;
  String? _error;
  String _storeName = '';
  int? _storeColor; // 店舗の分類色（上部バーの下の帯）
  bool _isOpen = false;
  List<Map<String, dynamic>> _products = [];
  final Map<String, int> _quantities = {}; // productId → 数量
  bool _ordering = false;

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    try {
      final data = await ApiService().getPublicStoreInfo(widget.storeCode);
      final rawColor = data['theme_color'] as int? ?? 1333408;
      if (!mounted) return;
      setState(() {
        _storeName = data['store_name'] as String? ?? '';
        _storeColor = 0xFF000000 | (rawColor & 0xFFFFFF);
        _isOpen = data['is_open'] as bool? ?? false;
        _products = List<Map<String, dynamic>>.from(
            data['products'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '店舗の情報を読み込めませんでした。QR コードを読み直すか、スタッフにお声がけください。';
        _loading = false;
      });
    }
  }

  int get _subtotal => _products.fold(0, (sum, p) {
        final qty = _quantities[p['id'] as String? ?? ''] ?? 0;
        return sum + (p['price'] as int? ?? 0) * qty;
      });

  bool get _hasItems => _quantities.values.any((q) => q > 0);

  List<Map<String, dynamic>> get _cartItems => _products
      .where((p) => (_quantities[p['id'] as String? ?? ''] ?? 0) > 0)
      .map((p) => {
            'product_id': p['id'] as String,
            'product_name': p['name'] as String,
            'unit_price': p['price'] as int,
            'quantity': _quantities[p['id'] as String]!,
          })
      .toList();

  Future<void> _onOrderPressed() async {
    if (!_hasItems) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        items: _cartItems,
        subtotal: _subtotal,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _ordering = true);
    try {
      final order = await ApiService().createPublicOrder(
        widget.storeCode,
        items: _cartItems,
        subtotal: _subtotal,
        discountAmount: 0,
        totalAmount: _subtotal,
      );
      if (!mounted) return;
      final orderId = order['id'] as String;
      context.go('/customer/${widget.storeCode}/number/$orderId');
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['error'] as String? ?? 'ご注文を送信できませんでした。もう一度お試しください。';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ご注文を送信できませんでした。もう一度お試しください。')));
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_storeName.isEmpty ? 'ご注文' : _storeName),
        automaticallyImplyLeading: false,
        bottom: storeBand(_storeColor),
      ),
      body: _buildBody(),
      bottomNavigationBar: _isOpen && !_loading && _error == null
          ? _OrderBar(
              subtotal: _subtotal,
              hasItems: _hasItems,
              ordering: _ordering,
              onOrder: _onOrderPressed,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Km1Space.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Km1Size.dialogWidthSm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Km1Notice(
                    status: Km1Status.danger,
                    title: '読み込めませんでした',
                    body: _error),
                const SizedBox(height: Km1Space.lg),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadStoreInfo();
                  },
                  icon: const Icon(Km1Icons.refresh, size: Km1Size.iconMd),
                  label: const Text('もう一度読み込む'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_isOpen) {
      return const Km1Empty(
        icon: Km1Icons.store,
        title: 'ただいま注文を受け付けていません',
        body: '店舗のスタッフにお問い合わせください。',
      );
    }
    if (_products.isEmpty) {
      return const Km1Empty(
        icon: Km1Icons.product,
        title: '商品が登録されていません',
        body: '店舗のスタッフにお問い合わせください。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: Km1Space.sm),
      itemCount: _products.length,
      separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: Km1Space.lg,
          endIndent: Km1Space.lg,
          color: context.km1.strokeSubtle),
      itemBuilder: (_, i) {
        final p = _products[i];
        final id = p['id'] as String;
        final qty = _quantities[id] ?? 0;
        return _ProductTile(
          name: p['name'] as String,
          price: p['price'] as int,
          quantity: qty,
          onDecrement: qty > 0
              ? () => setState(() => _quantities[id] = qty - 1)
              : null,
          onIncrement: () => setState(() => _quantities[id] = qty + 1),
        );
      },
    );
  }
}

// ─── 商品行 ───────────────────────────────────────────────────
class _ProductTile extends StatelessWidget {
  final String name;
  final int price;
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _ProductTile({
    required this.name,
    required this.price,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    // お客様のスマートフォンで押しやすいよう、増減ボタンは 48px
    const big = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
          Size(Km1Size.controlLgTouch, Km1Size.controlLgTouch)),
      fixedSize: WidgetStatePropertyAll(
          Size(Km1Size.controlLgTouch, Km1Size.controlLgTouch)),
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Km1Space.lg, vertical: Km1Space.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Km1Text.subtitle1.copyWith(color: c.ink)),
                const SizedBox(height: Km1Space.xxs),
                Text('¥$price',
                    style: Km1Text.body2.copyWith(color: c.inkSecondary)),
              ],
            ),
          ),
          // 数量コントロール（大きめタップ）
          OutlinedButton(
            style: big,
            onPressed: onDecrement,
            child: Icon(Km1Icons.subtract,
                semanticLabel: '$nameを 1 つ減らす',
                color: onDecrement == null ? c.inkDisabled : c.ink),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$quantity',
              style: Km1Text.title3.copyWith(
                  color: c.ink,
                  fontFeatures: const [FontFeature.tabularFigures()]),
              textAlign: TextAlign.center,
            ),
          ),
          FilledButton(
            style: big,
            onPressed: onIncrement,
            child: Icon(Km1Icons.add,
                semanticLabel: '$nameを 1 つ増やす', color: c.onBrand),
          ),
        ],
      ),
    );
  }
}

// ─── 合計・注文ボタンバー ──────────────────────────────────────
class _OrderBar extends StatelessWidget {
  final int subtotal;
  final bool hasItems;
  final bool ordering;
  final VoidCallback onOrder;

  const _OrderBar({
    required this.subtotal,
    required this.hasItems,
    required this.ordering,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.strokeSubtle)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Km1Space.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('合計',
                        style: Km1Text.caption1.copyWith(color: c.inkSecondary)),
                    Text('¥$subtotal',
                        style: Km1Text.title2.copyWith(
                            color: c.ink,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ],
                ),
              ),
              FilledButton(
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(
                      Size(160, Km1Size.controlLgTouch)),
                  textStyle: WidgetStatePropertyAll(Km1Text.subtitle2),
                ),
                onPressed: (hasItems && !ordering) ? onOrder : null,
                child: Text(ordering ? '送信中' : '注文する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 確認ダイアログ ───────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int subtotal;

  const _ConfirmDialog({
    required this.items,
    required this.subtotal,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    const tabular = [FontFeature.tabularFigures()];
    return AlertDialog(
      title: const Text('ご注文の確認'),
      content: SizedBox(
        width: Km1Size.dialogWidthSm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: Km1Space.xs),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('${item['product_name']}',
                              style: Km1Text.body2.copyWith(color: c.ink))),
                      Text('× ${item['quantity']}',
                          style:
                              Km1Text.body2.copyWith(color: c.inkSecondary)),
                      const SizedBox(width: Km1Space.sm),
                      Text(
                          '¥${(item['unit_price'] as int) * (item['quantity'] as int)}',
                          style: Km1Text.body2
                              .copyWith(color: c.ink, fontFeatures: tabular)),
                    ],
                  ),
                )),
            Divider(height: Km1Space.xl, color: c.strokeSubtle),
            Row(
              children: [
                Expanded(
                    child: Text('合計',
                        style: Km1Text.subtitle2.copyWith(color: c.ink))),
                Text('¥$subtotal',
                    style: Km1Text.title3
                        .copyWith(color: c.ink, fontFeatures: tabular)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('戻って直す'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('注文する'),
        ),
      ],
    );
  }
}
