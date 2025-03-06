import 'package:json_annotation/json_annotation.dart';

part 'whatsapp_group.g.dart';

@JsonSerializable()
class WhatsAppGroup {
  final String id;
  final String name;
  final int participants;
  final bool? isContact; // علامة لتوضيح ما إذا كانت المجموعة من جهة اتصال

  WhatsAppGroup({
    required this.id,
    required this.name,
    required this.participants,
    this.isContact,
  });

  factory WhatsAppGroup.fromJson(Map<String, dynamic> json) =>
      _$WhatsAppGroupFromJson(json);

  Map<String, dynamic> toJson() => _$WhatsAppGroupToJson(this);
}
