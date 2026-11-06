import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/models/auth_state.dart';
import '../../../core/network/api_service.dart';
import '../../products/domain/products_provider.dart';
import '../../order/domain/order_provider.dart';
import '../../../version.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final storeName = _codeCtrl.text.trim();
    final password = _pwCtrl.text;
    if (storeName.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('店舗コードとパスワードを入力してください')));
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) ログイン
      final api = ApiService(); // トークンなし（ログイン前）
      final data = await api.login(storeName, password);

      final token = data['token'] as String;
      final storeId = data['store_id'] as String;
      final name = data['store_name'] as String;
      final rawColor = data['theme_color'] as int? ?? 1333408;
      final themeColor = 0xFF000000 | (rawColor & 0xFFFFFF);

      // 2) 営業日確認（authState 更新前にトークンを直接渡して確認）
      //    先に確認することで authState の更新が1回で済み、
      //    ルーターが中間状態（closed→open）に反応して /opening に
      //    飛んでしまうレースコンディションを防ぐ
      final tokenApi = ApiService(token: token);
      Map<String, dynamic>? bday = await tokenApi.getCurrentBusinessDay();

      // 3) 前日以前の営業日が残っている場合はポップアップ → 自動締め
      if (bday != null) {
        final openedAt =
            DateTime.parse(bday['opened_at'] as String).toLocal();
        final today = DateTime.now();
        final isStale = openedAt.year != today.year ||
            openedAt.month != today.month ||
            openedAt.day != today.day;

        if (isStale) {
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('前日の営業日が残っています'),
              content: Text(
                '${openedAt.year}年${openedAt.month}月${openedAt.day}日の営業日が'
                '締められていません。\n自動的に締め処理を行い、本日の開設画面に移動します。',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('確認して開設へ'),
                ),
              ],
            ),
          );
          await tokenApi.closeBusinessDay();
          bday = null;
        }
      }

      // 4) AuthState を確定した状態で1回だけ更新
      //    → ルーターはここで初めてリダイレクトを判断する
      ref.read(authStateProvider.notifier).state = AuthState(
        token: token,
        storeId: storeId,
        storeName: name,
        businessDayStatus: bday != null ? 'open' : 'closed',
        businessDayId: bday?['id'] as String?,
        themeColor: themeColor,
      );

      // 5) 商品一覧（authState のトークンが利用可能になった後）
      await ref.read(productListProvider.notifier).loadProducts();

      // 6) 営業日が開いていれば当日の注文を復元
      if (bday != null) {
        await ref.read(orderListProvider.notifier).loadOrders();
      }
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 401
          ? '店舗コードまたはパスワードが違います'
          : 'ログインに失敗しました（${e.message}）';
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('POS ログイン',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                        labelText: '店舗コード',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store)),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'パスワード',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock)),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('ログイン', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('店舗を新規登録する'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v$kAppVersion',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
