import 'package:json_annotation/json_annotation.dart';

part 'instagram_account.g.dart';

@JsonSerializable()
class InstagramAccount {
  final String id;
  final String username;
  final String? profilePictureUrl;
  final String pageId;
  final String pageAccessToken;

  InstagramAccount({
    required this.id,
    required this.username,
    this.profilePictureUrl,
    required this.pageId,
    required this.pageAccessToken,
  });

  factory InstagramAccount.fromJson(Map<String, dynamic> json) =>
      _$InstagramAccountFromJson(json);

  Map<String, dynamic> toJson() => _$InstagramAccountToJson(this);
}
