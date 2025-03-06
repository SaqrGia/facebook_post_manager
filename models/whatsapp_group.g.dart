// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whatsapp_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WhatsAppGroup _$WhatsAppGroupFromJson(Map<String, dynamic> json) =>
    WhatsAppGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      participants: json['participants'] as int,
      isContact: json['isContact'] as bool?,
    );

Map<String, dynamic> _$WhatsAppGroupToJson(WhatsAppGroup instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'participants': instance.participants,
      'isContact': instance.isContact,
    };
