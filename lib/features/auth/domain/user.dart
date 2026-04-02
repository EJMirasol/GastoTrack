import 'dart:convert';
import 'package:flutter/material.dart';

enum SubscriptionStatus { free, pro }

class User {
  final String id;
  final String email;
  final String? name;
  final String? image;
  final SubscriptionStatus subscriptionStatus;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.image,
    this.subscriptionStatus = SubscriptionStatus.free,
    required this.createdAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? image,
    SubscriptionStatus? subscriptionStatus,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      image: image ?? this.image,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'image': image,
    'subscriptionStatus': subscriptionStatus.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
    image: json['image'] as String?,
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
          image == other.image &&
          subscriptionStatus == other.subscriptionStatus;

  @override
  int get hashCode => Object.hash(id, email, name, image, subscriptionStatus);

  ImageProvider<Object>? get imageProvider {
    if (image == null) return null;
    if (image!.startsWith('data:')) {
      final bytes = base64Decode(image!.split(',').last);
      return MemoryImage(bytes);
    }
    return NetworkImage(image!);
  }
}
