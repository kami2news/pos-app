import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/product.dart';
import '../../../core/network/api_service.dart';

/// 商品一覧のProvider（APIと同期）
final productListProvider =
    StateNotifierProvider<ProductListNotifier, List<Product>>(
  (ref) => ProductListNotifier(ref),
);

class ProductListNotifier extends StateNotifier<List<Product>> {
  final Ref _ref;

  ProductListNotifier(this._ref) : super([]);

  ApiService get _api => _ref.read(apiServiceProvider);

  /// APIから商品一覧を取得してstateを更新（ログイン後に呼ぶ）
  Future<void> loadProducts() async {
    try {
      final data = await _api.getProducts();
      state = data
          .where((m) => !(m['is_deleted'] as bool? ?? false))
          .map((m) => Product(
                id: m['id'] as String,
                name: m['name'] as String,
                price: (m['price'] as num).toInt(),
              ))
          .toList();
    } catch (_) {
      // ロード失敗時は既存stateを維持
    }
  }

  /// 商品を追加（楽観的更新 → API同期 → サーバーIDに差し替え）
  Future<void> add(String name, int price) async {
    final tempId = 'tmp-${DateTime.now().millisecondsSinceEpoch}';
    state = [...state, Product(id: tempId, name: name, price: price)];
    try {
      final data = await _api.createProduct(name, price);
      final serverId = data['id'] as String;
      state = state
          .map((p) => p.id == tempId ? p.copyWith(id: serverId) : p)
          .toList();
    } catch (_) {
      // API失敗: tempIdのまま継続（画面はそのまま使える）
    }
  }

  /// 商品を削除（楽観的更新 → API非同期）
  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
    _api.deleteProduct(id).catchError((_) {});
  }

  /// 商品を更新（楽観的更新 → API非同期）
  void update(String id, String name, int price) {
    state = state
        .map((p) => p.id == id ? p.copyWith(name: name, price: price) : p)
        .toList();
    _api.updateProduct(id, name, price).catchError((_) => <String, dynamic>{});
  }
}
