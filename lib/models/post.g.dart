// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Post _$PostFromJson(Map<String, dynamic> json) => Post(
      id: json['id'] as String,
      message: json['message'] as String,
      link: json['link'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdTime: DateTime.parse(json['created_time'] as String),
      scheduledTime: json['scheduled_publish_time'] == null
          ? null
          : DateTime.parse(json['scheduled_publish_time'] as String),
    );

Map<String, dynamic> _$PostToJson(Post instance) => <String, dynamic>{
      'id': instance.id,
      'message': instance.message,
      'link': instance.link,
      'imageUrl': instance.imageUrl,
      'created_time': instance.createdTime.toIso8601String(),
      'scheduled_publish_time': instance.scheduledTime?.toIso8601String(),
    };
