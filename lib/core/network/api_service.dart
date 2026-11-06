import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/models/auth_state.dart';

/// POS バックエンドへの HTTP クライアント
/// Base URL: https://pos-server-production-157a.up.railway.app
class ApiService {
  static const String baseUrl =
      'https://pos-server-production-157a.up.railway.app';

  final Dio _dio;

  ApiService({String? token})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ));

  // ─── Auth ────────────────────────────────────────────────────
  /// POST /auth/login → {store_id, store_name, token}
  Future<Map<String, dynamic>> login(
      String storeName, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'store_name': storeName,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// POST /auth/register → {store_id, store_name}
  /// X-Admin-Secret ヘッダーが必要
  Future<Map<String, dynamic>> registerStore(
      String storeName, String password, {int themeColor = 1333408}) async {
    final res = await _dio.post('/auth/register',
      data: {
        'store_name': storeName,
        'password': password,
        'theme_color': themeColor,
      },
      options: Options(headers: {'X-Admin-Secret': 'kami2pos-admin-2024'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ─── Products ────────────────────────────────────────────────
  /// GET /api/products → List<{id, name, price, is_deleted}>
  Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await _dio.get('/api/products');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  /// POST /api/products → {id, name, price}
  Future<Map<String, dynamic>> createProduct(
      String name, int price) async {
    final res = await _dio.post('/api/products', data: {
      'name': name,
      'price': price,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// PATCH /api/products/:id → {id, name, price}
  Future<Map<String, dynamic>> updateProduct(
      String id, String name, int price) async {
    final res = await _dio.patch('/api/products/$id', data: {
      'name': name,
      'price': price,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// DELETE /api/products/:id
  Future<void> deleteProduct(String id) async {
    await _dio.delete('/api/products/$id');
  }

  // ─── Business Days ───────────────────────────────────────────
  /// POST /api/business-days → {id, store_id, opened_at, is_active}
  Future<Map<String, dynamic>> openBusinessDay() async {
    final res = await _dio.post('/api/business-days');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// PATCH /api/business-days/close
  Future<void> closeBusinessDay() async {
    await _dio.patch('/api/business-days/close');
  }

  /// GET /api/business-days/current
  /// → {active: true,  business_day: {id, ...}} または {active: false}
  /// active=false または取得失敗の場合は null を返す
  Future<Map<String, dynamic>?> getCurrentBusinessDay() async {
    try {
      final res = await _dio.get('/api/business-days/current');
      final data = Map<String, dynamic>.from(res.data as Map);
      final active = data['active'] as bool? ?? false;
      if (!active) return null;
      return Map<String, dynamic>.from(data['business_day'] as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ─── Orders ──────────────────────────────────────────────────
  /// GET /api/orders → 当日の注文一覧（items付き）
  Future<List<Map<String, dynamic>>> getOrders() async {
    final res = await _dio.get('/api/orders');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  /// POST /api/orders → {id, order_number, ...}
  Future<Map<String, dynamic>> createOrder({
    required String businessDayId,
    required List<Map<String, dynamic>> items,
    required int subtotal,
    required int discountAmount,
    required int totalAmount,
  }) async {
    final res = await _dio.post('/api/orders', data: {
      'business_day_id': businessDayId,
      'items': items,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// PATCH /api/orders/:id/complete
  Future<void> completeOrder(
      String orderId, String paymentMethod, int? receivedAmount) async {
    await _dio.patch('/api/orders/$orderId/complete', data: {
      'payment_method': paymentMethod,
      if (receivedAmount != null) 'received_amount': receivedAmount,
    });
  }

  /// PATCH /api/orders/:id/ready（支払済み・お渡し待ち）
  Future<void> readyOrder(
      String orderId, String paymentMethod, int? receivedAmount) async {
    await _dio.patch('/api/orders/$orderId/ready', data: {
      'payment_method': paymentMethod,
      if (receivedAmount != null) 'received_amount': receivedAmount,
    });
  }

  /// PATCH /api/orders/:id/handover（お渡し完了）
  Future<void> handoverOrder(String orderId) async {
    await _dio.patch('/api/orders/$orderId/handover');
  }

  /// PATCH /api/orders/:id/cancel
  Future<void> cancelOrder(String orderId) async {
    await _dio.patch('/api/orders/$orderId/cancel');
  }

  // ─── Public（認証不要・注文者モード） ────────────────────
  /// GET /public/:storeCode/info → {store_name, theme_color, is_open, products}
  Future<Map<String, dynamic>> getPublicStoreInfo(String storeCode) async {
    final res = await _dio.get('/public/${Uri.encodeComponent(storeCode)}/info');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// POST /public/:storeCode/orders → 注文作成
  Future<Map<String, dynamic>> createPublicOrder(
    String storeCode, {
    required List<Map<String, dynamic>> items,
    required int subtotal,
    required int discountAmount,
    required int totalAmount,
  }) async {
    final res = await _dio.post('/public/${Uri.encodeComponent(storeCode)}/orders', data: {
      'items': items,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// GET /public/orders/:orderId → 注文ステータス確認
  Future<Map<String, dynamic>> getPublicOrder(String orderId) async {
    final res = await _dio.get('/public/orders/$orderId');
    return Map<String, dynamic>.from(res.data as Map);
  }
}

/// Riverpod Provider: ログイン中トークンを注入した ApiService
final apiServiceProvider = Provider<ApiService>((ref) {
  final token = ref.watch(authStateProvider).token;
  return ApiService(token: token);
});
