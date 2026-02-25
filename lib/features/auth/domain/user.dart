enum SubscriptionStatus { free, pro }

class User {
  final String id;
  final String email;
  final String? name;
  final SubscriptionStatus subscriptionStatus;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.subscriptionStatus = SubscriptionStatus.free,
    required this.createdAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    SubscriptionStatus? subscriptionStatus,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'subscriptionStatus': subscriptionStatus.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
    subscriptionStatus: json['subscriptionStatus'] == 'pro'
        ? SubscriptionStatus.pro
        : SubscriptionStatus.free,
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          id == other.id &&
          email == other.email &&
          name == other.name &&
          subscriptionStatus == other.subscriptionStatus;

  @override
  int get hashCode => Object.hash(id, email, name, subscriptionStatus);
}
