import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_service.dart';

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

  // テーマカラーは注文画面から GoRouter extras で渡せないため、
  // ここではデフォルト値を使い、必要に応じて拡張する
  final Color _themeColor = const Color(0xFF1456A0);

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
        _error ??= 'ステータス取得中...';
      });
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
          title: const Text('整理番号'),
          automaticallyImplyLeading: false,
          elevation: 0,
          actions: [
            TextButton.icon(
              onPressed: () =>
                  context.go('/customer/${widget.storeCode}'),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
              label: const Text('注文に戻る',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_order == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('注文情報を取得できませんでした',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _fetchOrder();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    final order = _order!;
    final orderNumber = order['order_number'] as String? ?? '---';
    final status = order['status'] as String? ?? 'pending';
    final items =
        List<Map<String, dynamic>>.from(order['items'] as List? ?? []);
    final totalAmount = order['total_amount'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 整理番号カード ──
          _NumberCard(
              orderNumber: orderNumber, themeColor: _themeColor),
          const SizedBox(height: 20),

          // ── ステータスカード ──
          _StatusCard(status: status),
          const SizedBox(height: 20),

          // ── 注文内容 ──
          _OrderItemsCard(
              items: items, totalAmount: totalAmount, themeColor: _themeColor),
        ],
      ),
    );
  }
}

// ─── 整理番号カード ───────────────────────────────────────────
class _NumberCard extends StatelessWidget {
  final String orderNumber;
  final Color themeColor;

  const _NumberCard({required this.orderNumber, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '整理番号',
            style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            orderNumber,
            style: const TextStyle(
              fontSize: 80,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ステータスカード ─────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final String status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(config.icon, color: config.iconColor, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                config.label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: config.textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                config.description,
                style: TextStyle(
                    fontSize: 13, color: config.textColor.withOpacity(0.75)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _StatusConfig _statusConfig(String status) {
    switch (status) {
      case 'pending':
        return _StatusConfig(
          label: '準備中',
          description: '店舗スタッフが準備しています',
          icon: Icons.hourglass_top_rounded,
          bgColor: const Color(0xFFFFF3E0),
          borderColor: const Color(0xFFFFB74D),
          iconColor: const Color(0xFFF57C00),
          textColor: const Color(0xFFE65100),
        );
      case 'readyForPickup':
        return _StatusConfig(
          label: 'お呼び出し中',
          description: '受取カウンターにお越しください！',
          icon: Icons.notifications_active_rounded,
          bgColor: const Color(0xFFE8F5E9),
          borderColor: const Color(0xFF66BB6A),
          iconColor: const Color(0xFF388E3C),
          textColor: const Color(0xFF1B5E20),
        );
      case 'completed':
        return _StatusConfig(
          label: 'お渡し済み',
          description: 'ありがとうございました！',
          icon: Icons.check_circle_rounded,
          bgColor: const Color(0xFFF5F5F5),
          borderColor: const Color(0xFFBDBDBD),
          iconColor: const Color(0xFF757575),
          textColor: const Color(0xFF424242),
        );
      case 'cancelled':
        return _StatusConfig(
          label: 'キャンセル',
          description: '店舗スタッフにお問い合わせください',
          icon: Icons.cancel_rounded,
          bgColor: const Color(0xFFFFEBEE),
          borderColor: const Color(0xFFEF9A9A),
          iconColor: const Color(0xFFC62828),
          textColor: const Color(0xFFB71C1C),
        );
      default:
        return _StatusConfig(
          label: '確認中',
          description: 'ステータスを取得しています...',
          icon: Icons.sync_rounded,
          bgColor: const Color(0xFFF5F5F5),
          borderColor: const Color(0xFFBDBDBD),
          iconColor: const Color(0xFF757575),
          textColor: const Color(0xFF616161),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final String description;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;

  const _StatusConfig({
    required this.label,
    required this.description,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
  });
}

// ─── 注文内容カード ──────────────────────────────────────────
class _OrderItemsCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int totalAmount;
  final Color themeColor;

  const _OrderItemsCard({
    required this.items,
    required this.totalAmount,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              '注文内容',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isLast = i == items.length - 1;
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['product_name'] as String? ?? '',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text('× ${item['quantity']}',
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey.shade600)),
                      const SizedBox(width: 10),
                      Text(
                          '¥${(item['unit_price'] as int? ?? 0) * (item['quantity'] as int? ?? 1)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            );
          }),
          const Divider(height: 1),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Expanded(
                    child: Text('合計',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))),
                Text('¥$totalAmount',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
