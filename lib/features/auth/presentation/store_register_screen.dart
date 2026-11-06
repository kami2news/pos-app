import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_service.dart';

// ─── カラーパレット定義 ───────────────────────────────────
class _ColorEntry {
  final String label;
  final int value;
  const _ColorEntry(this.label, this.value);
}

const _kPalette = [
  _ColorEntry('ネイビー', 0xFF1456A0),
  _ColorEntry('ロイヤルブルー', 0xFF1565C0),
  _ColorEntry('インディゴ', 0xFF283593),
  _ColorEntry('ティール', 0xFF00695C),
  _ColorEntry('グリーン', 0xFF2E7D32),
  _ColorEntry('パープル', 0xFF4527A0),
  _ColorEntry('ディープパープル', 0xFF6A1B9A),
  _ColorEntry('レッド', 0xFFC62828),
  _ColorEntry('ピンク', 0xFFAD1457),
  _ColorEntry('オレンジ', 0xFFE65100),
  _ColorEntry('ブラウン', 0xFF4E342E),
  _ColorEntry('チャコール', 0xFF37474F),
];

// ─── 画面本体 ─────────────────────────────────────────────
class StoreRegisterScreen extends ConsumerStatefulWidget {
  const StoreRegisterScreen({super.key});

  @override
  ConsumerState<StoreRegisterScreen> createState() => _StoreRegisterScreenState();
}

class _StoreRegisterScreenState extends ConsumerState<StoreRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _loading = false;
  int _selected = 0xFF1456A0; // デフォルト：ネイビー

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pw2 = _pw2Ctrl.text;

    if (name.isEmpty || code.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('全ての項目を入力してください')));
      return;
    }
    if (pw != pw2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('パスワードが一致しません')));
      return;
    }

    setState(() => _loading = true);
    try {
      final api = ApiService();

      // 店舗登録（テーマカラーも送信）
      await api.registerStore(code, pw, themeColor: _selected & 0xFFFFFF);

      // 登録成功 → ログイン画面へ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登録が完了しました。ログインしてください')),
        );
        context.go('/login');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? '登録に失敗しました';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(_selected);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('店舗を新規登録'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── プレビューバー ──
                _AppBarPreview(color: accentColor),
                const SizedBox(height: 20),

                // ── 店舗情報フォーム ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('店舗情報',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '店舗名',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.store_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _codeCtrl,
                          decoration: const InputDecoration(
                            labelText: '店舗コード（ログインID）',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _pwCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'パスワード',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _pw2Ctrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'パスワード（確認）',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── テーマカラー選択 ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('テーマカラー',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 10),
                          // 選択中の色名を表示
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _kPalette
                                  .firstWhere((c) => c.value == _selected)
                                  .label,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        const Text('アプリ全体のカラーテーマを選択',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 18),

                        // カラーグリッド（4列）
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _kPalette.length,
                          itemBuilder: (_, i) {
                            final c = _kPalette[i];
                            final isSelected = _selected == c.value;
                            return GestureDetector(
                              onTap: () => setState(() => _selected = c.value),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    width: isSelected ? 56 : 50,
                                    height: isSelected ? 56 : 50,
                                    decoration: BoxDecoration(
                                      color: Color(c.value),
                                      shape: BoxShape.circle,
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: Color(c.value)
                                                    .withValues(alpha: 0.55),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            color: Colors.white, size: 28)
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    c.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected
                                          ? Color(c.value)
                                          : Colors.grey[600],
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── 登録ボタン ──
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loading ? null : _register,
                  icon: const Icon(Icons.store_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('登録する', style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('ログイン画面に戻る'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── アプリバープレビュー ──────────────────────────────────
class _AppBarPreview extends StatelessWidget {
  final Color color;
  const _AppBarPreview({required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          // AppBar 風プレビュー
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: 52,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.white, size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: Text('店舗名',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
                Icon(Icons.receipt_long, color: Colors.white, size: 20),
                SizedBox(width: 14),
                Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                SizedBox(width: 14),
                Icon(Icons.local_offer_outlined, color: Colors.white, size: 20),
              ],
            ),
          ),
          // ボディヒント
          Container(
            height: 32,
            color: Colors.grey[100],
            child: Center(
              child: Text('カラープレビュー',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ),
          ),
        ],
      ),
    );
  }
}