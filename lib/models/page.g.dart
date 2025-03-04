// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FacebookPage _$FacebookPageFromJson(Map<String, dynamic> json) => FacebookPage(
      id: json['id'] as String,
      name: json['name'] as String,
      accessToken: json['access_token'] as String,
      category: json['category'] as String?,
      picture: json['picture'] as Map<String, dynamic>?,
      fanCount: (json['fan_count'] as num?)?.toInt(),
      engagementCount: (json['talking_about_count'] as num?)?.toInt(),
      instagramBusinessAccount:
          json['instagram_business_account'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$FacebookPageToJson(FacebookPage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'access_token': instance.accessToken,
      'category': instance.category,
      'picture': instance.picture,
      'fan_count': instance.fanCount,
      'talking_about_count': instance.engagementCount,
      'instagram_business_account': instance.instagramBusinessAccount,
    };
