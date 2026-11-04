import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ログイン後にサーバーから返ってくる情報
class AuthState {
  /// JWTトークン（nullなら未ログイン）
  final String? token;

  /// 店舗ID
  final String? storeId;

  /// 店舗名
  final String? storeName;

  /// 当日のBusinessDayのステータス
  /// null: 未開設 / 'open': 営業中 / 'closed': 締め済み
  final String? businessDayStatus;

  /// 当日のBusinessDay ID（開設済みの場合）
  final String? businessDayId;

  /// テーマカラー（0xFFRRGGBB形式）
  /// nullの場合はデフォルトカラー(ネイビー)を使用
  final int? themeColor;

  const AuthState({
    this.token,
    this.storeId,
    this.storeName,
    this.businessDayStatus,
    this.businessDayId,
    this.themeColor,
  });

  /// 未ログイン状態
  const AuthState.initial()
      : token = null,
        storeId = null,
        storeName = null,
        businessDayStatus = null,
        businessDayId = null,
        themeColor = null;

  /// フィールドを部分的に更新して新しいインスタンスを返す
  AuthState copyWith({
    String? token,
    String? storeId,
    String? storeName,
    String? businessDayStatus,
    String? businessDayId,
    int? themeColor,
  }) {
    return AuthState(
      token: token ?? this.token,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      businessDayStatus: businessDayStatus ?? this.businessDayStatus,
      businessDayId: businessDayId ?? this.businessDayId,
      themeColor: themeColor ?? this.themeColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          token == other.token &&
          storeId == other.storeId &&
          storeName == other.storeName &&
          businessDayStatus == other.businessDayStatus &&
          businessDayId == other.businessDayId &&
          themeColor == other.themeColor;

  @override
  int get hashCode => Object.hash(
      token, storeId, storeName, businessDayStatus, businessDayId, themeColor);
}

/// 認証状態のProvider
final authStateProvider = StateProvider<AuthState>((ref) {
  return const AuthState.initial();
});
