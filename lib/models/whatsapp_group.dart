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

  // إضافة طريقة مساواة لتسهيل المقارنة بين المجموعات
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppGroup &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // إضافة طريقة نسخ مع تعديلات
  WhatsAppGroup copyWith({
    String? id,
    String? name,
    int? participants,
    bool? isContact,
  }) {
    return WhatsAppGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      isContact: isContact ?? this.isContact,
    );
  }

  // إضافة طريقة لعرض المجموعة كنص
  @override
  String toString() {
    return 'WhatsAppGroup(id: $id, name: $name, participants: $participants, isContact: $isContact)';
  }
}
