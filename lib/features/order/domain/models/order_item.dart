/// 注文明細（1商品あたり）
class OrderItem {
  final String productId;
  final String productName;
  final int unitPrice;
  int quantity;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
  });

  /// 小計（int同士・double禁止）
  int get subtotal => unitPrice * quantity;
}
