enum TransactionType { expense, income }

enum PaymentMethod { cash, ewallet, bank }

class Transaction {
  final String id;
  final double amount;
  final String categoryId;
  final String userId;
  final String? groupId;
  final String? description;
  final DateTime date;
  final TransactionType type;
  final PaymentMethod paymentMethod;
  final bool isRecurring;
  final String? recurringRuleId;
  final bool isTransfer;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.userId,
    this.groupId,
    this.description,
    required this.date,
    this.type = TransactionType.expense,
    this.paymentMethod = PaymentMethod.cash,
    this.isRecurring = false,
    this.recurringRuleId,
    this.isTransfer = false,
    required this.createdAt,
  });

  Transaction copyWith({
    String? id,
    double? amount,
    String? categoryId,
    String? userId,
    String? groupId,
    String? description,
    DateTime? date,
    TransactionType? type,
    PaymentMethod? paymentMethod,
    bool? isRecurring,
    String? recurringRuleId,
    bool? isTransfer,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringRuleId: recurringRuleId ?? this.recurringRuleId,
      isTransfer: isTransfer ?? this.isTransfer,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'categoryId': categoryId,
    'userId': userId,
    'groupId': groupId,
    'description': description,
    'date': date.millisecondsSinceEpoch,
    'type': type.name,
    'paymentMethod': paymentMethod.name,
    'isRecurring': isRecurring,
    'recurringRuleId': recurringRuleId,
    'isTransfer': isTransfer,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    categoryId: json['categoryId'] as String,
    userId: json['userId'] as String,
    groupId: json['groupId'] as String?,
    description: json['description'] as String?,
    date: DateTime.fromMillisecondsSinceEpoch((json['date'] as num).toInt()),
    type: json['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense,
    paymentMethod: json['paymentMethod'] == 'ewallet'
        ? PaymentMethod.ewallet
        : json['paymentMethod'] == 'bank'
        ? PaymentMethod.bank
        : PaymentMethod.cash,
    isRecurring: json['isRecurring'] as bool? ?? false,
    recurringRuleId: json['recurringRuleId'] as String?,
    isTransfer: json['isTransfer'] as bool? ?? false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num).toInt(),
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          id == other.id &&
          amount == other.amount &&
          date == other.date;

  @override
  int get hashCode => Object.hash(id, amount, date);
}
