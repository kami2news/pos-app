import 'order_item.dart';

/// 注文ステータス
/// pending         : 注文済み・未精算
/// readyForPickup  : 支払い済み・商品お渡し前
/// completed       : 精算＆お渡し完了
/// cancelled       : キャンセル
enum OrderStatus { pending, readyForPickup, completed, cancelled }

/// 支払い方法
enum PaymentMethod { cash, card }

class OrderModel {
  final String id;
  final String orderNumber;
  final List<OrderItem> items;
  final int subtotal; // 割引前の小計
  final int discountAmount; // 割引額（0以上）
  final int totalAmount; // 最終合計（subtotal - discountAmount）
  final DateTime orderedAt;
  final OrderStatus status;
  final PaymentMethod? paymentMethod;
  final int? receivedAmount; // 現金受取額（現金支払い時）

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.orderedAt,
    this.status = OrderStatus.completed, // 既存の addOrder は即完了
    this.paymentMethod,
    this.receivedAmount,
  });

  // ─── 便利なゲッター ───
  bool get isPending => status == OrderStatus.pending;
  bool get isReadyForPickup => status == OrderStatus.readyForPickup;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isCancelled => status == OrderStatus.cancelled;

  /// 支払い済み（readyForPickup または completed）
  bool get isPaid => isReadyForPickup || isCompleted;

  /// 現金のお釣り（現金支払い時のみ正値）
  int get change => paymentMethod == PaymentMethod.cash
      ? (receivedAmount ?? 0) - totalAmount
      : 0;

  /// ステータス・支払い情報だけを更新して新インスタンスを返す
  OrderModel copyWith({
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    int? receivedAmount,
  }) =>
      OrderModel(
        id: id,
        orderNumber: orderNumber,
        items: items,
        subtotal: subtotal,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        orderedAt: orderedAt,
        status: status ?? this.status,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        receivedAmount: receivedAmount ?? this.receivedAmount,
      );
}
