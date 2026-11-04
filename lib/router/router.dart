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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.token != null;
      final location = state.matchedLocation;

      if (!isLoggedIn) {
        if (location == '/login' || location == '/register') return null;
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
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(
          path: '/register', builder: (c, s) => const StoreRegisterScreen()),
      GoRoute(path: '/opening', builder: (c, s) => const OpeningScreen()),
      GoRoute(path: '/closing', builder: (c, s) => const ClosingScreen()),
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
    ],
    errorBuilder: (c, s) => Scaffold(
      body: Center(child: Text('ページが見つかりません: ${s.error}')),
    ),
  );
});
