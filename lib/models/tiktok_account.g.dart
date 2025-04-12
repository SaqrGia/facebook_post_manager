// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tiktok_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TikTokAccount _$TikTokAccountFromJson(Map<String, dynamic> json) =>
    TikTokAccount(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      accessToken: json['accessToken'] as String,
      tokenExpiry: DateTime.parse(json['tokenExpiry'] as String),
      refreshToken: json['refreshToken'] as String,
    );

Map<String, dynamic> _$TikTokAccountToJson(TikTokAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
      'accessToken': instance.accessToken,
      'tokenExpiry': instance.tokenExpiry.toIso8601String(),
      'refreshToken': instance.refreshToken,
    };
