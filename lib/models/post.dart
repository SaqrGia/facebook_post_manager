import 'package:json_annotation/json_annotation.dart';

part 'post.g.dart';

@JsonSerializable()
class Post {
  final String id;
  final String message;
  final String? link;
  final String? imageUrl;
  @JsonKey(name: 'created_time')
  final DateTime createdTime;
  @JsonKey(name: 'scheduled_publish_time')
  final DateTime? scheduledTime;

  const Post({
    required this.id,
    required this.message,
    this.link,
    this.imageUrl,
    required this.createdTime,
    this.scheduledTime,
  });

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
  Map<String, dynamic> toJson() => _$PostToJson(this);
}
