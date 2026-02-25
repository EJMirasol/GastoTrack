import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/expense.dart';
import '../domain/category.dart';

final _uuid = Uuid();

final defaultCategories = [
  const Category(
    id: '1',
    name: 'Food',
    icon: 'restaurant',
    color: '#FF6B6B',
    isDefault: true,
  ),
  const Category(
    id: '2',
    name: 'Transport',
    icon: 'directions_car',
    color: '#4ECDC4',
    isDefault: true,
  ),
  const Category(
    id: '3',
    name: 'Shopping',
    icon: 'shopping_bag',
    color: '#45B7D1',
    isDefault: true,
  ),
  const Category(
    id: '4',
    name: 'Entertainment',
    icon: 'movie',
    color: '#96CEB4',
    isDefault: true,
  ),
  const Category(
    id: '5',
    name: 'Bills',
    icon: 'receipt',
    color: '#FECEA8',
    isDefault: true,
  ),
  const Category(
    id: '6',
    name: 'Health',
    icon: 'local_hospital',
    color: '#FF6F91',
    isDefault: true,
  ),
  const Category(
    id: '7',
    name: 'Education',
    icon: 'school',
    color: '#845EC2',
    isDefault: true,
  ),
  const Category(
    id: '8',
    name: 'Rent',
    icon: 'home',
    color: '#D65DB1',
    isDefault: true,
  ),
  const Category(
    id: '9',
    name: 'Salary',
    icon: 'account_balance_wallet',
    color: '#4CAF50',
    isDefault: true,
  ),
  const Category(
    id: '10',
    name: 'Other',
    icon: 'more_horiz',
    color: '#FFC75F',
    isDefault: true,
  ),
];

final categoriesProvider = Provider<List<Category>>((ref) {
  return defaultCategories;
});

class ExpenseNotifier extends StateNotifier<List<Expense>> {
  ExpenseNotifier() : super([]);

  void addExpense({
    required double amount,
    required String categoryId,
    required String userId,
    String? groupId,
    String? description,
    required DateTime date,
    ExpenseType type = ExpenseType.expense,
  }) {
    final expense = Expense(
      id: _uuid.v4(),
      amount: amount,
      categoryId: categoryId,
      userId: userId,
      groupId: groupId,
      description: description,
      date: date,
      type: type,
      createdAt: DateTime.now(),
    );
    state = [...state, expense];
  }

  void removeExpense(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  void updateExpense(Expense updated) {
    state = state.map((e) => e.id == updated.id ? updated : e).toList();
  }

  List<Expense> getExpensesForMonth(DateTime month) {
    return state.where((e) {
      return e.date.year == month.year && e.date.month == month.month;
    }).toList();
  }

  double getTotalExpensesForMonth(DateTime month) {
    return getExpensesForMonth(month)
        .where((e) => e.type == ExpenseType.expense)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double getTotalIncomeForMonth(DateTime month) {
    return getExpensesForMonth(month)
        .where((e) => e.type == ExpenseType.income)
        .fold(0, (sum, e) => sum + e.amount);
  }
}

final expensesProvider = StateNotifierProvider<ExpenseNotifier, List<Expense>>((
  ref,
) {
  return ExpenseNotifier();
});

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final monthlyExpensesProvider = Provider<List<Expense>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final expenses = ref.watch(expensesProvider);
  return expenses.where((e) {
    return e.date.year == month.year && e.date.month == month.month;
  }).toList();
});

final totalExpensesForMonthProvider = Provider<double>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);
  return expenses
      .where((e) => e.type == ExpenseType.expense)
      .fold(0.0, (sum, e) => sum + e.amount);
});

final totalIncomeForMonthProvider = Provider<double>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);
  return expenses
      .where((e) => e.type == ExpenseType.income)
      .fold(0.0, (sum, e) => sum + e.amount);
});

final expensesByCategoryProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);
  final byCategory = <String, double>{};
  for (final e in expenses.where((e) => e.type == ExpenseType.expense)) {
    byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
  }
  return byCategory;
});
