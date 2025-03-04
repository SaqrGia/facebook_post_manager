import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String name;
  final String? email;
  final String? pictureUrl;
  final String accessToken;

  User({
    required this.id,
    required this.name,
    this.email,
    this.pictureUrl,
    required this.accessToken,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? pictureUrl,
    String? accessToken,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      pictureUrl: pictureUrl ?? this.pictureUrl,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}
