import 'package:json_annotation/json_annotation.dart';

part 'whatsapp_channel.g.dart';

@JsonSerializable()
class WhatsAppChannel {
  final String id;
  final String channelName;
  final bool owner;
  final int? subscribeCount;
  final String? inviteLink;

  WhatsAppChannel({
    required this.id,
    required this.channelName,
    required this.owner,
    this.subscribeCount,
    this.inviteLink,
  });

  factory WhatsAppChannel.fromJson(Map<String, dynamic> json) =>
      _$WhatsAppChannelFromJson(json);

  Map<String, dynamic> toJson() => _$WhatsAppChannelToJson(this);

  // إضافة طريقة مساواة لتسهيل المقارنة بين القنوات
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppChannel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // إضافة طريقة نسخ مع تعديلات
  WhatsAppChannel copyWith({
    String? id,
    String? channelName,
    bool? owner,
    int? subscribeCount,
    String? inviteLink,
  }) {
    return WhatsAppChannel(
      id: id ?? this.id,
      channelName: channelName ?? this.channelName,
      owner: owner ?? this.owner,
      subscribeCount: subscribeCount ?? this.subscribeCount,
      inviteLink: inviteLink ?? this.inviteLink,
    );
  }

  // إضافة طريقة لعرض القناة كنص
  @override
  String toString() {
    return 'WhatsAppChannel(id: $id, channelName: $channelName, owner: $owner, subscribeCount: $subscribeCount)';
  }
}
