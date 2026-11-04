import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/discount_rule.dart';

final discountRulesProvider =
    StateNotifierProvider<DiscountRulesNotifier, List<DiscountRule>>((ref) {
  return DiscountRulesNotifier();
});

class DiscountRulesNotifier extends StateNotifier<List<DiscountRule>> {
  DiscountRulesNotifier()
      : super([
          // サンプルルール（削除してOK）
          const DiscountRule(
            id: 'sample-1',
            name: 'ドリンク＋フード セット割',
            conditionType: ConditionType.productCombo,
            targetProductIds: ['d1', 'd2'], // コーヒー＋ケーキ
            discountType: DiscountType.fixedAmount,
            discountValue: 100,
          ),
          const DiscountRule(
            id: 'sample-2',
            name: '3個以上まとめ買い割引',
            conditionType: ConditionType.quantityThreshold,
            targetProductIds: [], // 全商品対象
            minQuantity: 3,
            discountType: DiscountType.percentage,
            discountValue: 10,
          ),
        ]);

  void add(DiscountRule rule) => state = [...state, rule];

  void remove(String id) => state = state.where((r) => r.id != id).toList();

  void update(DiscountRule rule) =>
      state = state.map((r) => r.id == rule.id ? rule : r).toList();

  void toggleActive(String id) => state = state
      .map((r) => r.id == id ? r.copyWith(isActive: !r.isActive) : r)
      .toList();
}
