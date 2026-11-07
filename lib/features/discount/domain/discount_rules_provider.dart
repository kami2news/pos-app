import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/discount_rule.dart';
import '../../../core/network/api_service.dart';

final discountRulesProvider =
    StateNotifierProvider<DiscountRulesNotifier, List<DiscountRule>>((ref) {
  return DiscountRulesNotifier(ref);
});

class DiscountRulesNotifier extends StateNotifier<List<DiscountRule>> {
  final Ref _ref;
  DiscountRulesNotifier(this._ref) : super([]);

  ApiService get _api => _ref.read(apiServiceProvider);

  // ── APIからルールを読み込む（ログイン後・画面オープン時に呼ぶ）──
  Future<void> loadRules() async {
    try {
      final data = await _api.getDiscountRules();
      state = data.map(_fromMap).toList();
    } catch (e) {
      debugPrint('[DiscountRules] loadRules error: $e');
    }
  }

  // ── ルール追加（APIに送信してからstateを更新）──
  Future<void> add(DiscountRule rule) async {
    try {
      final data = await _api.createDiscountRule(_toMap(rule));
      state = [...state, _fromMap(data)];
    } catch (e) {
      debugPrint('[DiscountRules] add error: $e');
    }
  }

  // ── ルール削除 ──
  Future<void> remove(String id) async {
    // 楽観的更新（UIを即反映）
    state = state.where((r) => r.id != id).toList();
    try {
      await _api.deleteDiscountRule(id);
    } catch (e) {
      debugPrint('[DiscountRules] remove error: $e');
      // 失敗時は再読み込み
      await loadRules();
    }
  }

  // ── ルール更新 ──
  Future<void> update(DiscountRule rule) async {
    state = state.map((r) => r.id == rule.id ? rule : r).toList();
    try {
      await _api.updateDiscountRule(rule.id, _toMap(rule));
    } catch (e) {
      debugPrint('[DiscountRules] update error: $e');
      await loadRules();
    }
  }

  // ── ON/OFF トグル ──
  Future<void> toggleActive(String id) async {
    final rule = state.firstWhere((r) => r.id == id);
    await update(rule.copyWith(isActive: !rule.isActive));
  }

  // ── Flutter DiscountRule ↔ API Map 変換 ──
  static DiscountRule _fromMap(Map<String, dynamic> m) {
    final condType = switch (m['condition_type'] as String? ?? '') {
      'productCombo'       => ConditionType.productCombo,
      'quantityThreshold'  => ConditionType.quantityThreshold,
      _                    => ConditionType.amountThreshold,
    };
    final discType = (m['discount_type'] as String? ?? '') == 'percentage'
        ? DiscountType.percentage
        : DiscountType.fixedAmount;

    final rawIds = m['target_product_ids'];
    final ids = rawIds is List
        ? List<String>.from(rawIds.map((e) => e.toString()))
        : <String>[];

    return DiscountRule(
      id:               m['id'] as String,
      name:             m['name'] as String,
      isActive:         m['is_active'] as bool? ?? true,
      conditionType:    condType,
      targetProductIds: ids,
      minQuantity:      (m['min_quantity'] as num? ?? 2).toInt(),
      minAmount:        (m['min_amount'] as num? ?? 1000).toInt(),
      discountType:     discType,
      discountValue:    (m['discount_value'] as num).toInt(),
    );
  }

  static Map<String, dynamic> _toMap(DiscountRule r) => {
    'name':               r.name,
    'is_active':          r.isActive,
    'condition_type':     switch (r.conditionType) {
      ConditionType.productCombo      => 'productCombo',
      ConditionType.quantityThreshold => 'quantityThreshold',
      ConditionType.amountThreshold   => 'amountThreshold',
    },
    'target_product_ids': r.targetProductIds,
    'min_quantity':       r.minQuantity,
    'min_amount':         r.minAmount,
    'discount_type':      r.discountType == DiscountType.percentage
        ? 'percentage'
        : 'fixedAmount',
    'discount_value':     r.discountValue,
  };
}
