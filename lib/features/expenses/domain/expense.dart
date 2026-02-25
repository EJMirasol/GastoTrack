import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense.freezed.dart';
part 'expense.g.dart';

enum ExpenseType { expense, income }

@freezed
class Expense with _$Expense {
  const factory Expense({
    required String id,
    required double amount,
    required String categoryId,
    required String userId,
    String? groupId,
    String? description,
    required DateTime date,
    @Default(ExpenseType.expense) ExpenseType type,
    @Default(false) bool isRecurring,
    String? recurringRuleId,
    required DateTime createdAt,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}
