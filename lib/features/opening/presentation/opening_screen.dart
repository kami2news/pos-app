// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/km1.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/models/auth_state.dart';
import '../../order/domain/order_provider.dart';
import '../../../core/network/api_service.dart';

class OpeningScreen extends ConsumerStatefulWidget {
  const OpeningScreen({super.key});
  @override
  ConsumerState<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends ConsumerState<OpeningScreen> {
  final _cashCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final cashText = _cashCtrl.text.trim();
    if (cashText.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('レジ内金を入力してください。')));
      return;
    }
    final openingCash = int.tryParse(cashText);
    if (openingCash == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('レジ内金は半角数字で入力してください。')));
      return;
    }

    setState(() => _loading = true);
    try {
      // POST /api/business-days（opening_cash はGoサーバー未対応・送信なし）
      final api = ref.read(apiServiceProvider);
      final data = await api.openBusinessDay();

      final businessDayId = data['id'] as String;

      // 注文リストをリセット
      ref.read(orderListProvider.notifier).reset();

      // 開設金を localStorage に保存（ページリロード後も復元できるよう）
      try {
        html.window.localStorage['pos_opening_cash'] = openingCash.toString();
      } catch (_) {}

      // businessDayStatus を open に更新
      ref.read(authStateProvider.notifier).update(
            (s) => s.copyWith(
              businessDayStatus: 'open',
              businessDayId: businessDayId,
              openingCash: openingCash,
            ),
          );
      // router が自動で /orders にリダイレクト
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? '開設できませんでした。通信状態を確認してもう一度お試しください（${e.message}）';
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg.toString())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('開設できませんでした。もう一度お試しください（$e）')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final today = DateTime.now();
    final auth = ref.watch(authStateProvider);
    final storeName = auth.storeName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('開設 - $storeName'),
        bottom: storeBand(auth.themeColor),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Km1Space.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Km1Size.dialogWidthSm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: km1CardDecoration(context),
                  padding: const EdgeInsets.all(Km1Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('営業日',
                          style: Km1Text.caption1.copyWith(color: c.inkSecondary)),
                      const SizedBox(height: Km1Space.xs),
                      Text('今日 ${km1Date(today)}',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: Km1Space.xxl),
                      Km1Field(
                        label: 'レジ内金（開始時、円）',
                        child: TextField(
                          controller: _cashCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          decoration: const InputDecoration(
                            prefixText: '¥ ',
                            hintText: '50000',
                          ),
                          onSubmitted: (_) { if (!_loading) _open(); },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Km1Space.xxl),
                FilledButton(
                  onPressed: _loading ? null : _open,
                  child: Text(_loading ? '開設中' : '開設'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
