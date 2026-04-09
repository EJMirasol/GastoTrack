class Category {
  final String id;
  final String name;
  final String icon;
  final String color;
  final bool isDefault;
  final String? userId;
  final int order;
  final String categoryType;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = true,
    this.userId,
    this.order = 0,
    this.categoryType = 'expense',
  });

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    bool? isDefault,
    String? userId,
    int? order,
    String? categoryType,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      userId: userId ?? this.userId,
      order: order ?? this.order,
      categoryType: categoryType ?? this.categoryType,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'isDefault': isDefault,
    'userId': userId,
    'order': order,
    'categoryType': categoryType,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: json['color'] as String,
    isDefault: json['isDefault'] as bool? ?? true,
    userId: json['userId'] as String?,
    order: (json['order'] as num?)?.toInt() ?? 0,
    categoryType: json['categoryType'] as String? ?? 'expense',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
