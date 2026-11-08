import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/domain/models/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/store_register_screen.dart';
import '../features/opening/presentation/opening_screen.dart';
import '../features/order/presentation/order_screen.dart';
import '../features/order/presentation/order_list_screen.dart';
import '../features/order/presentation/order_registration_screen.dart';
import '../features/order/presentation/order_status_screen.dart';
import '../features/order/presentation/checkout_screen.dart';
import '../features/closing/presentation/closing_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/discount/presentation/discount_rules_screen.dart';
import '../features/customer/presentation/customer_order_screen.dart';
import '../features/customer/presentation/customer_number_screen.dart';
import '../features/history/presentation/history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.token != null;
      // go_router v13 では matchedLocation がルート確定前に "/" を返すことがある
      // uri.path を使うことで遷移先の実際のパスを確実に取得する
      final location = state.uri.path;

      if (!isLoggedIn) {
        if (location == '/login' || location == '/register') return null;
        // 注文者モード（QRアクセス）は認証不要
        if (location.startsWith('/customer')) return null;
        return '/login';
      }
      if (location == '/login') {
        return switch (authState.businessDayStatus) {
          'open' => '/orders',
          _ => '/opening',
        };
      }
      if (authState.businessDayStatus == 'closed' &&
          (location.startsWith('/orders') || location == '/closing')) {
        return '/opening';
      }
      // /history は営業日の状態に関わらずアクセス可能
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(
          path: '/register', builder: (c, s) => const StoreRegisterScreen()),
      GoRoute(path: '/opening', builder: (c, s) => const OpeningScreen()),
      GoRoute(path: '/closing', builder: (c, s) => const ClosingScreen()),
      GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
      GoRoute(path: '/products', builder: (c, s) => const ProductsScreen()),
      GoRoute(
          path: '/discount-rules',
          builder: (c, s) => const DiscountRulesScreen()),

      // ─── 注文系（ネストなし・フラットに並べる）───
      GoRoute(path: '/orders', builder: (c, s) => const OrderScreen()),
      GoRoute(path: '/orders/list', builder: (c, s) => const OrderListScreen()),
      GoRoute(
          path: '/orders/register',
          builder: (c, s) => const OrderRegistrationScreen()),
      GoRoute(
          path: '/orders/status', builder: (c, s) => const OrderStatusScreen()),
      GoRoute(
        path: '/orders/checkout/:orderId',
        builder: (c, s) =>
            CheckoutScreen(orderId: s.pathParameters['orderId']!),
      ),

      // ─── 注文者モード（認証不要・QRコードアクセス） ───
      GoRoute(
        path: '/customer/:storeCode',
        builder: (c, s) =>
            CustomerOrderScreen(storeCode: s.pathParameters['storeCode']!),
      ),
      GoRoute(
        path: '/customer/:storeCode/number/:orderId',
        builder: (c, s) => CustomerNumberScreen(
          storeCode: s.pathParameters['storeCode']!,
          orderId: s.pathParameters['orderId']!,
        ),
      ),
    ],
    errorBuilder: (c, s) => Scaffold(
      body: Center(child: Text('ページが見つかりません: ${s.error}')),
    ),
  );
});
