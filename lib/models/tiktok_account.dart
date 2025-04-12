import 'package:json_annotation/json_annotation.dart';

part 'tiktok_account.g.dart';

@JsonSerializable()
class TikTokAccount {
  final String id;
  final String username;
  final String? avatarUrl;
  final String accessToken;
  final DateTime tokenExpiry;
  final String refreshToken;

  TikTokAccount({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.accessToken,
    required this.tokenExpiry,
    required this.refreshToken,
  });

  factory TikTokAccount.fromJson(Map<String, dynamic> json) =>
      _$TikTokAccountFromJson(json);

  Map<String, dynamic> toJson() => _$TikTokAccountToJson(this);

  // التحقق من انتهاء صلاحية الرمز
  bool get isTokenExpired => DateTime.now().isAfter(tokenExpiry);

  // نسخة معدلة من الكائن
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
}
