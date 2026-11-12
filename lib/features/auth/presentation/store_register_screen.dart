import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_service.dart';
import '../../../core/theme/km1.dart';

// ─── カラーパレット定義 ───────────────────────────────────
class _ColorEntry {
  final String label;
  final int value;
  const _ColorEntry(this.label, this.value);
}

// 店舗の色は KM1 の分類色（cat-*）から選ぶ。帯と淡い塗りにだけ使う。
// 隣り合う色は明るさが違う組にし、青と橙を先頭に置く（EPSON のカラーユニバーサルデザイン）。
const _kPalette = [
  _ColorEntry('ブルー', 0xFF0F6CBD),
  _ColorEntry('パンプキン', 0xFFF7630C),
  _ColorEntry('ティール', 0xFF038387),
  _ColorEntry('ベリー', 0xFFC239B3),
  _ColorEntry('グリーン', 0xFF13A10E),
  _ColorEntry('コーンフラワー', 0xFF4F6BED),
  _ColorEntry('マリーゴールド', 0xFFEAA300),
  _ColorEntry('パープル', 0xFF8764B8),
  _ColorEntry('シアン', 0xFF0099BC),
  _ColorEntry('レッド', 0xFFD13438),
  _ColorEntry('ブラウン', 0xFF8E562E),
  _ColorEntry('グレー', 0xFF7A7574),
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
  int _selected = 0xFF0F6CBD; // 既定：ブルー

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
          .showSnackBar(const SnackBar(content: Text('すべての項目を入力してください。')));
      return;
    }
    if (pw != pw2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('パスワードが一致しません。確認用にも同じパスワードを入力してください。')));
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
          const SnackBar(content: Text('店舗を登録しました。ログインしてください。')),
        );
        context.go('/login');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? '登録できませんでした。もう一度お試しください。';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('登録できませんでした。もう一度お試しください（$e）')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final selectedEntry = _kPalette.firstWhere((e) => e.value == _selected,
        orElse: () => _kPalette.first);

    Widget section(String title, List<Widget> children) => Container(
          decoration: km1CardDecoration(context),
          padding: const EdgeInsets.all(Km1Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: Km1Space.lg),
              ...children,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('店舗の登録'),
        leading: IconButton(
          icon: const Icon(Km1Icons.back),
          tooltip: '戻る',
          onPressed: () => context.go('/login'),
        ),
        bottom: storeBand(_selected),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Km1Size.dialogWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Km1Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section('店舗情報', [
                  Km1Field(
                    label: '店舗名',
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Km1Icons.store)),
                    ),
                  ),
                  const SizedBox(height: Km1Space.lg),
                  Km1Field(
                    label: '店舗コード（ログイン ID）',
                    child: TextField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Km1Icons.person)),
                    ),
                  ),
                  const SizedBox(height: Km1Space.lg),
                  Km1Field(
                    label: 'パスワード',
                    child: TextField(
                      controller: _pwCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Km1Icons.lock)),
                    ),
                  ),
                  const SizedBox(height: Km1Space.lg),
                  Km1Field(
                    label: 'パスワード（確認）',
                    child: TextField(
                      controller: _pw2Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Km1Icons.lock)),
                    ),
                  ),
                ]),
                const SizedBox(height: Km1Space.lg),
                section('店舗の色', [
                  Text(
                    '店舗を見分けるための色です。画面上部のバーの下に帯として表示されます。',
                    style: Km1Text.body1.copyWith(color: c.inkSecondary),
                  ),
                  const SizedBox(height: Km1Space.lg),
                  Wrap(
                    spacing: Km1Space.sm,
                    runSpacing: Km1Space.sm,
                    children: [
                      for (final e in _kPalette)
                        _ColorOption(
                          entry: e,
                          selected: _selected == e.value,
                          onTap: () => setState(() => _selected = e.value),
                        ),
                    ],
                  ),
                  const SizedBox(height: Km1Space.md),
                  Text('選択中：${selectedEntry.label}',
                      style: Km1Text.body1Strong.copyWith(color: c.ink)),
                ]),
                const SizedBox(height: Km1Space.xxl),
                FilledButton(
                  onPressed: _loading ? null : _register,
                  child: Text(_loading ? '登録中' : '登録'),
                ),
                const SizedBox(height: Km1Space.sm),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('ログイン画面に戻る'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 色の選択肢（見本の帯 + 色名。選択中はチェックと縁で示す） ───
class _ColorOption extends StatelessWidget {
  final _ColorEntry entry;
  final bool selected;
  final VoidCallback onTap;
  const _ColorOption(
      {required this.entry, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.km1;
    final b = Theme.of(context).brightness;
    final color = Color(entry.value);
    return Semantics(
      selected: selected,
      button: true,
      label: entry.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Km1Radius.md),
        child: Container(
          width: 128,
          constraints: BoxConstraints(minHeight: context.km1Target),
          decoration: BoxDecoration(
            color: Km1Category.tint(color, b),
            borderRadius: BorderRadius.circular(Km1Radius.md),
            border: Border.all(
              color: selected ? c.brandStroke : c.stroke,
              width: selected ? Km1Size.strokeThick : Km1Size.strokeThin,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: Km1Size.strokeAccent,
                height: context.km1Target - 4,
                color: color,
              ),
              const SizedBox(width: Km1Space.sm),
              Expanded(
                child: Text(entry.label,
                    style: (selected ? Km1Text.body1Strong : Km1Text.body1)
                        .copyWith(color: c.ink),
                    overflow: TextOverflow.ellipsis),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(right: Km1Space.sm),
                  child: Icon(Km1Icons.check, size: Km1Size.iconSm, color: c.ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
