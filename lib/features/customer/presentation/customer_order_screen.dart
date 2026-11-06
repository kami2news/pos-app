import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_service.dart';

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
  Color _themeColor = const Color(0xFF1456A0);
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
        _themeColor = Color(0xFF000000 | (rawColor & 0xFFFFFF));
        _isOpen = data['is_open'] as bool? ?? false;
        _products = List<Map<String, dynamic>>.from(
            data['products'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '読み込みに失敗しました\n通信状況を確認してください';
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
        themeColor: _themeColor,
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
      final msg = e.response?.data?['error'] as String? ?? '注文に失敗しました';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注文に失敗しました。もう一度お試しください')));
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _themeColor),
        useMaterial3: true,
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _themeColor,
          foregroundColor: Colors.white,
          title:
              Text(_storeName.isEmpty ? 'ご注文' : _storeName),
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        body: _buildBody(),
        bottomNavigationBar: _isOpen && !_loading && _error == null
            ? _OrderBar(
                subtotal: _subtotal,
                hasItems: _hasItems,
                ordering: _ordering,
                themeColor: _themeColor,
                onOrder: _onOrderPressed,
              )
            : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(_error!,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadStoreInfo();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_isOpen) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_mall_directory_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('現在受付中ではありません',
                style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('店舗スタッフにお問い合わせください',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
          child: Text('商品が登録されていません',
              style: TextStyle(color: Colors.grey.shade500)));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _products.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final p = _products[i];
        final id = p['id'] as String;
        final qty = _quantities[id] ?? 0;
        return _ProductTile(
          name: p['name'] as String,
          price: p['price'] as int,
          quantity: qty,
          themeColor: _themeColor,
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
  final Color themeColor;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _ProductTile({
    required this.name,
    required this.price,
    required this.quantity,
    required this.themeColor,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('¥$price',
                    style: TextStyle(
                        fontSize: 15,
                        color: themeColor,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // 数量コントロール（大きめタップ）
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CounterButton(
                icon: Icons.remove,
                onTap: onDecrement,
                color: quantity > 0 ? themeColor : Colors.grey.shade300,
                iconColor: quantity > 0 ? Colors.white : Colors.grey.shade400,
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$quantity',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              _CounterButton(
                icon: Icons.add,
                onTap: onIncrement,
                color: themeColor,
                iconColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color iconColor;

  const _CounterButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

// ─── 合計・注文ボタンバー ──────────────────────────────────────
class _OrderBar extends StatelessWidget {
  final int subtotal;
  final bool hasItems;
  final bool ordering;
  final Color themeColor;
  final VoidCallback onOrder;

  const _OrderBar({
    required this.subtotal,
    required this.hasItems,
    required this.ordering,
    required this.themeColor,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('合計',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Text(
                    '¥$subtotal',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: hasItems ? themeColor : Colors.grey.shade300,
                foregroundColor: Colors.white,
                minimumSize: const Size(140, 56),
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: (hasItems && !ordering) ? onOrder : null,
              child: ordering
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('注文する'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 確認ダイアログ ───────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int subtotal;
  final Color themeColor;

  const _ConfirmDialog({
    required this.items,
    required this.subtotal,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ご注文の確認'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                        child: Text('${item['product_name']}',
                            style: const TextStyle(fontSize: 15))),
                    Text('× ${item['quantity']}',
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey.shade600)),
                    const SizedBox(width: 8),
                    Text(
                        '¥${(item['unit_price'] as int) * (item['quantity'] as int)}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
              )),
          const Divider(height: 20),
          Row(
            children: [
              const Expanded(
                  child: Text('合計',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16))),
              Text('¥$subtotal',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('修正する'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: themeColor),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('注文する'),
        ),
      ],
    );
  }
}
