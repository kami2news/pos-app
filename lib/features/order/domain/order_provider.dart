import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/order_item.dart';
import 'models/order_model.dart';
import '../../discount/domain/models/discount_rule.dart';
import '../../discount/domain/discount_rules_provider.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../../core/network/api_service.dart';

// ─────────────────────────────────────
// 作成中の注文（カート）
// ─────────────────────────────────────
final currentOrderProvider =
    StateNotifierProvider<CurrentOrderNotifier, List<OrderItem>>((ref) {
  return CurrentOrderNotifier();
});

class CurrentOrderNotifier extends StateNotifier<List<OrderItem>> {
  CurrentOrderNotifier() : super([]);

  void addProduct({
    required String productId,
    required String productName,
    required int unitPrice,
  }) {
    final exists = state.any((i) => i.productId == productId);
    if (exists) {
      state = [
        for (final item in state)
          if (item.productId == productId)
            OrderItem(
              productId: item.productId,
              productName: item.productName,
              unitPrice: item.unitPrice,
              quantity: item.quantity + 1,
            )
          else
            item,
      ];
    } else {
      state = [
        ...state,
        OrderItem(
            productId: productId,
            productName: productName,
            unitPrice: unitPrice),
      ];
    }
  }

  void decreaseProduct(String productId) {
    state = state
        .map((i) => i.productId == productId
            ? OrderItem(
                productId: i.productId,
                productName: i.productName,
                unitPrice: i.unitPrice,
                quantity: i.quantity - 1,
              )
            : i)
        .where((i) => i.quantity > 0)
        .toList();
  }

  void clear() => state = [];

  int get subtotal => state.fold(0, (s, i) => s + i.subtotal);
}

// ─────────────────────────────────────
// 手動割引
// ─────────────────────────────────────
final manualDiscountProvider = StateProvider<int>((ref) => 0);

// ─────────────────────────────────────
// セット割の自動適用
// ─────────────────────────────────────

/// 適用されたルールとその割引額のペア
class AppliedDiscount {
  final DiscountRule rule;
  final int amount; // 実際の割引額（円）
  const AppliedDiscount({required this.rule, required this.amount});
}

/// セット割の自動計算結果
class AutoDiscountResult {
  final List<AppliedDiscount> applied;
  final int totalDiscount;
  const AutoDiscountResult(
      {required this.applied, required this.totalDiscount});
}

final autoDiscountProvider = Provider<AutoDiscountResult>((ref) {
  final cart = ref.watch(currentOrderProvider);
  final rules = ref.watch(discountRulesProvider);
  final subtotal = cart.fold(0, (s, i) => s + i.subtotal);

  final applied = <AppliedDiscount>[];
  int totalDiscount = 0;

  for (final rule in rules.where((r) => r.isActive)) {
    if (!_ruleApplies(rule, cart, subtotal)) continue;

    final discount = _calcDiscount(rule, subtotal);
    if (discount <= 0) continue;

    applied.add(AppliedDiscount(rule: rule, amount: discount));
    totalDiscount += discount;
  }

  // 小計を超えない
  totalDiscount = totalDiscount.clamp(0, subtotal);
  return AutoDiscountResult(applied: applied, totalDiscount: totalDiscount);
});

/// ルールが現在のカートに適用されるか判定
bool _ruleApplies(DiscountRule rule, List<OrderItem> cart, int subtotal) {
  switch (rule.conditionType) {
    case ConditionType.productCombo:
      if (rule.targetProductIds.length < 2) return false;
      return rule.targetProductIds
          .every((id) => cart.any((i) => i.productId == id));
    case ConditionType.amountThreshold:
      return subtotal >= rule.minAmount;
    case ConditionType.quantityThreshold:
      final totalItems = cart.fold(0, (s, i) => s + i.quantity);
      return totalItems >= rule.minQuantity;
  }
}

/// 割引額を計算
int _calcDiscount(DiscountRule rule, int subtotal) {
  switch (rule.discountType) {
    case DiscountType.fixedAmount:
      return rule.discountValue;
    case DiscountType.percentage:
      return (subtotal * rule.discountValue / 100).floor();
  }
}

// ─────────────────────────────────────
// 注文一覧
// ─────────────────────────────────────
final orderListProvider =
    StateNotifierProvider<OrderListNotifier, List<OrderModel>>((ref) {
  return OrderListNotifier(ref);
});

class OrderListNotifier extends StateNotifier<List<OrderModel>> {
  final Ref _ref;
  int _seq = 0;

  OrderListNotifier(this._ref) : super([]);

  ApiService get _api => _ref.read(apiServiceProvider);
  String get _businessDayId =>
      _ref.read(authStateProvider).businessDayId ?? '';

