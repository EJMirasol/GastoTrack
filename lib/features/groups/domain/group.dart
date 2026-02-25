class Group {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members;
  final String inviteCode;
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.inviteCode,
    required this.createdAt,
  });

  Group copyWith({
    String? id,
    String? name,
    String? createdBy,
    List<String>? members,
    String? inviteCode,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdBy': createdBy,
    'members': members,
    'inviteCode': inviteCode,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'] as String,
    name: json['name'] as String,
    createdBy: json['createdBy'] as String,
    members: List<String>.from(json['members'] as List),
    inviteCode: json['inviteCode'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
