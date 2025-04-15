import 'package:json_annotation/json_annotation.dart';

part 'tiktok_account.g.dart';

/// نموذج يمثل حساب TikTok المرتبط في التطبيق
///
/// يخزن معلومات المستخدم ورموز المصادقة اللازمة
/// للتفاعل مع TikTok API نيابة عن المستخدم
@JsonSerializable()
class TikTokAccount {
  /// معرف المستخدم الفريد في TikTok (OpenID)
  final String id;

  /// اسم المستخدم المعروض في TikTok
  final String username;

  /// رابط صورة البروفايل
  final String? avatarUrl;

  /// رمز الوصول (Access Token) للمصادقة مع TikTok API
  final String accessToken;

  /// تاريخ انتهاء صلاحية رمز الوصول
  final DateTime tokenExpiry;

  /// رمز التحديث (Refresh Token) لتجديد رمز الوصول
  final String refreshToken;

  TikTokAccount({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.accessToken,
    required this.tokenExpiry,
    required this.refreshToken,
  });

  /// إنشاء نموذج من بيانات JSON
  factory TikTokAccount.fromJson(Map<String, dynamic> json) =>
      _$TikTokAccountFromJson(json);

  /// تحويل النموذج إلى بيانات JSON
  Map<String, dynamic> toJson() => _$TikTokAccountToJson(this);

  /// التحقق من انتهاء صلاحية الرمز
  bool get isTokenExpired => DateTime.now().isAfter(tokenExpiry);

  /// نسخة معدلة من الكائن
  TikTokAccount copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    String? accessToken,
    DateTime? tokenExpiry,
    String? refreshToken,
  }) {
    return TikTokAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      accessToken: accessToken ?? this.accessToken,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  /// تمثيل نصي للكائن
  @override
  String toString() {
    return 'TikTokAccount(id: $id, username: $username, tokenExpiry: $tokenExpiry, isTokenExpired: $isTokenExpired)';
  }

  /// مقارنة المساواة
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TikTokAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
