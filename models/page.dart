import 'package:json_annotation/json_annotation.dart';

part 'page.g.dart';

@JsonSerializable()
class FacebookPage {
  final String id;
  final String name;
  @JsonKey(name: 'access_token')
  final String accessToken;
  final String? category;
  final Map<String, dynamic>? picture;
  @JsonKey(name: 'fan_count')
  final int? fanCount;
  @JsonKey(name: 'talking_about_count')
  final int? engagementCount;
  @JsonKey(name: 'instagram_business_account')
  final Map<String, dynamic>? instagramBusinessAccount;

  String? get pictureUrl => picture?['data']?['url'] as String?;

  FacebookPage({
    required this.id,
    required this.name,
    required this.accessToken,
    this.category,
    this.picture,
    this.fanCount,
    this.engagementCount,
    this.instagramBusinessAccount,
  });

  factory FacebookPage.fromJson(Map<String, dynamic> json) =>
      _$FacebookPageFromJson(json);

  Map<String, dynamic> toJson() => _$FacebookPageToJson(this);

  FacebookPage copyWith({
    String? id,
    String? name,
    String? accessToken,
    String? category,
    Map<String, dynamic>? picture,
    int? fanCount,
    int? engagementCount,
    Map<String, dynamic>? instagramBusinessAccount,
  }) {
    return FacebookPage(
      id: id ?? this.id,
      name: name ?? this.name,
      accessToken: accessToken ?? this.accessToken,
      category: category ?? this.category,
      picture: picture ?? this.picture,
      fanCount: fanCount ?? this.fanCount,
      engagementCount: engagementCount ?? this.engagementCount,
      instagramBusinessAccount:
          instagramBusinessAccount ?? this.instagramBusinessAccount,
    );
  }
}