  // ── APIから当日注文を復元（ログイン時に呼ぶ）──
  Future<void> loadOrders() async {
    try {
      final data = await _api.getOrders();
      if (data.isEmpty) return;
      _seq = data.length; // 連番を現在の注文数に合わせる
      state = data.map((m) {
        final rawItems = (m['items'] as List? ?? []);
        final items = rawItems.map<OrderItem>((i) => OrderItem(
              productId: i['product_id'] as String? ?? '',
              productName: i['product_name'] as String? ?? '',
              unitPrice: (i['unit_price'] as num).toInt(),
              quantity: (i['quantity'] as num).toInt(),
            )).toList();
        return OrderModel(
          id: m['id'] as String,
          orderNumber: m['order_number'] as String,
          items: List.unmodifiable(items),
          subtotal: (m['subtotal'] as num).toInt(),
          discountAmount: (m['discount_amount'] as num? ?? 0).toInt(),
          manualDiscountAmount: (m['manual_discount_amount'] as num? ?? 0).toInt(),
          totalAmount: (m['total_amount'] as num).toInt(),
          orderedAt: DateTime.parse(m['ordered_at'] as String).toLocal(),
          status: _statusFrom(m['status'] as String? ?? 'pending'),
          paymentMethod: _paymentFrom(m['payment_method']),
          receivedAmount: m['received_amount'] as int?,
        );
      }).toList();
    } catch (e) {
      // ロード失敗は無視（既存 state を維持）
      debugPrint('[OrderProvider] loadOrders error: $e');
    }
  }

  static OrderStatus _statusFrom(String s) => switch (s) {
        'completed'      => OrderStatus.completed,
        'readyForPickup' => OrderStatus.readyForPickup,
        'cancelled'      => OrderStatus.cancelled,
        _                => OrderStatus.pending,
      };

  static PaymentMethod? _paymentFrom(dynamic s) => switch (s) {
        'cash' => PaymentMethod.cash,
        'card' => PaymentMethod.card,
        _      => null,
      };

  // ── 保留注文を登録（注文登録画面から利用）──
  // API 完了後にサーバー発行の ID を返す。
  // 失敗時は tempId を返してローカル動作を継続する。
  Future<String> addPending(
      List<OrderItem> items, int subtotal, int discountAmount,
      {int manualDiscountAmount = 0}) async {
    _seq++;
    final number = _seq.toString().padLeft(3, '0');
    final total = max(0, subtotal - discountAmount);
    final tempId = 'tmp-${DateTime.now().millisecondsSinceEpoch}';

    // 1. 即座に state を更新（呼び出し元はこの時点で orderNumber を読める）
    state = [
      ...state,
      OrderModel(
        id: tempId,
        orderNumber: number,
        items: List.unmodifiable(items),
        subtotal: subtotal,
        discountAmount: discountAmount,
        manualDiscountAmount: manualDiscountAmount,
        totalAmount: total,
        orderedAt: DateTime.now(),
        status: OrderStatus.pending,
      ),
    ];

    // 2. API に注文を送信してサーバー ID を取得
    try {
      final data = await _api.createOrder(
        businessDayId: _businessDayId,
        items: items
            .map((i) => {
                  'product_id': i.productId,
                  'product_name': i.productName,
                  'unit_price': i.unitPrice,
                  'quantity': i.quantity,
                })
            .toList(),
        subtotal: subtotal,
        discountAmount: discountAmount,
        manualDiscountAmount: manualDiscountAmount,
        totalAmount: total,
      );
      final serverId = data['id'] as String;
      final serverNum = data['order_number'] as String? ?? number;
      // temp ID → サーバー ID に差し替え
      state = [
        for (final o in state)
          if (o.id == tempId)
            OrderModel(
              id: serverId,
              orderNumber: serverNum,
              items: o.items,
              subtotal: o.subtotal,
              discountAmount: o.discountAmount,
              manualDiscountAmount: o.manualDiscountAmount,
              totalAmount: o.totalAmount,
              orderedAt: o.orderedAt,
              status: OrderStatus.pending,
            )
          else
            o,
      ];
      return serverId; // ← 確定したサーバーIDを返す
    } catch (_) {
      // API 失敗: ローカルの temp ID で動作継続
      return tempId;
    }
  }

  // ── 精算完了（精算のみモード）──
  void completeOrder(String id, PaymentMethod method, {int? receivedAmount}) {
    state = [
      for (final o in state)
        if (o.id == id)
          o.copyWith(
            status: OrderStatus.completed,
            paymentMethod: method,
            receivedAmount: receivedAmount,
          )
        else
          o,
    ];
    final methodStr = method == PaymentMethod.cash ? 'cash' : 'card';
    _api.completeOrder(id, methodStr, receivedAmount).catchError((e) {
      debugPrint('[OrderProvider] completeOrder error: $e');
      loadOrders(); // サーバー状態でUIを修正
    });
  }

  // ── 支払い済み・お渡し待ち（精算＋お渡しモード）──
  void readyOrderForPickup(String id, PaymentMethod method,
      {int? receivedAmount}) {
    state = [
      for (final o in state)
        if (o.id == id)
          o.copyWith(
            status: OrderStatus.readyForPickup,
            paymentMethod: method,
            receivedAmount: receivedAmount,
          )
        else
          o,
    ];
    final methodStr = method == PaymentMethod.cash ? 'cash' : 'card';
    _api.readyOrder(id, methodStr, receivedAmount).catchError((e) {
      debugPrint('[OrderProvider] readyOrderForPickup error: $e');
      loadOrders(); // サーバー状態でUIを修正
    });
  }

