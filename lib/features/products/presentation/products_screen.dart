import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/domain/models/auth_state.dart';
import '../domain/models/product.dart';
import '../domain/products_provider.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListProvider);
    final storeName = ref.watch(authStateProvider).storeName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('商品管理 - $storeName'),
        backgroundColor: const Color(0xFF1456A0),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: products.isEmpty
          ? const Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('商品がまだ登録されていません', style: TextStyle(color: Colors.grey)),
                ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = products[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF1456A0),
                      child:
                          Icon(Icons.inventory, color: Colors.white, size: 20),
                    ),
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text('¥${p.price}（税込）'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () =>
                            _showProductDialog(context, ref, product: p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, p),
                      ),
                    ]),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('商品を追加'),
        backgroundColor: const Color(0xFF1456A0),
        foregroundColor: Colors.white,
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
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: '商品名', border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? '商品名を入力してください' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '価格（税込・円）',
                  prefixText: '¥',
                  border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.isEmpty) return '価格を入力してください';
                if (int.tryParse(v) == null) return '数字で入力してください';
                if (int.parse(v) <= 0) return '0より大きい値を入力してください';
                return null;
              },
            ),
          ]),
        ),
        actions: [
          TextButton(
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
            child: Text(product == null ? '追加' : '更新'),
          ),
        ],
      ),
    );
  }

  /// 削除確認ダイアログ
  void _confirmDelete(BuildContext context, WidgetRef ref, Product p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${p.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
