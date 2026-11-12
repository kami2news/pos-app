import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/km1.dart';
import '../../auth/domain/models/auth_state.dart';
import '../domain/models/product.dart';
import '../domain/products_provider.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.km1;
    final products = ref.watch(productListProvider);
    final auth = ref.watch(authStateProvider);
    final storeName = auth.storeName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('商品管理 - $storeName'),
        bottom: storeBand(auth.themeColor),
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
            child: Row(
              children: [
                Expanded(
                  child: Text('商品（${products.length} 件）',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                FilledButton.icon(
                  onPressed: () => _showProductDialog(context, ref),
                  icon: const Icon(Km1Icons.add, size: Km1Size.iconMd),
                  label: const Text('商品を追加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Km1Empty(
                    icon: Km1Icons.product,
                    title: '商品がまだ登録されていません',
                    body: '「商品を追加」から登録してください。',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Km1Space.lg, Km1Space.sm, Km1Space.lg, Km1Space.lg),
                    itemCount: products.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Km1Space.sm),
                    itemBuilder: (context, i) {
                      final p = products[i];
                      return Container(
                        decoration: km1CardDecoration(context),
                        padding: const EdgeInsets.only(
                            left: Km1Space.lg, right: Km1Space.xs),
                        constraints:
                            BoxConstraints(minHeight: context.km1Target + 16),
                        child: Row(children: [
                          Icon(Km1Icons.product, color: c.inkSecondary),
                          const SizedBox(width: Km1Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(p.name,
                                    style: Km1Text.body1Strong
                                        .copyWith(color: c.ink),
                                    overflow: TextOverflow.ellipsis),
                                Text('¥${p.price}（税込）',
                                    style: Km1Text.caption1
                                        .copyWith(color: c.inkSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Km1Icons.edit),
                            tooltip: '「${p.name}」を編集',
                            onPressed: () =>
                                _showProductDialog(context, ref, product: p),
                          ),
                          IconButton(
                            icon: Icon(Km1Icons.delete, color: c.dangerInk),
                            tooltip: '「${p.name}」を削除',
                            onPressed: () => _confirmDelete(context, ref, p),
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

  /// 商品追加・編集ダイアログ
  void _showProductDialog(BuildContext context, WidgetRef ref,
      {Product? product}) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl =
        TextEditingController(text: product != null ? '${product.price}' : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product == null ? '商品を追加' : '商品を編集'),
        content: SizedBox(
          width: Km1Size.dialogWidth,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Km1Field(
                label: '商品名',
                child: TextFormField(
                  controller: nameCtrl,
                  validator: (v) =>
                      v == null || v.isEmpty ? '商品名を入力してください。' : null,
                ),
              ),
              const SizedBox(height: Km1Space.lg),
              Km1Field(
                label: '価格（税込、円）',
                child: TextFormField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(prefixText: '¥ '),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '価格を入力してください。';
                    if (int.tryParse(v) == null) return '半角数字で入力してください。';
                    if (int.parse(v) <= 0) return '1 円以上で入力してください。';
                    return null;
                  },
                ),
              ),
            ]),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final name = nameCtrl.text.trim();
              final price = int.parse(priceCtrl.text);
              if (product == null) {
                ref.read(productListProvider.notifier).add(name, price);
              } else {
                ref
                    .read(productListProvider.notifier)
                    .update(product.id, name, price);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(product == null ? '追加' : '保存'),
          ),
        ],
      ),
    );
  }

  /// 削除確認ダイアログ（見出しに対象の名前を入れる）
  void _confirmDelete(BuildContext context, WidgetRef ref, Product p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${p.name}」を削除しますか'),
        content: const Text('削除した商品は元に戻せません。'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: km1DangerButton(context),
            onPressed: () {
              ref.read(productListProvider.notifier).remove(p.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
