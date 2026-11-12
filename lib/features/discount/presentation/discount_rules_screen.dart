import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../products/domain/models/product.dart';
import '../../products/domain/products_provider.dart';
import '../domain/models/discount_rule.dart';
import '../domain/discount_rules_provider.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../../core/theme/km1.dart';

class DiscountRulesScreen extends ConsumerWidget {
  const DiscountRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.km1;
    final rules = ref.watch(discountRulesProvider);
    final products = ref.watch(productListProvider);
    final storeColor = ref.watch(authStateProvider.select((s) => s.themeColor));

    return Scaffold(
      appBar: AppBar(
        title: const Text('セット割'),
        bottom: storeBand(storeColor),
        leading: IconButton(
          icon: const Icon(Km1Icons.back),
          tooltip: '戻る',
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 見出し行の右に主な追加操作（FAB は使わない）
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Km1Space.lg, Km1Space.lg, Km1Space.lg, Km1Space.sm),
            child: Row(children: [
              Expanded(
                child: Text('ルール（${rules.length} 件）',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              FilledButton.icon(
                onPressed: () => _showRuleDialog(context, ref, products),
                icon: const Icon(Km1Icons.add, size: Km1Size.iconMd),
                label: const Text('ルールを追加'),
              ),
            ]),
          ),
          Expanded(
            child: rules.isEmpty
                ? const Km1Empty(
                    icon: Km1Icons.discount,
                    title: 'セット割のルールがまだありません',
                    body: '「ルールを追加」から、組み合わせ・数量・金額の条件で割引を作れます。',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Km1Space.lg, Km1Space.sm, Km1Space.lg, Km1Space.lg),
                    itemCount: rules.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Km1Space.sm),
                    itemBuilder: (_, i) {
                      final rule = rules[i];
                      final ink = rule.isActive ? c.ink : c.inkTertiary;
                      return Container(
                        decoration: km1CardDecoration(context),
                        padding: const EdgeInsets.fromLTRB(
                            Km1Space.sm, Km1Space.sm, Km1Space.xs, Km1Space.sm),
                        child: Row(children: [
                          Switch(
                            value: rule.isActive,
                            onChanged: (_) => ref
                                .read(discountRulesProvider.notifier)
                                .toggleActive(rule.id),
                          ),
                          const SizedBox(width: Km1Space.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(rule.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: Km1Text.body1Strong
                                            .copyWith(color: ink)),
                                  ),
                                  const SizedBox(width: Km1Space.sm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Km1Space.smNudge),
                                    decoration: BoxDecoration(
                                      color: rule.isActive
                                          ? c.successTint
                                          : c.surfaceMuted,
                                      border: Border.all(
                                          color: rule.isActive
                                              ? c.successInk
                                              : c.stroke),
                                      borderRadius:
                                          BorderRadius.circular(Km1Radius.md),
                                    ),
                                    child: Text(_discountLabel(rule),
                                        style: Km1Text.caption1
                                            .copyWith(color: ink)),
                                  ),
                                ]),
                                const SizedBox(height: Km1Space.xxs),
                                Text(
                                  '${rule.isActive ? '有効' : '無効'}　${_conditionLabel(rule, products)}',
                                  style: Km1Text.caption1
                                      .copyWith(color: c.inkSecondary),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Km1Icons.edit),
                            tooltip: '「${rule.name}」を編集',
                            onPressed: () => _showRuleDialog(
                                context, ref, products,
                                existing: rule),
                          ),
                          IconButton(
                            icon: Icon(Km1Icons.delete, color: c.dangerInk),
                            tooltip: '「${rule.name}」を削除',
                            onPressed: () =>
                                _confirmDelete(context, ref, rule),
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ],
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
        return '組み合わせ：$names';
      case ConditionType.quantityThreshold:
        if (rule.targetProductIds.isEmpty) {
          return '合計 ${rule.minQuantity} 個以上';
        }
        final names = rule.targetProductIds
            .map((id) =>
                products
                    .where((p) => p.id == id)
                    .map((p) => p.name)
                    .firstOrNull ??
                id)
            .join('・');
        return '$names を ${rule.minQuantity} 個以上';
      case ConditionType.amountThreshold:
        return '合計 ¥${rule.minAmount} 以上';
    }
  }

  String _discountLabel(DiscountRule rule) {
    if (rule.discountType == DiscountType.percentage) {
      return '${rule.discountValue}% 引き';
    }
    return '¥${rule.discountValue} 引き';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DiscountRule rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${rule.name}」を削除しますか'),
        content: const Text('削除したルールは元に戻せません。一時的に止めたいときは、スイッチで無効にできます。'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: km1DangerButton(ctx),
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
    final c = context.km1;
    final sectionStyle = Km1Text.body1Strong.copyWith(color: c.ink);
    return AlertDialog(
      title: Text(widget.existing == null ? 'ルールを追加' : 'ルールを編集'),
      scrollable: true,
      content: SizedBox(
        width: Km1Size.dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ルール名 ──
            Km1Field(
              label: 'ルール名',
              child: TextField(controller: _nameCtrl),
            ),
            const SizedBox(height: Km1Space.xxl),

            // ── 条件種別 ──
            Text('条件の種類', style: sectionStyle),
            const SizedBox(height: Km1Space.xs),
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
                            style: Km1Text.body1.copyWith(color: c.ink)),
                        value: t,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: Km1Space.sm),

            // ── 条件の詳細（種別ごとに変化） ──
            _buildConditionDetail(),
            const SizedBox(height: Km1Space.xxl),

            // ── 割引種別・金額 ──
            Text('割引の内容', style: sectionStyle),
            const SizedBox(height: Km1Space.sm),
            Wrap(spacing: Km1Space.sm, children: [
              ChoiceChip(
                label: const Text('金額（円）'),
                selected: _discType == DiscountType.fixedAmount,
                onSelected: (_) =>
                    setState(() => _discType = DiscountType.fixedAmount),
              ),
              ChoiceChip(
                label: const Text('割合（%）'),
                selected: _discType == DiscountType.percentage,
                onSelected: (_) =>
                    setState(() => _discType = DiscountType.percentage),
              ),
            ]),
            const SizedBox(height: Km1Space.md),
            Km1Field(
              label: _discType == DiscountType.percentage ? '割引率（%）' : '割引額（円）',
              child: TextField(
                controller: _valueCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  hintText:
                      _discType == DiscountType.percentage ? '10' : '200',
                  prefixText:
                      _discType == DiscountType.fixedAmount ? '¥ ' : null,
                  suffixText:
                      _discType == DiscountType.percentage ? '%' : null,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
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
    final c = context.km1;
    switch (_condType) {
      // ── 商品コンビ ──
      case ConditionType.productCombo:
        return Km1Field(
          label: '組み合わせる商品（2 つ以上）',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: c.strokeStrong),
                borderRadius: BorderRadius.circular(Km1Radius.md),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: widget.products
                      .map(
                        (p) => CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            '${p.name}　¥${p.price}',
                            style: Km1Text.body1.copyWith(color: c.ink),
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
        );

      // ── 数量割引 ──
      case ConditionType.quantityThreshold:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Km1Field(
              label: '対象の商品',
              child: DropdownButtonFormField<String?>(
                initialValue: _qtyTargetId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('全商品（合計）')),
                  ...widget.products.map((p) =>
                      DropdownMenuItem(value: p.id, child: Text(p.name))),
                ],
                onChanged: (v) => setState(() => _qtyTargetId = v),
              ),
            ),
            const SizedBox(height: Km1Space.lg),
            Km1Field(
              label: '最低の個数',
              child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                decoration: const InputDecoration(
                  hintText: '3',
                  suffixText: '個以上',
                ),
              ),
            ),
          ],
        );

      // ── 金額割引 ──
      case ConditionType.amountThreshold:
        return Km1Field(
          label: '最低の合計金額（円）',
          child: TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            decoration: const InputDecoration(
              hintText: '1000',
              prefixText: '¥ ',
              suffixText: '以上',
            ),
          ),
        );
    }
  }

  String _condTypeName(ConditionType t) {
    switch (t) {
      case ConditionType.productCombo:
        return '商品の組み合わせ（A＋Bセット）';
      case ConditionType.quantityThreshold:
        return '数量割引（N 個以上で割引）';
      case ConditionType.amountThreshold:
        return '金額割引（○ 円以上で割引）';
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final value = int.tryParse(_valueCtrl.text);
    if (name.isEmpty || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ルール名と割引の値（1 以上）を入力してください。')));
      return;
    }

    if (_condType == ConditionType.productCombo &&
        _selectedProductIds.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('組み合わせる商品を 2 つ以上選んでください。')));
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
