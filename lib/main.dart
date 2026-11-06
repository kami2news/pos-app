import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/auth/domain/models/auth_state.dart';
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
    // テーマカラーを監視（変更時にアプリ全体に反映）
    final themeColorValue = ref.watch(
      authStateProvider.select((s) => s.themeColor),
    );
    final seedColor = themeColorValue != null
        ? Color(themeColorValue)
        : const Color(0xFF1456A0); // デフォルト：ネイビー

    // routerProvider を watch してリアクティブに更新
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'POS',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Noto Sans JP で日本語文字を確実に表示
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        // AppBar のデフォルトカラーをテーマカラーに統一
        appBarTheme: AppBarTheme(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        // FilledButton のデフォルトカラーも統一
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: seedColor,
            foregroundColor: Colors.white,
          ),
        ),
        // Switch のアクティブカラー
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? seedColor : null),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? seedColor.withValues(alpha: 0.4)
                  : null),
        ),
      ),
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
