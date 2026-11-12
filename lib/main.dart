import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme/km1.dart';
import 'router/router.dart';

void main() {
  // ハッシュなしのパスベースURL（例: /customer/xxx）を使用する
  // これがないとQRコードのURLでアクセスしたときルーターが正しく動作しない
  usePathUrlStrategy();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // routerProvider を watch してリアクティブに更新
    final router = ref.watch(routerProvider);

    // 見た目は KM1（Fluent 2 準拠）。ブランド色は EPSON ブルーに固定し、
    // 店舗のテーマカラーは分類色として上部バーの下の帯にだけ使う（km1.dart の storeBand）。
    return MaterialApp.router(
      title: 'kami2pos',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // レスポンシブ文字サイズ（画面幅に応じてスケール）
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        final double scale;
        if (width >= 1440) {
          scale = 1.15;
        } else if (width >= 1024) {
          scale = 1.10;
        } else if (width >= 768) {
          scale = 1.05;
        } else {
          scale = 1.00;
        }

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
    );
  }
}
