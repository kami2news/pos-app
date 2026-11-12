// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/models/auth_state.dart';
import '../../../core/network/api_service.dart';
import '../../products/domain/products_provider.dart';
import '../../order/domain/order_provider.dart';
import '../../discount/domain/discount_rules_provider.dart';
import '../../../version.dart';
import '../../../core/theme/km1.dart';

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
          const SnackBar(content: Text('店舗コードとパスワードを入力してください。')));
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
                  child: const Text('開設へ進む'),
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
      //    開設金は localStorage から復元（リロード後も維持）
      int? restoredOpeningCash;
      if (bday != null) {
        try {
          final stored = html.window.localStorage['pos_opening_cash'];
          restoredOpeningCash = stored != null ? int.tryParse(stored) : null;
        } catch (_) {}
      }
      ref.read(authStateProvider.notifier).state = AuthState(
        token: token,
        storeId: storeId,
        storeName: name,
        businessDayStatus: bday != null ? 'open' : 'closed',
        businessDayId: bday?['id'] as String?,
        themeColor: themeColor,
        openingCash: restoredOpeningCash,
      );

      // 5) 商品一覧（authState のトークンが利用可能になった後）
      await ref.read(productListProvider.notifier).loadProducts();

      // 6) 営業日が開いていれば当日の注文を復元
      if (bday != null) {
        await ref.read(orderListProvider.notifier).loadOrders();
      }

      // 7) セット割ルールを読み込み
      await ref.read(discountRulesProvider.notifier).loadRules();
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 401
          ? '店舗コードかパスワードが違います。入力し直してください。'
          : 'ログインできませんでした。通信状態を確認してもう一度お試しください（${e.message}）';
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ログインできませんでした。もう一度お試しください（$e）')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Km1Space.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Km1Size.dialogWidthSm),
            child: Container(
              decoration: km1CardDecoration(context),
              padding: const EdgeInsets.all(Km1Space.xxl),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('kami2pos',
                        style: Km1Text.caption1.copyWith(color: c.inkTertiary)),
                    const SizedBox(height: Km1Space.xs),
                    Text('ログイン', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: Km1Space.xxl),
                    Km1Field(
                      label: '店舗コード',
                      child: TextField(
                        controller: _codeCtrl,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Km1Icons.store)),
                        onSubmitted: (_) => _login(),
                      ),
                    ),
                    const SizedBox(height: Km1Space.lg),
                    Km1Field(
                      label: 'パスワード',
                      child: TextField(
                        controller: _pwCtrl,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Km1Icons.lock)),
                        onSubmitted: (_) => _login(),
                      ),
                    ),
                    const SizedBox(height: Km1Space.xxl),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    width: Km1Size.iconSm,
                                    height: Km1Size.iconSm,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: c.inkDisabled)),
                                const SizedBox(width: Km1Space.sm),
                                const Text('ログイン中'),
                              ],
                            )
                          : const Text('ログイン'),
                    ),
                    const SizedBox(height: Km1Space.sm),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('店舗を登録する'),
                    ),
                    const SizedBox(height: Km1Space.lg),
                    Text(
                      'v$kAppVersion',
                      style: Km1Text.caption1.copyWith(color: c.inkTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
