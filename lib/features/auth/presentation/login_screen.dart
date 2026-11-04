import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/models/auth_state.dart';
import '../../../core/network/api_service.dart';
import '../../products/domain/products_provider.dart';

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
      // POST /auth/login
      final api = ApiService(); // トークンなし（ログイン前）
      final data = await api.login(storeName, password);

      final token = data['token'] as String;
      final storeId = data['store_id'] as String;
      final name = data['store_name'] as String;

      // AuthState を更新（トークンをセット）
      ref.read(authStateProvider.notifier).state = AuthState(
        token: token,
        storeId: storeId,
        storeName: name,
        businessDayStatus: 'closed',
      );

      // 商品一覧をAPIから取得
      await ref.read(productListProvider.notifier).loadProducts();

      // 現在の営業日を確認（取得済みトークンで直接APIを呼ぶ）
      final tokenApi = ApiService(token: token);
      final bday = await tokenApi.getCurrentBusinessDay();
      if (bday != null) {
        ref.read(authStateProvider.notifier).update(
              (s) => s.copyWith(
                businessDayStatus: bday['status'] as String? ?? 'open',
                businessDayId: bday['id'] as String?,
              ),
            );
      }
      // router が businessDayStatus に応じて /opening か /orders へリダイレクト
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