  // ── お渡し完了（注文確認画面から利用）──
  void handoverOrder(String id) {
    state = [
      for (final o in state)
        if (o.id == id) o.copyWith(status: OrderStatus.completed) else o,
    ];
    _api.handoverOrder(id).catchError((e) {
      debugPrint('[OrderProvider] handoverOrder error: $e');
      loadOrders(); // サーバー状態でUIを修正
    });
  }

  // ── キャンセル ──
  void cancelOrder(String id) {
    state = [
      for (final o in state)
        if (o.id == id) o.copyWith(status: OrderStatus.cancelled) else o,
    ];
    _api.cancelOrder(id).catchError((e) {
      debugPrint('[OrderProvider] cancelOrder error: $e');
      loadOrders(); // サーバー状態でUIを修正
    });
  }

  void reset() {
    state = [];
    _seq = 0;
  }
}

// ─────────────────────────────────────
// 待機中注文（精算前）
// ─────────────────────────────────────
final pendingOrdersProvider = Provider<List<OrderModel>>(
    (ref) => ref.watch(orderListProvider).where((o) => o.isPending).toList());

final pendingCountProvider =
    Provider<int>((ref) => ref.watch(pendingOrdersProvider).length);

// お渡し待ち注文（支払済・お渡し前）
final readyForPickupOrdersProvider = Provider<List<OrderModel>>((ref) =>
    ref.watch(orderListProvider).where((o) => o.isReadyForPickup).toList());

final readyForPickupCountProvider =
    Provider<int>((ref) => ref.watch(readyForPickupOrdersProvider).length);

// ─────────────────────────────────────
// 販売総数の集計（完了分のみ）
// ─────────────────────────────────────
final productSalesProvider = Provider<Map<String, int>>((ref) {
  final orders = ref.watch(orderListProvider).where((o) => o.isCompleted);
  final map = <String, int>{};
  for (final order in orders) {
    for (final item in order.items) {
      map[item.productName] = (map[item.productName] ?? 0) + item.quantity;
    }
  }
  return map;
});

final totalSoldProvider = Provider<int>(
    (ref) => ref.watch(productSalesProvider).values.fold(0, (s, q) => s + q));

// ─────────────────────────────────────
// 締め集計用：商品別売上明細（数量＋金額）
// ─────────────────────────────────────
class ProductSaleDetail {
  final String name;
  final int unitPrice;      // 実効単価（手動割引按分後）
  final int quantity;
  final int discountPerItem; // 1個あたりの手動割引額（0 = 通常価格）
  int get amount => unitPrice * quantity;
  const ProductSaleDetail({
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.discountPerItem = 0,
  });
}

final productSaleDetailsProvider = Provider<List<ProductSaleDetail>>((ref) {
  final orders = ref.watch(orderListProvider).where((o) => o.isCompleted);
  // key: 'name|effectiveUnitPrice'
  final map = <String, ProductSaleDetail>{};
  for (final order in orders) {
    for (final item in order.items) {
      // 手動割引がある場合、按分して実効単価を計算
      int effectiveUnitPrice;
      int discountPerItem;
      if (order.manualDiscountAmount > 0 && order.subtotal > 0) {
        effectiveUnitPrice =
            (item.unitPrice *
                    (order.subtotal - order.manualDiscountAmount) /
                    order.subtotal)
                .round();
        discountPerItem = item.unitPrice - effectiveUnitPrice;
      } else {
        effectiveUnitPrice = item.unitPrice;
        discountPerItem = 0;
      }

      final key = '${item.productName}|$effectiveUnitPrice';
      final existing = map[key];
      if (existing != null) {
        map[key] = ProductSaleDetail(
          name: item.productName,
          unitPrice: effectiveUnitPrice,
          quantity: existing.quantity + item.quantity,
          discountPerItem: discountPerItem,
        );
      } else {
        map[key] = ProductSaleDetail(
          name: item.productName,
          unitPrice: effectiveUnitPrice,
          quantity: item.quantity,
          discountPerItem: discountPerItem,
        );
      }
    }
  }
  return map.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
});

// ─────────────────────────────────────
// 締め集計用：割引内訳（自動 / 手動）
// ─────────────────────────────────────
class DiscountSummary {
  final int autoDiscount;
  final int manualDiscount;
  int get total => autoDiscount + manualDiscount;
  const DiscountSummary({required this.autoDiscount, required this.manualDiscount});
}

final discountSummaryProvider = Provider<DiscountSummary>((ref) {
  final orders = ref.watch(orderListProvider).where((o) => o.isCompleted);
  int manual = 0, total = 0;
  for (final o in orders) {
    total  += o.discountAmount;
    manual += o.manualDiscountAmount;
  }
  return DiscountSummary(
    autoDiscount:   total - manual,
    manualDiscount: manual,
  );
});

