// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whatsapp_channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WhatsAppChannel _$WhatsAppChannelFromJson(Map<String, dynamic> json) =>
    WhatsAppChannel(
      id: json['id'] as String,
      channelName: json['channelName'] as String,
      owner: json['owner'] as bool,
      subscribeCount: (json['subscribeCount'] as num?)?.toInt(),
      inviteLink: json['inviteLink'] as String?,
    );

Map<String, dynamic> _$WhatsAppChannelToJson(WhatsAppChannel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'channelName': instance.channelName,
      'owner': instance.owner,
      'subscribeCount': instance.subscribeCount,
      'inviteLink': instance.inviteLink,
    };
