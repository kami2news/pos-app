import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
          .showSnackBar(const SnackBar(content: Text('レジ内金を入力してください')));
      return;
    }
    final openingCash = int.tryParse(cashText);
    if (openingCash == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('半角数字で入力してください')));
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

      // businessDayStatus を open に更新
      ref.read(authStateProvider.notifier).update(
            (s) => s.copyWith(
              businessDayStatus: 'open',
              businessDayId: businessDayId,
            ),
          );
      // router が自動で /orders にリダイレクト
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? '開設に失敗しました（${e.message}）';
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg.toString())));
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
    final today = DateTime.now();
    final storeName = ref.watch(authStateProvider).storeName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('開設作業 - $storeName'),
        backgroundColor: const Color(0xFF1456A0),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('営業日',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '${today.year}年${today.month}月${today.day}日',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ]),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('レジ内金（開始時）',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cashCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '金額（円）',
                              prefixText: '¥',
                              border: OutlineInputBorder(),
                              hintText: '例: 50000',
                            ),
                          ),
                        ]),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loading ? null : _open,
                  icon: const Icon(Icons.store_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('開設する', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
