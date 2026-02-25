// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExpenseImpl _$$ExpenseImplFromJson(Map<String, dynamic> json) =>
    _$ExpenseImpl(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      categoryId: json['categoryId'] as String,
      userId: json['userId'] as String,
      groupId: json['groupId'] as String?,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
      type:
          $enumDecodeNullable(_$ExpenseTypeEnumMap, json['type']) ??
          ExpenseType.expense,
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurringRuleId: json['recurringRuleId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ExpenseImplToJson(_$ExpenseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'categoryId': instance.categoryId,
      'userId': instance.userId,
      'groupId': instance.groupId,
      'description': instance.description,
      'date': instance.date.toIso8601String(),
      'type': _$ExpenseTypeEnumMap[instance.type]!,
      'isRecurring': instance.isRecurring,
      'recurringRuleId': instance.recurringRuleId,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$ExpenseTypeEnumMap = {
  ExpenseType.expense: 'expense',
  ExpenseType.income: 'income',
};
