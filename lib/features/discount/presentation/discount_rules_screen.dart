import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../products/domain/models/product.dart';
import '../../products/domain/products_provider.dart';
import '../domain/models/discount_rule.dart';
import '../domain/discount_rules_provider.dart';

class DiscountRulesScreen extends ConsumerWidget {
  const DiscountRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(discountRulesProvider);
    final products = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('セット割設定'),
        backgroundColor: const Color(0xFF1456A0),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: rules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_offer_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('セット割ルールがまだありません',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showRuleDialog(context, ref, products),
                    icon: const Icon(Icons.add),
                    label: const Text('最初のルールを追加'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final rule = rules[i];
                return Card(
                  child: ListTile(
                    leading: Switch(
                      value: rule.isActive,
                      activeThumbColor: const Color(0xFF1456A0),
                      onChanged: (_) => ref
                          .read(discountRulesProvider.notifier)
                          .toggleActive(rule.id),
                    ),
                    // タイトル行：ルール名＋割引バッジ
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            rule.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: rule.isActive ? null : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: rule.isActive
                                ? const Color(0xFFE1F5EE)
                                : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _discountLabel(rule),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: rule.isActive
                                  ? const Color(0xFF085041)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      _conditionLabel(rule, products),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    // trailing：編集・削除アイコンのみ
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showRuleDialog(
                              context, ref, products,
                              existing: rule),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.red),
                          onPressed: () => _confirmDelete(context, ref, rule),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRuleDialog(context, ref, products),
        icon: const Icon(Icons.add),
        label: const Text('ルールを追加'),
        backgroundColor: const Color(0xFF1456A0),
        foregroundColor: Colors.white,
      ),
    );
  }

  String _conditionLabel(DiscountRule rule, List<Product> products) {
    switch (rule.conditionType) {
      case ConditionType.productCombo:
        final names = rule.targetProductIds
            .map((id) =>
                products
                    .where((p) => p.id == id)
                    .map((p) => p.name)
                    .firstOrNull ??
                id)
            .join(' ＋ ');
        return '組み合わせ: $names';
      case ConditionType.quantityThreshold:
        if (rule.targetProductIds.isEmpty) {
          return '合計${rule.minQuantity}個以上購入';
        }
        final names = rule.targetProductIds
            .map((id) =>
                products
                    .where((p) => p.id == id)
                    .map((p) => p.name)
                    .firstOrNull ??
                id)
            .join('・');
        return '$names を${rule.minQuantity}個以上';
      case ConditionType.amountThreshold:
        return '合計¥${rule.minAmount}以上で';
    }
  }

