/// セット割ルールの条件種別
enum ConditionType {
  productCombo, // 商品の組み合わせ（A＋B）
  quantityThreshold, // 数量条件（N個以上）
  amountThreshold, // 合計金額条件（○円以上）
}

/// 割引の種別
enum DiscountType {
  fixedAmount, // 固定額（円）
  percentage, // 割合（%）
}

/// セット割ルール（純粋なデータクラス）
class DiscountRule {
  final String id;
  final String name;
  final bool isActive;

  // ─── 条件 ───
  final ConditionType conditionType;

  /// productCombo: 全商品が揃うと発動
  /// quantityThreshold: 対象商品の合計数がminQuantity以上で発動
  ///   （空リストなら「全商品の合計」）
  final List<String> targetProductIds;

  /// quantityThreshold で使用（何個以上か）
  final int minQuantity;

  /// amountThreshold で使用（小計が何円以上か）
  final int minAmount;

  // ─── 割引 ───
  final DiscountType discountType;
  final int discountValue; // 円 or %

  const DiscountRule({
    required this.id,
    required this.name,
    this.isActive = true,
    required this.conditionType,
    this.targetProductIds = const [],
    this.minQuantity = 2,
    this.minAmount = 1000,
    required this.discountType,
    required this.discountValue,
  });

  DiscountRule copyWith({
    String? id,
    String? name,
    bool? isActive,
    ConditionType? conditionType,
    List<String>? targetProductIds,
    int? minQuantity,
    int? minAmount,
    DiscountType? discountType,
    int? discountValue,
  }) =>
      DiscountRule(
        id: id ?? this.id,
        name: name ?? this.name,
        isActive: isActive ?? this.isActive,
        conditionType: conditionType ?? this.conditionType,
        targetProductIds: targetProductIds ?? this.targetProductIds,
        minQuantity: minQuantity ?? this.minQuantity,
        minAmount: minAmount ?? this.minAmount,
        discountType: discountType ?? this.discountType,
        discountValue: discountValue ?? this.discountValue,
      );
}
