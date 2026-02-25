import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

enum SubscriptionStatus { free, pro }

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    String? name,
    @Default(SubscriptionStatus.free) SubscriptionStatus subscriptionStatus,
    required DateTime createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