  String _discountLabel(DiscountRule rule) {
    if (rule.discountType == DiscountType.percentage) {
      return '${rule.discountValue}% OFF';
    }
    return '¥${rule.discountValue} OFF';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DiscountRule rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${rule.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(discountRulesProvider.notifier).remove(rule.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showRuleDialog(
      BuildContext context, WidgetRef ref, List<Product> products,
      {DiscountRule? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _RuleDialog(
        products: products,
        existing: existing,
        onSave: (rule) {
          if (existing == null) {
            ref.read(discountRulesProvider.notifier).add(rule);
          } else {
            ref.read(discountRulesProvider.notifier).update(rule);
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────
// ルール追加・編集ダイアログ
// ─────────────────────────────────────
class _RuleDialog extends StatefulWidget {
  final List<Product> products;
  final DiscountRule? existing;
  final void Function(DiscountRule rule) onSave;

  const _RuleDialog({
    required this.products,
    required this.onSave,
    this.existing,
  });

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  late ConditionType _condType;
  late DiscountType _discType;
  final Set<String> _selectedProductIds = {};
  String? _qtyTargetId; // null = 全商品

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _nameCtrl.text = r.name;
      _valueCtrl.text = '${r.discountValue}';
      _amountCtrl.text = '${r.minAmount}';
      _qtyCtrl.text = '${r.minQuantity}';
      _condType = r.conditionType;
      _discType = r.discountType;
      _selectedProductIds.addAll(r.targetProductIds);
      _qtyTargetId =
          r.targetProductIds.isNotEmpty ? r.targetProductIds.first : null;
    } else {
      _condType = ConditionType.productCombo;
      _discType = DiscountType.fixedAmount;
      _qtyCtrl.text = '2';
      _amountCtrl.text = '1000';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _amountCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'ルールを追加' : 'ルールを編集'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ルール名 ──
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'ルール名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),

            // ── 条件種別 ──
            const Text('条件の種類',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            RadioGroup<ConditionType>(
              groupValue: _condType,
              onChanged: (v) => setState(() => _condType = v!),
              child: Column(
                children: ConditionType.values
                    .map(
                      (t) => RadioListTile<ConditionType>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_condTypeName(t),
                            style: const TextStyle(fontSize: 13)),
                        value: t,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),

            // ── 条件の詳細（種別ごとに変化） ──
            _buildConditionDetail(),
            const SizedBox(height: 18),

            // ── 割引種別・金額 ──
            const Text('割引の内容',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              ChoiceChip(
                label: const Text('金額（円）'),
                selected: _discType == DiscountType.fixedAmount,
                onSelected: (_) =>
                    setState(() => _discType = DiscountType.fixedAmount),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('割合（%）'),
                selected: _discType == DiscountType.percentage,
                onSelected: (_) =>
                    setState(() => _discType = DiscountType.percentage),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _valueCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _discType == DiscountType.percentage
                    ? '割引率（例: 10）'
                    : '割引額（例: 200）',
                prefixText: _discType == DiscountType.fixedAmount ? '¥' : null,
                suffixText: _discType == DiscountType.percentage ? '%' : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildConditionDetail() {
    switch (_condType) {
      // ── 商品コンビ ──
      case ConditionType.productCombo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('組み合わせる商品を2つ以上選択',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.products
                        .map(
                          (p) => CheckboxListTile(
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              '${p.name}  ¥${p.price}',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: _selectedProductIds.contains(p.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedProductIds.add(p.id);
                              } else {
                                _selectedProductIds.remove(p.id);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        );

      // ── 数量割引 ──
      case ConditionType.quantityThreshold:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _qtyTargetId,
              decoration: const InputDecoration(
                  labelText: '対象商品', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('全商品（合計）')),
                ...widget.products.map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _qtyTargetId = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '最低個数（例: 3）',
                suffixText: '個以上',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );

      // ── 金額割引 ──
      case ConditionType.amountThreshold:
        return TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '最低合計金額（例: 1000）',
            prefixText: '¥',
            suffixText: '以上',
            border: OutlineInputBorder(),
          ),
        );
    }
  }

  String _condTypeName(ConditionType t) {
    switch (t) {
      case ConditionType.productCombo:
        return '商品の組み合わせ（A＋Bセット）';
      case ConditionType.quantityThreshold:
        return '数量割引（N個以上で割引）';
      case ConditionType.amountThreshold:
        return '金額割引（○円以上で割引）';
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final value = int.tryParse(_valueCtrl.text);
    if (name.isEmpty || value == null || value <= 0) return;

    if (_condType == ConditionType.productCombo &&
        _selectedProductIds.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('商品を2つ以上選択してください')));
      return;
    }

    final List<String> targetIds;
    final int minQty;
    final int minAmt;

    switch (_condType) {
      case ConditionType.productCombo:
        targetIds = _selectedProductIds.toList();
        minQty = 1;
        minAmt = 0;
        break;
      case ConditionType.quantityThreshold:
        targetIds = _qtyTargetId != null ? [_qtyTargetId!] : [];
        minQty = int.tryParse(_qtyCtrl.text) ?? 2;
        minAmt = 0;
        break;
      case ConditionType.amountThreshold:
        targetIds = [];
        minQty = 1;
        minAmt = int.tryParse(_amountCtrl.text) ?? 1000;
        break;
    }

    final rule = DiscountRule(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isActive: widget.existing?.isActive ?? true,
      conditionType: _condType,
      targetProductIds: targetIds,
      minQuantity: minQty,
      minAmount: minAmt,
      discountType: _discType,
      discountValue: value,
    );

    widget.onSave(rule);
    Navigator.of(context).pop();
  }
}
