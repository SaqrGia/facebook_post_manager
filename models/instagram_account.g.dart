// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instagram_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InstagramAccount _$InstagramAccountFromJson(Map<String, dynamic> json) =>
    InstagramAccount(
      id: json['id'] as String,
      username: json['username'] as String,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      pageId: json['pageId'] as String,
      pageAccessToken: json['pageAccessToken'] as String,
    );

Map<String, dynamic> _$InstagramAccountToJson(InstagramAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'profilePictureUrl': instance.profilePictureUrl,
      'pageId': instance.pageId,
      'pageAccessToken': instance.pageAccessToken,
    };
