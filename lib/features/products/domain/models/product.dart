/// 商品モデル（税込・円単位）
class Product {
  final String id;
  final String name;
  final int price; // 税込・円・int必須（double禁止）
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.isActive = true,
  });

  Product copyWith({
    String? id,
    String? name,
    int? price,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
    );
  }
}
